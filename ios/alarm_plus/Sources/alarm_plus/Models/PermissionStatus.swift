import Foundation
import UserNotifications

struct PermissionStatus {
    let notificationsGranted: Bool
    let exactAlarmsGranted: Bool
    let fullScreenIntentGranted: Bool
    let canOpenExactAlarmSettings: Bool
    let canOpenFullScreenSettings: Bool
    let criticalAlertsEligible: Bool
    let platformMeta: [String: Any]

    init(
        notificationsGranted: Bool,
        exactAlarmsGranted: Bool = false,
        fullScreenIntentGranted: Bool = false,
        canOpenExactAlarmSettings: Bool = false,
        canOpenFullScreenSettings: Bool = false,
        criticalAlertsEligible: Bool,
        platformMeta: [String: Any] = [:]
    ) {
        self.notificationsGranted = notificationsGranted
        self.exactAlarmsGranted = exactAlarmsGranted
        self.fullScreenIntentGranted = fullScreenIntentGranted
        self.canOpenExactAlarmSettings = canOpenExactAlarmSettings
        self.canOpenFullScreenSettings = canOpenFullScreenSettings
        self.criticalAlertsEligible = criticalAlertsEligible
        self.platformMeta = platformMeta
    }

    init(settings: UNNotificationSettings) {
        self.init(
            notificationsGranted: settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional,
            criticalAlertsEligible: settings.criticalAlertSetting == .enabled,
            platformMeta: [
                "authorizationStatus": settings.authorizationStatus.rawValue,
                "soundSetting": settings.soundSetting.rawValue
            ]
        )
    }

    func toMap() -> [String: Any] {
        return [
            "notificationsGranted": notificationsGranted,
            "exactAlarmsGranted": exactAlarmsGranted,
            "fullScreenIntentGranted": fullScreenIntentGranted,
            "canOpenExactAlarmSettings": canOpenExactAlarmSettings,
            "canOpenFullScreenSettings": canOpenFullScreenSettings,
            "criticalAlertsEligible": criticalAlertsEligible,
            "platformMeta": platformMeta
        ]
    }
}
