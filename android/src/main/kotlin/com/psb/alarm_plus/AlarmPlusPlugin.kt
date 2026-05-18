package com.psb.alarm_plus

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.psb.alarm_plus.core.AlarmConstants
import com.psb.alarm_plus.core.AlarmEventDispatcher
import com.psb.alarm_plus.core.AlarmJson
import com.psb.alarm_plus.core.AlarmLog
import com.psb.alarm_plus.core.AlarmNotificationResponseMapper
import com.psb.alarm_plus.core.AlarmPermissionManager
import com.psb.alarm_plus.core.AlarmScheduler
import com.psb.alarm_plus.data.AlarmRepository
import com.psb.alarm_plus.runtime.AlarmRingingService
import com.psb.alarm_plus.runtime.background.AlarmBackgroundIsolatePreferences
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import androidx.core.content.edit

/** AlarmPlusPlugin */
class AlarmPlusPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    private var activityBinding: ActivityPluginBinding? = null
    private lateinit var repository: com.psb.alarm_plus.data.AlarmRepository
    private lateinit var scheduler: AlarmScheduler
    private lateinit var permissionManager: AlarmPermissionManager
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        repository = _root_ide_package_.com.psb.alarm_plus.data.AlarmRepository.getInstance(appContext)
        scheduler = AlarmScheduler(appContext)
        permissionManager = AlarmPermissionManager(appContext)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, _root_ide_package_.com.psb.alarm_plus.core.AlarmConstants.METHOD_CHANNEL)
        eventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, _root_ide_package_.com.psb.alarm_plus.core.AlarmConstants.EVENT_CHANNEL)
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            AlarmConstants.METHOD_INITIALIZE -> runAsync(result) {
                val dispatcherHandle = call.optionalLong("dispatcher_handle")
                val callbackHandle = call.optionalLong("callback_handle")
                if (dispatcherHandle != null && callbackHandle != null) {
                    AlarmBackgroundIsolatePreferences(appContext)
                        .saveHandles(dispatcherHandle, callbackHandle)
                }
                null
            }
            AlarmConstants.METHOD_GET_BACKGROUND_CALLBACK_HANDLE -> runAsync(result) {
                AlarmBackgroundIsolatePreferences(appContext).getCallbackHandle()
            }
            AlarmConstants.METHOD_GET_LAST_NOTIFICATION_RESPONSE -> runAsync(result) {
                consumePendingNotificationResponse()
            }
            "triggerNow" -> runAsync(result) {
                val data = call.argument<Map<String, Any?>>("data") ?: emptyMap()
                val id = data["id"]?.toString().takeUnless { it.isNullOrBlank() }
                    ?: "trigger_${UUID.randomUUID()}"
                val now = System.currentTimeMillis()
                val payloadJson = AlarmJson.toJson(data)
                val platformMeta = mutableMapOf<String, Any?>()
                call.argument<Map<String, Any?>>("notificationSettings")?.let {
                    platformMeta["notificationSettings"] = it
                }
                val entity = repository.upsertScheduled(
                    id = id,
                    scheduledTimeUtcMs = now,
                    scheduledTimeLocalIso = AlarmRepository.localIsoFromUtcMillis(now),
                    payloadJson = payloadJson,
                    platformMeta = platformMeta
                )
                val serviceIntent = Intent(appContext, AlarmRingingService::class.java).apply {
                    action = AlarmConstants.ACTION_TRIGGER
                    putExtra(AlarmConstants.EXTRA_ALARM_ID, id)
                    putExtra(AlarmConstants.EXTRA_PAYLOAD_JSON, payloadJson)
                    putExtra(AlarmConstants.EXTRA_SCHEDULED_UTC_MS, entity.scheduledTimeUtcMs)
                    putExtra(
                        AlarmConstants.EXTRA_SCHEDULED_LOCAL_ISO,
                        entity.scheduledTimeLocalIso
                    )
                    putExtra(AlarmConstants.EXTRA_RETRY_COUNT, 0)
                }
                ContextCompat.startForegroundService(appContext, serviceIntent)
                null
            }
            "schedule" -> runAsync(result) {
                if (!scheduler.canScheduleExactAlarms()) {
                    throw AlarmException(
                        AlarmConstants.ERROR_PERMISSION_EXACT_ALARM_DENIED,
                        "Exact alarm permission denied"
                    )
                }
                val id = call.requiredString("id")
                val timeUtcMs = call.requiredLong("timeUtcMs")
                val localIso =
                    call.argument<String>("timeLocalIso")
                        ?: AlarmRepository.localIsoFromUtcMillis(timeUtcMs)
                val payloadMap = call.argument<Map<String, Any?>>("data")
                val payloadJson = AlarmJson.toJson(payloadMap)
                val platformMeta = mutableMapOf<String, Any?>()
                call.argument<Map<String, Any?>>("notificationSettings")?.let {
                    platformMeta["notificationSettings"] = it
                }
                val entity = repository.upsertScheduled(
                    id = id,
                    scheduledTimeUtcMs = timeUtcMs,
                    scheduledTimeLocalIso = localIso,
                    payloadJson = payloadJson,
                    status = AlarmConstants.STATUS_SCHEDULED,
                    retryCount = 0,
                    platformMeta = platformMeta
                )
                scheduler.schedule(entity)
                null
            }
            "cancel" -> runAsync(result) {
                val id = call.requiredString("id")
                scheduler.cancel(id)
                repository.markCanceled(id)
                null
            }
            "delete" -> runAsync(result) {
                val id = call.requiredString("id")
                scheduler.cancel(id)
                repository.deleteById(id)
                null
            }
            "stop" -> runAsync(result) {
                val intent = Intent(appContext, AlarmRingingService::class.java).apply {
                    action = AlarmConstants.ACTION_STOP
                }
                ContextCompat.startForegroundService(appContext, intent)
                null
            }
            "snooze" -> runAsync(result) {
                val id = call.requiredString("id")
                val minutes = call.requiredInt("minutes")
                val intent = Intent(appContext, AlarmRingingService::class.java).apply {
                    action = AlarmConstants.ACTION_SNOOZE
                    putExtra(AlarmConstants.EXTRA_ALARM_ID, id)
                    putExtra(AlarmConstants.EXTRA_SNOOZE_MINUTES, minutes)
                }
                ContextCompat.startForegroundService(appContext, intent)
                null
            }
            "getAll" -> runAsync(result) {
                repository.getAll().map { repository.toPlatformMap(it) }
            }
            "getLaunchAlarm" -> runAsync(result) {
                consumeLaunchAlarm()
            }
            "getPermissionStatus" -> runAsync(result) {
                permissionManager.getStatus()
            }
            "requestPermissions" -> runAsync(result) {
                val before = permissionManager.getStatus()
                val after = permissionManager.requestFromSettings()
                AlarmEventDispatcher.emit(
                    mapOf(
                        "type" to AlarmConstants.EVENT_TYPE_PERMISSION_CHANGED,
                        "atMs" to System.currentTimeMillis(),
                        "id" to null,
                        "alarm" to null,
                        "errorCode" to null,
                        "errorMessage" to null,
                        "meta" to mapOf("before" to before, "after" to after)
                    )
                )
                after
            }
            else -> result.notImplemented()
        }
    }

    private fun consumeLaunchAlarm(): Map<String, Any?>? {
        val activityIntent = activityBinding?.activity?.intent
        val intentId = activityIntent?.getStringExtra(AlarmConstants.EXTRA_ALARM_ID)
        if (!intentId.isNullOrBlank()) {
            activityIntent.removeExtra(AlarmConstants.EXTRA_ALARM_ID)
            repository.getById(intentId)?.let { return repository.toPlatformMap(it) }
        }

        val prefs = appContext.getSharedPreferences(AlarmConstants.PREFS_NAME, Context.MODE_PRIVATE)
        val consumed = prefs.getBoolean(AlarmConstants.PREF_LAUNCH_CONSUMED, true)
        val id = prefs.getString(AlarmConstants.PREF_LAST_LAUNCH_ALARM_ID, null)
        if (consumed || id.isNullOrBlank()) {
            return null
        }
        prefs.edit { putBoolean(AlarmConstants.PREF_LAUNCH_CONSUMED, true) }
        return repository.getById(id)?.let { repository.toPlatformMap(it) }
    }

    private fun runAsync(result: Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post {
                    result.success(value)
                }
            } catch (error: AlarmException) {
                AlarmLog.w("plugin", "AlarmException code=${error.code} msg=${error.message}")
                mainHandler.post {
                    result.error(error.code, error.message, null)
                }
            } catch (error: Throwable) {
                AlarmLog.e("plugin", "Method call failed", error)
                mainHandler.post {
                    result.error(
                        AlarmConstants.ERROR_SCHEDULE_FAILED,
                        error.message ?: "Unknown error",
                        null
                    )
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        AlarmEventDispatcher.setSink(events)
    }

    override fun onCancel(arguments: Any?) {
        AlarmEventDispatcher.setSink(null)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdownNow()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        sendNotificationPayloadMessage(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        sendNotificationPayloadMessage(binding.activity.intent)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        val handled = sendNotificationPayloadMessage(intent)
        if (handled) {
            activityBinding?.activity?.intent = intent
        }
        return handled
    }

    private fun sendNotificationPayloadMessage(intent: Intent?): Boolean {
        if (intent?.action != AlarmConstants.ACTION_LAUNCH_FROM_NOTIFICATION) {
            return false
        }
        executor.execute {
            try {
                val notificationResponse =
                    AlarmNotificationResponseMapper.fromIntent(intent, repository)
                savePendingNotificationResponse(notificationResponse)
                mainHandler.post {
                    channel.invokeMethod(
                        AlarmConstants.METHOD_NOTIFICATION_RESPONSE,
                        notificationResponse
                    )
                }
            } catch (e: Throwable) {
                AlarmLog.e("plugin", "Failed to send notification payload message", e)
            }
        }
        return true
    }

    private fun savePendingNotificationResponse(map: Map<String, Any?>) {
        val prefs = appContext.getSharedPreferences(AlarmConstants.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit {
            putString(
                AlarmConstants.PREF_PENDING_NOTIFICATION_RESPONSE,
                AlarmJson.toJson(map)
            )
        }
    }

    private fun consumePendingNotificationResponse(): Map<String, Any?>? {
        val prefs = appContext.getSharedPreferences(AlarmConstants.PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(AlarmConstants.PREF_PENDING_NOTIFICATION_RESPONSE, null)
        if (raw.isNullOrBlank()) {
            return null
        }
        prefs.edit { remove(AlarmConstants.PREF_PENDING_NOTIFICATION_RESPONSE) }
        return AlarmJson.toMap(raw)
    }

    private fun MethodCall.requiredString(key: String): String {
        val value = argument<String>(key)
        if (value.isNullOrBlank()) {
            throw AlarmException(AlarmConstants.ERROR_SCHEDULE_FAILED, "Missing `$key`")
        }
        return value
    }

    private fun MethodCall.requiredLong(key: String): Long {
        val value = optionalLong(key) ?: throw AlarmException(
            AlarmConstants.ERROR_SCHEDULE_FAILED,
            "Missing `$key`"
        )
        return value
    }

    private fun MethodCall.optionalLong(key: String): Long? {
        val value = when (val raw = argument<Any>(key)) {
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull()
            else -> null
        }
        return value
    }

    private fun MethodCall.requiredInt(key: String): Int {
        val value = argument<Number>(key)?.toInt()
            ?: throw AlarmException(AlarmConstants.ERROR_SCHEDULE_FAILED, "Missing `$key`")
        return value
    }
}

private class AlarmException(val code: String, override val message: String) :
    RuntimeException(message)
