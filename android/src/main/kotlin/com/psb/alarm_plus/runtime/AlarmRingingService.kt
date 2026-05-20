package com.psb.alarm_plus.runtime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.edit
import coil.ImageLoader
import coil.request.ImageRequest
import kotlinx.coroutines.runBlocking
import com.psb.alarm_plus.R
import com.psb.alarm_plus.core.AlarmConstants
import com.psb.alarm_plus.core.AlarmEventDispatcher
import com.psb.alarm_plus.core.AlarmIds
import com.psb.alarm_plus.core.AlarmLog
import com.psb.alarm_plus.core.AlarmScheduler
import com.psb.alarm_plus.data.AlarmRepository
import com.psb.alarm_plus.core.AlarmJson
import com.psb.alarm_plus.data.AlarmEntity
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class AlarmRingingService : Service() {
    private lateinit var repository: AlarmRepository
    private lateinit var scheduler: AlarmScheduler
    private lateinit var notificationManager: NotificationManager
    private lateinit var audioManager: AudioManager

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var activeAlarmId: String? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var volumeEnforcementRunnable: Runnable? = null
    private var originalSystemVolume: Int = -1
    private var targetVolume: Float = 1.0f

    override fun onCreate() {
        super.onCreate()
        repository = AlarmRepository.getInstance(applicationContext)
        scheduler = AlarmScheduler(applicationContext)
        notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val alarmId = intent?.getStringExtra(AlarmConstants.EXTRA_ALARM_ID)
        if (action != null) {
            ensureForeground(alarmId, null)
        }
        executor.execute {
            try {
                when (action) {
                    AlarmConstants.ACTION_TRIGGER -> onTrigger(intent)
                    AlarmConstants.ACTION_STOP -> onStopAction(alarmId)
                    AlarmConstants.ACTION_SNOOZE -> onSnoozeAction(
                        alarmId = alarmId,
                        minutes = intent.getIntExtra(
                            AlarmConstants.EXTRA_SNOOZE_MINUTES,
                            AlarmConstants.DEFAULT_SNOOZE_MINUTES
                        )
                    )

                    else -> AlarmLog.w("service", "Unknown action=$action")
                }
            } catch (error: Throwable) {
                AlarmLog.e("service", "Error handling action=$action", error)
                emitError(
                    id = alarmId,
                    code = AlarmConstants.ERROR_TRIGGER_FAILED,
                    message = error.message ?: "Unknown error"
                )
            }
        }
        return START_STICKY
    }

    private fun onTrigger(intent: Intent) {
        val alarmId = intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID) ?: return
        val alarm = repository.getById(alarmId)
        if (alarm == null) {
            AlarmLog.w("trigger", "Alarm not found id=$alarmId")
            emitError(
                id = alarmId,
                code = AlarmConstants.ERROR_ALARM_NOT_FOUND,
                message = "Alarm record missing at trigger time"
            )
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        val now = System.currentTimeMillis()
        val driftMs = now - alarm.scheduledTimeUtcMs
        val retryCount = intent.getIntExtra(
            AlarmConstants.EXTRA_RETRY_COUNT,
            alarm.retryCount
        )

        repository.markTriggered(
            id = alarm.id,
            actualTriggeredAtMs = now,
            driftMs = driftMs,
            retryCount = retryCount,
            nextRetryAtMs = null,
            platformMeta = mapOf("source" to "receiver")
        )
        setLaunchAlarmId(alarm.id)

        try {
            activeAlarmId = alarm.id
            startAlarmAudio(alarm)
            ensureForeground(alarm.id, alarm)
            val updated = repository.getById(alarm.id) ?: alarm
            AlarmEventDispatcher.emit(
                event(
                    type = AlarmConstants.EVENT_TYPE_TRIGGERED,
                    id = updated.id,
                    alarm = repository.toPlatformMap(updated),
                    meta = mapOf("driftMs" to driftMs)
                )
            )
            AlarmLog.i("trigger", "Triggered id=${alarm.id} driftMs=$driftMs")
        } catch (error: Throwable) {
            AlarmLog.e("trigger", "Audio start failed id=${alarm.id}", error)
            scheduleRetry(alarm.id, retryCount, error)
        }
    }

    private fun onStopAction(alarmId: String?) {
        val id = alarmId ?: activeAlarmId
        if (id != null) {
            repository.markStopped(id)
            repository.getById(id)?.let {
                AlarmEventDispatcher.emit(
                    event(
                        type = AlarmConstants.EVENT_TYPE_STOPPED,
                        id = id,
                        alarm = repository.toPlatformMap(it)
                    )
                )
            }
            AlarmLog.i("service", "Stopped id=$id")
        }
        stopPlayback()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun onSnoozeAction(alarmId: String?, minutes: Int) {
        val id = alarmId ?: activeAlarmId
        if (id == null) {
            stopPlayback()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        val existing = repository.getById(id)
        if (existing == null) {
            emitError(
                id = id,
                code = AlarmConstants.ERROR_ALARM_NOT_FOUND,
                message = "Cannot snooze missing alarm"
            )
            stopPlayback()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        val nextTimeMs = System.currentTimeMillis() + minutes.coerceAtLeast(1) * 60_000L
        val newRecord = repository.upsertScheduled(
            id = existing.id,
            scheduledTimeUtcMs = nextTimeMs,
            scheduledTimeLocalIso = AlarmRepository.localIsoFromUtcMillis(nextTimeMs),
            payloadJson = existing.payloadJson,
            status = AlarmConstants.STATUS_SNOOZED,
            retryCount = 0,
            nextRetryAtMs = null,
            platformMeta = mapOf(
                "snoozeMinutes" to minutes,
                "source" to "notification_action"
            )
        )
        scheduler.schedule(newRecord)
        repository.markSnoozed(id, retryCount = 0)
        val updated = repository.getById(id) ?: newRecord
        AlarmEventDispatcher.emit(
            event(
                type = AlarmConstants.EVENT_TYPE_SNOOZED,
                id = id,
                alarm = repository.toPlatformMap(updated),
                meta = mapOf("minutes" to minutes)
            )
        )
        AlarmLog.i("service", "Snoozed id=$id minutes=$minutes")
        stopPlayback()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun scheduleRetry(alarmId: String, currentRetryCount: Int, cause: Throwable) {
        val nextRetryCount = currentRetryCount + 1
        if (nextRetryCount > AlarmConstants.MAX_RETRY_COUNT) {
            repository.markError(alarmId, retryCount = nextRetryCount, nextRetryAtMs = null)
            emitError(
                id = alarmId,
                code = AlarmConstants.ERROR_TRIGGER_FAILED,
                message = "Retry exhausted: ${cause.message}"
            )
            return
        }

        val delayMs = AlarmConstants.RETRY_DELAYS_MS.getOrElse(nextRetryCount - 1) { 60_000L }
        val nextAtMs = System.currentTimeMillis() + delayMs
        val existing = repository.getById(alarmId)
        if (existing == null) {
            emitError(
                id = alarmId,
                code = AlarmConstants.ERROR_ALARM_NOT_FOUND,
                message = "Retry failed because alarm record disappeared"
            )
            return
        }
        val retryRecord = repository.upsertScheduled(
            id = existing.id,
            scheduledTimeUtcMs = nextAtMs,
            scheduledTimeLocalIso = AlarmRepository.localIsoFromUtcMillis(nextAtMs),
            payloadJson = existing.payloadJson,
            status = AlarmConstants.STATUS_SCHEDULED,
            retryCount = nextRetryCount,
            nextRetryAtMs = nextAtMs,
            platformMeta = mapOf(
                "retryReason" to (cause.message ?: "trigger_failure"),
                "retryCount" to nextRetryCount
            )
        )
        scheduler.schedule(retryRecord)
        repository.markError(alarmId, retryCount = nextRetryCount, nextRetryAtMs = nextAtMs)
        emitError(
            id = alarmId,
            code = AlarmConstants.ERROR_TRIGGER_FAILED,
            message = "Retry scheduled in ${delayMs}ms"
        )
        AlarmLog.w("trigger", "Retry scheduled id=$alarmId retryCount=$nextRetryCount")
    }

    private fun startAlarmAudio(alarm: AlarmEntity) {
        stopPlayback()
        acquireWakeLock()

        val platformMeta = AlarmJson.toMap(alarm.platformMetaJson)

        @Suppress("UNCHECKED_CAST")
        val settings = platformMeta["notificationSettings"] as? Map<String, Any?>
        val soundAsset = settings?.get("soundAsset") as? String
        
        @Suppress("UNCHECKED_CAST")
        val volumeSettings = settings?.get("volumeSettings") as? Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val vibrationSettings = settings?.get("vibrationSettings") as? Map<String, Any?>

        val defaultUri =
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            isLooping = true

            var sourceSet = false
            if (!soundAsset.isNullOrEmpty()) {
                try {
                    val flutterLoader = io.flutter.FlutterInjector.instance().flutterLoader()
                    if (!flutterLoader.initialized()) {
                        flutterLoader.startInitialization(applicationContext)
                        flutterLoader.ensureInitializationComplete(applicationContext, null)
                      }
                    val assetKey = flutterLoader.getLookupKeyForAsset(soundAsset)
                    val fd = applicationContext.assets.openFd(assetKey)
                    setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                    fd.close()
                    sourceSet = true
                } catch (e: Exception) {
                    AlarmLog.e("service", "Failed to load custom sound, falling back to default", e)
                }
            }

            if (!sourceSet) {
                setDataSource(applicationContext, defaultUri)
            }

            prepare()
        }
        mediaPlayer = player

        applyVolumeSettings(volumeSettings)
        applyVibrationSettings(vibrationSettings)
        
        player.start()
    }

    private fun applyVolumeSettings(settings: Map<String, Any?>?) {
        val player = mediaPlayer ?: return
        
        val vol = (settings?.get("volume") as? Number)?.toFloat()
        val fadeDurationMs = (settings?.get("fadeDurationMs") as? Number)?.toLong()
        @Suppress("UNCHECKED_CAST")
        val fadeSteps = settings?.get("fadeSteps") as? List<Map<String, Any?>>
        val volumeEnforced = settings?.get("volumeEnforced") as? Boolean ?: false

        targetVolume = vol ?: 1.0f

        if (vol != null) {
            originalSystemVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val targetSystemVol = (vol * maxVol).toInt()
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetSystemVol, 0)
        }

        if (fadeSteps != null && fadeSteps.isNotEmpty()) {
            player.setVolume(0f, 0f)
            fadeSteps.sortedBy { (it["atMs"] as? Number)?.toLong() ?: 0L }.forEach { step ->
                val stepVol = (step["volume"] as? Number)?.toFloat() ?: 1.0f
                val atMs = (step["atMs"] as? Number)?.toLong() ?: 0L
                mainHandler.postDelayed({
                    mediaPlayer?.setVolume(stepVol, stepVol)
                }, atMs)
            }
        } else if (fadeDurationMs != null && fadeDurationMs > 0) {
            player.setVolume(0f, 0f)
            val startTime = System.currentTimeMillis()
            val fadeRunnable = object : Runnable {
                override fun run() {
                    val currentMillis = System.currentTimeMillis() - startTime
                    if (currentMillis < fadeDurationMs) {
                        val currentVol = (currentMillis.toFloat() / fadeDurationMs) * targetVolume
                        mediaPlayer?.setVolume(currentVol, currentVol)
                        mainHandler.postDelayed(this, 50)
                    } else {
                        mediaPlayer?.setVolume(targetVolume, targetVolume)
                    }
                }
            }
            mainHandler.post(fadeRunnable)
        } else {
            player.setVolume(targetVolume, targetVolume)
        }

        if (volumeEnforced) {
            val enforceRunnable = object : Runnable {
                override fun run() {
                    val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    val targetSystemVol = (targetVolume * maxVol).toInt()
                    if (currentVol != targetSystemVol) {
                        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetSystemVol, 0)
                    }
                    mainHandler.postDelayed(this, 1000)
                }
            }
            volumeEnforcementRunnable = enforceRunnable
            mainHandler.post(enforceRunnable)
        }
    }

    private fun applyVibrationSettings(settings: Map<String, Any?>?) {
        val enabled = settings?.get("enabled") as? Boolean ?: true
        if (!enabled) return

        val preset = settings?.get("preset") as? String ?: "medium"
        val continuous = settings?.get("continuous") as? Boolean ?: true
        @Suppress("UNCHECKED_CAST")
        val customPattern = settings?.get("customPattern") as? List<Number>

        val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        vibrator = v

        val pattern = when (preset) {
            "custom" -> {
                if (customPattern != null && customPattern.isNotEmpty()) {
                    customPattern.map { it.toLong() }.toLongArray()
                } else {
                    longArrayOf(0, 500, 500, 500) // fallback to medium
                }
            }
            "strong" -> longArrayOf(0, 1000, 200, 1000)
            "light" -> longArrayOf(0, 200, 500, 200)
            "heartbeat" -> longArrayOf(0, 100, 100, 100, 500, 100, 100, 100)
            else -> longArrayOf(0, 500, 500, 500) // medium
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(pattern, if (continuous) 0 else -1)
            v.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(pattern, if (continuous) 0 else -1)
        }
    }

    private fun stopPlayback() {
        mainHandler.removeCallbacksAndMessages(null)
        volumeEnforcementRunnable = null
        
        if (originalSystemVolume != -1) {
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalSystemVolume, 0)
            originalSystemVolume = -1
        }

        try {
            mediaPlayer?.stop()
        } catch (_: Throwable) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Throwable) {
        }
        mediaPlayer = null

        try {
            vibrator?.cancel()
        } catch (_: Throwable) {
        }
        vibrator = null

        activeAlarmId = null
        releaseWakeLock()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock =
            powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                AlarmConstants.SERVICE_WAKELOCK_TAG
            ).apply {
                setReferenceCounted(false)
                acquire(AlarmConstants.SERVICE_WAKELOCK_TIMEOUT_MS)
            }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Throwable) {
        }
        wakeLock = null
    }

    private fun ensureForeground(
        alarmId: String?,
        alarm: AlarmEntity?
    ) {
        val notification = buildRingingNotification(alarmId, alarm)
        ServiceCompat.startForeground(
            this,
            AlarmConstants.RINGING_NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            } else {
                0
            }
        )
    }

    private fun buildRingingNotification(
        alarmId: String?,
        alarm: AlarmEntity?
    ): Notification {
        val platformMeta = if (alarm != null) {
            AlarmJson.toMap(alarm.platformMetaJson)
        } else {
            emptyMap()
        }

        @Suppress("UNCHECKED_CAST")
        val settings = platformMeta["notificationSettings"] as? Map<String, Any?>
        val title =
            settings?.get("title") as? String ?: getString(R.string.alarm_plus_notification_title)
        val body =
            settings?.get("body") as? String ?: getString(R.string.alarm_plus_notification_body)
        val stopText =
            settings?.get("stopButtonText") as? String ?: getString(R.string.alarm_plus_action_stop)
        val snoozeText = settings?.get("snoozeButtonText") as? String
            ?: getString(R.string.alarm_plus_action_snooze)
        val smallIconName = settings?.get("icon") as? String

        var smallIconRes = android.R.drawable.ic_lock_idle_alarm
        if (!smallIconName.isNullOrEmpty()) {
            val resId = resources.getIdentifier(smallIconName, "drawable", packageName)
            if (resId != 0) smallIconRes = resId
        }

        val launchIntent =
            (packageManager.getLaunchIntentForPackage(packageName) ?: Intent()).apply {
                action = AlarmConstants.ACTION_LAUNCH_FROM_NOTIFICATION
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
                putExtra(
                    AlarmConstants.EXTRA_ACTION_ID,
                    AlarmConstants.ACTION_LAUNCH_FROM_NOTIFICATION
                )
                putExtra(
                    AlarmConstants.EXTRA_NOTIFICATION_RESPONSE_TYPE,
                    AlarmConstants.NOTIFICATION_RESPONSE_SELECTED_NOTIFICATION
                )
            }
        val launchPendingIntent =
            PendingIntent.getActivity(
                this,
                alarmId?.let { AlarmIds.requestCodeFor(it) } ?: 90111,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        val stopIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = AlarmConstants.ACTION_STOP
            putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmConstants.EXTRA_ACTION_ID, AlarmConstants.ACTION_STOP)
            putExtra(
                AlarmConstants.EXTRA_NOTIFICATION_RESPONSE_TYPE,
                AlarmConstants.NOTIFICATION_RESPONSE_SELECTED_ACTION
            )
        }
        val snoozeIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = AlarmConstants.ACTION_SNOOZE
            putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmConstants.EXTRA_SNOOZE_MINUTES, AlarmConstants.DEFAULT_SNOOZE_MINUTES)
            putExtra(AlarmConstants.EXTRA_ACTION_ID, AlarmConstants.ACTION_SNOOZE)
            putExtra(
                AlarmConstants.EXTRA_NOTIFICATION_RESPONSE_TYPE,
                AlarmConstants.NOTIFICATION_RESPONSE_SELECTED_ACTION
            )
        }
        val stopPendingIntent =
            PendingIntent.getBroadcast(
                this,
                90211,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        val snoozePendingIntent =
            PendingIntent.getBroadcast(
                this,
                90212,
                snoozeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        val builder = NotificationCompat.Builder(this, AlarmConstants.NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(smallIconRes)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(launchPendingIntent)
            .setFullScreenIntent(launchPendingIntent, true)
            .addAction(
                android.R.drawable.ic_media_pause,
                stopText,
                stopPendingIntent
            )
            .addAction(
                android.R.drawable.ic_media_next,
                snoozeText,
                snoozePendingIntent
            )

        // Load large icon or big picture
        val largeIconAsset = settings?.get("largeIconAsset") as? String
        val bigPictureAsset = settings?.get("bigPictureAsset") as? String
        val largeIconUrl = settings?.get("largeIconUrl") as? String
        val bigPictureUrl = settings?.get("bigPictureUrl") as? String

        val imageLoader = ImageLoader.Builder(applicationContext).build()

        if (!largeIconAsset.isNullOrEmpty() || !largeIconUrl.isNullOrEmpty()) {
            if (!largeIconAsset.isNullOrEmpty()) {
                val flutterLoader = io.flutter.FlutterInjector.instance().flutterLoader()
                if (!flutterLoader.initialized()) {
                    flutterLoader.startInitialization(applicationContext)
                    flutterLoader.ensureInitializationComplete(applicationContext, null)
                }

                try {
                    val assetKey = flutterLoader.getLookupKeyForAsset(largeIconAsset)
                    val inputStream = applicationContext.assets.open(assetKey)
                    val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                    builder.setLargeIcon(bitmap)
                } catch (e: Exception) {
                    AlarmLog.e("service", "Failed to load large icon from asset", e)
                }
            } else if (!largeIconUrl.isNullOrEmpty()) {
                try {
                    val request = ImageRequest.Builder(applicationContext)
                        .data(largeIconUrl)
                        .build()
                    val result = runBlocking { imageLoader.execute(request) }
                    val drawable = result.drawable
                    if (drawable is android.graphics.drawable.BitmapDrawable) {
                        builder.setLargeIcon(drawable.bitmap)
                    }
                } catch (e: Exception) {
                    AlarmLog.e("service", "Failed to load large icon from URL", e)
                }
            }
        }

        if (!bigPictureAsset.isNullOrEmpty() || !bigPictureUrl.isNullOrEmpty()) {
            if (!bigPictureAsset.isNullOrEmpty()) {
                val flutterLoader = io.flutter.FlutterInjector.instance().flutterLoader()
                if (!flutterLoader.initialized()) {
                    flutterLoader.startInitialization(applicationContext)
                    flutterLoader.ensureInitializationComplete(applicationContext, null)
                }

                try {
                    val assetKey = flutterLoader.getLookupKeyForAsset(bigPictureAsset)
                    val inputStream = applicationContext.assets.open(assetKey)
                    val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                    builder.setStyle(NotificationCompat.BigPictureStyle().bigPicture(bitmap))
                } catch (e: Exception) {
                    AlarmLog.e("service", "Failed to load big picture from asset", e)
                }
            } else if (!bigPictureUrl.isNullOrEmpty()) {
                try {
                    val request = ImageRequest.Builder(applicationContext)
                        .data(bigPictureUrl)
                        .build()
                    val result = runBlocking { imageLoader.execute(request) }
                    val drawable = result.drawable
                    if (drawable is android.graphics.drawable.BitmapDrawable) {
                        builder.setStyle(NotificationCompat.BigPictureStyle().bigPicture(drawable.bitmap))
                    }
                } catch (e: Exception) {
                    AlarmLog.e("service", "Failed to load big picture from URL", e)
                }
            }
        }

        return builder.build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            AlarmConstants.NOTIFICATION_CHANNEL_ID,
            AlarmConstants.NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = AlarmConstants.NOTIFICATION_CHANNEL_DESC
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            setBypassDnd(true)
            setSound(null, null)
            enableVibration(true)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun setLaunchAlarmId(id: String) {
        val prefs = getSharedPreferences(AlarmConstants.PREFS_NAME, MODE_PRIVATE)
        prefs.edit {
            putString(AlarmConstants.PREF_LAST_LAUNCH_ALARM_ID, id)
                .putBoolean(AlarmConstants.PREF_LAUNCH_CONSUMED, false)
        }
    }

    private fun emitError(id: String?, code: String, message: String) {
        AlarmEventDispatcher.emit(
            event(
                type = AlarmConstants.EVENT_TYPE_ERROR,
                id = id,
                alarm = id?.let { repository.getById(it) }?.let { repository.toPlatformMap(it) },
                errorCode = code,
                errorMessage = message
            )
        )
    }

    private fun event(
        type: String,
        id: String?,
        alarm: Map<String, Any?>? = null,
        errorCode: String? = null,
        errorMessage: String? = null,
        meta: Map<String, Any?> = emptyMap()
    ): Map<String, Any?> {
        return mapOf(
            "type" to type,
            "atMs" to System.currentTimeMillis(),
            "id" to id,
            "alarm" to alarm,
            "errorCode" to errorCode,
            "errorMessage" to errorMessage,
            "meta" to meta
        )
    }

    override fun onDestroy() {
        stopPlayback()
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
