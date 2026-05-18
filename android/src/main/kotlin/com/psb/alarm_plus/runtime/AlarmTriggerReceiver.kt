package com.psb.alarm_plus.runtime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.psb.alarm_plus.core.AlarmConstants
import com.psb.alarm_plus.core.AlarmLog

class AlarmTriggerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmConstants.ACTION_TRIGGER) {
            return
        }
        val serviceIntent = Intent(context, AlarmRingingService::class.java).apply {
            action = AlarmConstants.ACTION_TRIGGER
            putExtra(AlarmConstants.EXTRA_ALARM_ID, intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID))
            putExtra(
                AlarmConstants.EXTRA_PAYLOAD_JSON,
                intent.getStringExtra(AlarmConstants.EXTRA_PAYLOAD_JSON)
            )
            putExtra(
                AlarmConstants.EXTRA_SCHEDULED_UTC_MS,
                intent.getLongExtra(AlarmConstants.EXTRA_SCHEDULED_UTC_MS, 0L)
            )
            putExtra(
                AlarmConstants.EXTRA_SCHEDULED_LOCAL_ISO,
                intent.getStringExtra(AlarmConstants.EXTRA_SCHEDULED_LOCAL_ISO)
            )
            putExtra(
                AlarmConstants.EXTRA_RETRY_COUNT,
                intent.getIntExtra(AlarmConstants.EXTRA_RETRY_COUNT, 0)
            )
        }
        try {
            ContextCompat.startForegroundService(context, serviceIntent)
            AlarmLog.i(
                "receiver",
                "Trigger received id=${intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID)}"
            )
        } catch (error: Throwable) {
            AlarmLog.e("receiver", "Failed to start foreground service", error)
        }
    }
}

