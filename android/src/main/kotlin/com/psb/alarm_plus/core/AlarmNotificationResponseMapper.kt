package com.psb.alarm_plus.core

import android.content.Intent
import com.psb.alarm_plus.data.AlarmRepository

object AlarmNotificationResponseMapper {
    fun fromIntent(intent: Intent, repository: AlarmRepository): Map<String, Any?> {
        val alarmId = intent.getStringExtra(AlarmConstants.EXTRA_ALARM_ID)
        val alarm = alarmId?.let { repository.getById(it) }
        val action = intent.getStringExtra(AlarmConstants.EXTRA_ACTION_ID)
            ?: intent.action
            ?: ""
        val responseType = intent.getIntExtra(
            AlarmConstants.EXTRA_NOTIFICATION_RESPONSE_TYPE,
            AlarmConstants.NOTIFICATION_RESPONSE_SELECTED_ACTION
        )
        val platformMeta = alarm?.platformMetaJson?.let { AlarmJson.toMap(it) } ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val settings = platformMeta["notificationSettings"] as? Map<String, Any?>
        val explicitPayload = settings?.get("payload") as? String
        
        return mapOf(
            "notificationId" to alarmId?.hashCode(),
            "alarmId" to alarmId,
            "actionId" to action,
            "input" to null,
            "payload" to (explicitPayload ?: alarm?.payloadJson ?: intent.getStringExtra(AlarmConstants.EXTRA_PAYLOAD_JSON)),
            "notificationResponseType" to responseType,
            "data" to mapOf(
                "alarmId" to alarmId,
                "scheduledTimeUtcMs" to alarm?.scheduledTimeUtcMs,
                "status" to alarm?.status
            )
        )
    }
}

