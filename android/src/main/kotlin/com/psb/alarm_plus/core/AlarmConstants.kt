package com.psb.alarm_plus.core

object AlarmConstants {
    const val METHOD_CHANNEL = "alarm_plus"
    const val EVENT_CHANNEL = "alarm_plus/events"
    const val BACKGROUND_EVENT_CHANNEL = "alarm_plus/actions"

    const val ACTION_TRIGGER = "com.psb.alarm_plus.action.TRIGGER"
    const val ACTION_STOP = "com.psb.alarm_plus.action.STOP"
    const val ACTION_SNOOZE = "com.psb.alarm_plus.action.SNOOZE"
    const val ACTION_LAUNCH_FROM_NOTIFICATION = "com.psb.alarm_plus.action.LAUNCH"

    const val EXTRA_ALARM_ID = "alarm_id"
    const val EXTRA_PAYLOAD_JSON = "payload_json"
    const val EXTRA_SCHEDULED_UTC_MS = "scheduled_utc_ms"
    const val EXTRA_SCHEDULED_LOCAL_ISO = "scheduled_local_iso"
    const val EXTRA_RETRY_COUNT = "retry_count"
    const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"
    const val EXTRA_ACTION_ID = "action_id"
    const val EXTRA_NOTIFICATION_RESPONSE_TYPE = "notification_response_type"

    const val EVENT_TYPE_TRIGGERED = "triggered"
    const val EVENT_TYPE_STOPPED = "stopped"
    const val EVENT_TYPE_SNOOZED = "snoozed"
    const val EVENT_TYPE_ERROR = "error"
    const val EVENT_TYPE_PERMISSION_CHANGED = "permissionChanged"

    const val STATUS_SCHEDULED = "scheduled"
    const val STATUS_TRIGGERED = "triggered"
    const val STATUS_SNOOZED = "snoozed"
    const val STATUS_STOPPED = "stopped"
    const val STATUS_CANCELED = "canceled"
    const val STATUS_ERROR = "error"

    const val PREFS_NAME = "alarm_plus_prefs"
    const val PREF_LAST_LAUNCH_ALARM_ID = "last_launch_alarm_id"
    const val PREF_LAUNCH_CONSUMED = "launch_consumed"
    const val PREF_BG_DISPATCHER_HANDLE = "bg_dispatcher_handle"
    const val PREF_BG_CALLBACK_HANDLE = "bg_callback_handle"
    const val PREF_PENDING_NOTIFICATION_RESPONSE = "pending_notification_response"

    const val NOTIFICATION_CHANNEL_ID = "alarm_plus_alarm_channel"
    const val NOTIFICATION_CHANNEL_NAME = "Alarm Plus"
    const val NOTIFICATION_CHANNEL_DESC = "Alarm notifications and controls"

    const val RINGING_NOTIFICATION_ID = 18001
    const val SERVICE_WAKELOCK_TAG = "alarm_plus::ringing"
    const val SERVICE_WAKELOCK_TIMEOUT_MS = 10 * 60 * 1000L

    const val DEFAULT_SNOOZE_MINUTES = 10
    const val MAX_RETRY_COUNT = 2
    val RETRY_DELAYS_MS = longArrayOf(15_000L, 60_000L)

    const val ERROR_PERMISSION_EXACT_ALARM_DENIED = "ERR_PERMISSION_EXACT_ALARM_DENIED"
    const val ERROR_ALARM_NOT_FOUND = "ERR_ALARM_NOT_FOUND"
    const val ERROR_SCHEDULE_FAILED = "ERR_SCHEDULE_FAILED"
    const val ERROR_TRIGGER_FAILED = "ERR_TRIGGER_FAILED"

    const val METHOD_INITIALIZE = "initialize"
    const val METHOD_GET_BACKGROUND_CALLBACK_HANDLE = "getBackgroundCallbackHandle"
    const val METHOD_NOTIFICATION_RESPONSE = "didReceiveNotificationResponse"
    const val METHOD_GET_LAST_NOTIFICATION_RESPONSE = "getLastNotificationResponse"

    const val NOTIFICATION_RESPONSE_SELECTED_NOTIFICATION = 0
    const val NOTIFICATION_RESPONSE_SELECTED_ACTION = 1
}
