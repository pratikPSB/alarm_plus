package com.psb.alarm_plus.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.psb.alarm_plus.data.AlarmEntity
import com.psb.alarm_plus.runtime.AlarmTriggerReceiver

class AlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun schedule(entity: AlarmEntity) {
        val pendingIntent = buildTriggerPendingIntent(entity)
        val triggerAtMs = entity.scheduledTimeUtcMs
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMs,
                pendingIntent
            )
            AlarmLog.i(
                "schedule",
                "Scheduled id=${entity.id} at=$triggerAtMs status=${entity.status}"
            )
        } catch (error: Throwable) {
            AlarmLog.e("schedule", "setExactAndAllowWhileIdle failed id=${entity.id}", error)
            throw error
        }
    }

    fun cancel(id: String) {
        val pendingIntent = buildTriggerPendingIntent(id = id)
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        AlarmLog.i("schedule", "Cancelled id=$id")
    }

    fun rescheduleAll(alarms: List<AlarmEntity>) {
        for (alarm in alarms) {
            if (
                alarm.status == AlarmConstants.STATUS_SCHEDULED ||
                alarm.status == AlarmConstants.STATUS_SNOOZED
            ) {
                schedule(alarm)
            }
        }
        AlarmLog.i("schedule", "Rescheduled ${alarms.size} alarms")
    }

    private fun buildTriggerPendingIntent(entity: AlarmEntity): PendingIntent {
        return buildTriggerPendingIntent(
            id = entity.id,
            payloadJson = entity.payloadJson,
            scheduledUtcMs = entity.scheduledTimeUtcMs,
            scheduledLocalIso = entity.scheduledTimeLocalIso,
            retryCount = entity.retryCount
        )
    }

    private fun buildTriggerPendingIntent(
        id: String,
        payloadJson: String? = null,
        scheduledUtcMs: Long = 0L,
        scheduledLocalIso: String = "",
        retryCount: Int = 0
    ): PendingIntent {
        val intent = Intent(context, AlarmTriggerReceiver::class.java).apply {
            action = AlarmConstants.ACTION_TRIGGER
            putExtra(AlarmConstants.EXTRA_ALARM_ID, id)
            putExtra(AlarmConstants.EXTRA_PAYLOAD_JSON, payloadJson)
            putExtra(AlarmConstants.EXTRA_SCHEDULED_UTC_MS, scheduledUtcMs)
            putExtra(AlarmConstants.EXTRA_SCHEDULED_LOCAL_ISO, scheduledLocalIso)
            putExtra(AlarmConstants.EXTRA_RETRY_COUNT, retryCount)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(
            context,
            AlarmIds.requestCodeFor(id),
            intent,
            flags
        )
    }

    fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }
}

