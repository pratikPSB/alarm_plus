import Foundation

enum AlarmConstants {
    static let methodChannelName = "alarm_plus"
    static let eventChannelName = "alarm_plus/events"
    static let defaultsStoreKey = "alarm_plus_store"
    static let defaultsLaunchAlarmIdKey = "alarm_plus_launch_alarm_id"
    static let defaultsPendingNotificationResponseKey = "alarm_plus_pending_notification_response"

    static let userInfoAlarmIdKey = "alarm_id"
    static let userInfoPayloadJsonKey = "payload_json"
    static let notificationCategoryId = "alarm_plus_category"
    static let actionStopId = "alarm_plus_stop"
    static let actionSnoozeId = "alarm_plus_snooze"

    static let defaultSnoozeMinutes = 10
}
