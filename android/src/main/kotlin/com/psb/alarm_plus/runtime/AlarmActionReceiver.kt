package com.psb.alarm_plus.runtime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.psb.alarm_plus.core.AlarmConstants
import com.psb.alarm_plus.core.AlarmLog
import com.psb.alarm_plus.core.AlarmNotificationResponseMapper
import com.psb.alarm_plus.data.AlarmRepository
import com.psb.alarm_plus.runtime.background.AlarmBackgroundActionDispatcher
import java.util.concurrent.Executors

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != AlarmConstants.ACTION_STOP && action != AlarmConstants.ACTION_SNOOZE) {
            return
        }

        val pendingResult = goAsync()
        val alarmId = intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID)
        val snoozeMinutes = intent.getIntExtra(
            AlarmConstants.EXTRA_SNOOZE_MINUTES,
            AlarmConstants.DEFAULT_SNOOZE_MINUTES
        )

        executor.execute {
            try {
                val repository = AlarmRepository.getInstance(context)
                val callbackMap = AlarmNotificationResponseMapper.fromIntent(intent, repository)

                Handler(Looper.getMainLooper()).post {
                    try {
                        AlarmBackgroundActionDispatcher.dispatch(context, callbackMap)

                        val serviceIntent = Intent(context, AlarmRingingService::class.java).apply {
                            this.action = action
                            putExtra(AlarmConstants.EXTRA_ALARM_ID, alarmId)
                            putExtra(AlarmConstants.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
                            putExtra(AlarmConstants.EXTRA_ACTION_ID, action)
                            putExtra(
                                AlarmConstants.EXTRA_NOTIFICATION_RESPONSE_TYPE,
                                AlarmConstants.NOTIFICATION_RESPONSE_SELECTED_ACTION
                            )
                        }
                        ContextCompat.startForegroundService(context, serviceIntent)
                        AlarmLog.i(
                            "action",
                            "Action received action=$action id=$alarmId"
                        )
                    } catch (e: Throwable) {
                        AlarmLog.e("action", "Failed to dispatch action", e)
                    } finally {
                        pendingResult.finish()
                    }
                }
            } catch (error: Throwable) {
                AlarmLog.e("action", "Failed to route action to service", error)
                pendingResult.finish()
            }
        }
    }

    companion object {
        private val executor = Executors.newSingleThreadExecutor()
    }
}
