import Foundation
import UserNotifications

protocol NotificationServiceDelegate: AnyObject {
    func onAlarmTriggered(id: String)
    func onNotificationResponse(alarmId: String, actionId: String?, payload: String?, type: Int)
}

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let notificationCenter = UNUserNotificationCenter.current()
    private weak var assetResolver: AssetResolver?
    weak var delegate: NotificationServiceDelegate?
    private weak var previousDelegate: UNUserNotificationCenterDelegate?

    init(assetResolver: AssetResolver?) {
        self.assetResolver = assetResolver
        super.init()
        self.previousDelegate = notificationCenter.delegate
        notificationCenter.delegate = self
        configureActions()
    }

    func requestPermissions(completion: @escaping (PermissionStatus) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { _, _ in
            self.getPermissionStatus(completion: completion)
        }
    }

    func getPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            completion(PermissionStatus(settings: settings))
        }
    }

    func scheduleNotification(record: AlarmRecord, fireDate: Date, completion: @escaping (Error?) -> Void) {
        let content = UNMutableNotificationContent()
        let ns = record.platformMeta["notificationSettings"] as? [String: Any]
        
        content.title = ns?["title"] as? String ?? "Alarm"
        content.body = ns?["body"] as? String ?? "Alarm is ringing"
        content.interruptionLevel = .timeSensitive
        
        if let soundAsset = ns?["soundAsset"] as? String,
           let soundName = assetResolver?.resolveSoundAsset(soundAsset) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = UNNotificationSound.default
        }
        
        let stopText = ns?["stopButtonText"] as? String ?? "Stop"
        let snoozeText = ns?["snoozeButtonText"] as? String ?? "Snooze"
        let stopAction = UNNotificationAction(identifier: AlarmConstants.actionStopId, title: stopText, options: [.foreground])
        let snoozeAction = UNNotificationAction(identifier: AlarmConstants.actionSnoozeId, title: snoozeText, options: [.foreground])
        let categoryId = "\(AlarmConstants.notificationCategoryId)_\(record.id)"
        let category = UNNotificationCategory(identifier: categoryId, actions: [stopAction, snoozeAction], intentIdentifiers: [], options: [.customDismissAction])
        
        notificationCenter.getNotificationCategories { categories in
            var newCategories = categories
            newCategories.insert(category)
            self.notificationCenter.setNotificationCategories(newCategories)
        }

        content.categoryIdentifier = categoryId
        content.userInfo = [
            AlarmConstants.userInfoAlarmIdKey: record.id,
            AlarmConstants.userInfoPayloadJsonKey: record.payloadJson ?? ""
        ]

        let finalize = { (attachment: UNNotificationAttachment?) in
            if let attachment = attachment { content.attachments = [attachment] }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: self.notificationId(for: record.id), content: content, trigger: trigger)
            self.notificationCenter.add(request, withCompletionHandler: completion)
        }

        if let bigPicture = ns?["bigPictureAsset"] as? String, let attachment = assetResolver?.resolveImageAsset(bigPicture) {
            finalize(attachment)
        } else if let largeIcon = ns?["largeIconAsset"] as? String, let attachment = assetResolver?.resolveImageAsset(largeIcon) {
            finalize(attachment)
        } else if let bigPictureUrl = ns?["bigPictureUrl"] as? String {
            assetResolver?.resolveImageUrl(bigPictureUrl) { attachment in
                if let attachment = attachment { finalize(attachment) }
                else if let largeIconUrl = ns?["largeIconUrl"] as? String {
                    self.assetResolver?.resolveImageUrl(largeIconUrl, completion: finalize)
                } else { finalize(nil) }
            }
        } else if let largeIconUrl = ns?["largeIconUrl"] as? String {
            assetResolver?.resolveImageUrl(largeIconUrl, completion: finalize)
        } else {
            finalize(nil)
        }
    }

    func cancelNotification(for id: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId(for: id)])
    }

    func removeAllDelivered() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    private func notificationId(for id: String) -> String {
        return "alarm_plus_\(id)"
    }

    private func configureActions() {
        let stopAction = UNNotificationAction(identifier: AlarmConstants.actionStopId, title: "Stop", options: [.foreground])
        let snoozeAction = UNNotificationAction(identifier: AlarmConstants.actionSnoozeId, title: "Snooze", options: [.foreground])
        let category = UNNotificationCategory(identifier: AlarmConstants.notificationCategoryId, actions: [stopAction, snoozeAction], intentIdentifiers: [], options: [.customDismissAction])
        notificationCenter.setNotificationCategories([category])
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if let id = notification.request.content.userInfo[AlarmConstants.userInfoAlarmIdKey] as? String {
            delegate?.onAlarmTriggered(id: id)
        }
        if let previous = previousDelegate, previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            previous.userNotificationCenter?(center, willPresent: notification) { options in
                completionHandler(options.union([.banner, .sound, .list]))
            }
        } else {
            completionHandler([.banner, .sound, .list])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let id = userInfo[AlarmConstants.userInfoAlarmIdKey] as? String {
            delegate?.onAlarmTriggered(id: id)
            let type = response.actionIdentifier == UNNotificationDefaultActionIdentifier ? 0 : 1
            delegate?.onNotificationResponse(alarmId: id, actionId: response.actionIdentifier, payload: userInfo[AlarmConstants.userInfoPayloadJsonKey] as? String, type: type)
        }
        if let previous = previousDelegate, previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            previous.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }
}
