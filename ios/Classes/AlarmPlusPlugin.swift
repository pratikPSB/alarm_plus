import Flutter
import UIKit
import UserNotifications
import AVFoundation
import MediaPlayer

public class AlarmPlusPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, UNUserNotificationCenterDelegate {
  private static let methodChannelName = "alarm_plus"
  private static let eventChannelName = "alarm_plus/events"
  private static let defaultsStoreKey = "alarm_plus_store"
  private static let defaultsLaunchAlarmIdKey = "alarm_plus_launch_alarm_id"
  private static let defaultsPendingNotificationResponseKey = "alarm_plus_pending_notification_response"

  private static let userInfoAlarmIdKey = "alarm_id"
  private static let userInfoPayloadJsonKey = "payload_json"
  private static let notificationCategoryId = "alarm_plus_category"
  private static let actionStopId = "alarm_plus_stop"
  private static let actionSnoozeId = "alarm_plus_snooze"

  private static let defaultSnoozeMinutes = 10

  private let notificationCenter = UNUserNotificationCenter.current()
  private let defaults = UserDefaults.standard
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private weak var previousNotificationDelegate: UNUserNotificationCenterDelegate?
  private var registrar: FlutterPluginRegistrar?

  // MARK: - Background Audio Properties
  private var silentAudioPlayer: AVAudioPlayer?
  private var activeTimers: [String: Timer] = [:]
  private var alarmAudioPlayer: AVAudioPlayer?
  private var volumeEnforcementTimer: Timer?
  private var previousSystemVolume: Float?
  private let silentWavBase64 = "UklGRvgPAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgARkxMUswPAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkYXRhAAAAAA=="

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    let instance = AlarmPlusPlugin()
    instance.methodChannel = channel
    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
    instance.configureNotificationActions()
    instance.previousNotificationDelegate = instance.notificationCenter.delegate
    instance.notificationCenter.delegate = instance
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      result(nil)
    case "getBackgroundCallbackHandle":
      result(nil)
    case "getLastNotificationResponse":
      let pending = defaults.dictionary(forKey: Self.defaultsPendingNotificationResponseKey)
      defaults.removeObject(forKey: Self.defaultsPendingNotificationResponseKey)
      result(pending)
    case "triggerNow":
      handleTriggerNow(call, result: result)
    case "schedule":
      handleSchedule(call, result: result)
    case "cancel":
      handleCancel(call, result: result)
    case "delete":
      handleDelete(call, result: result)
    case "stop":
      handleStop(result: result)
    case "snooze":
      handleSnooze(call, result: result)
    case "getAll":
      handleGetAll(result: result)
    case "getLaunchAlarm":
      handleGetLaunchAlarm(result: result)
    case "getPermissionStatus":
      handleGetPermissionStatus(result: result)
    case "requestPermissions":
      handleRequestPermissions(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handleTriggerNow(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing triggerNow args", details: nil))
      return
    }
    let data = args["data"] as? [String: Any] ?? [:]
    let nowMs = now()
    let id = (data["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "trigger_\(UUID().uuidString)"
    let payloadJson = jsonString(data)

    let record = buildRecord(
      id: id,
      scheduledTimeUtcMs: nowMs,
      scheduledTimeLocalIso: isoFromMillis(nowMs),
      payloadJson: payloadJson,
      status: "scheduled",
      createdAtMs: nowMs,
      platformMeta: args["notificationSettings"] as? [String: Any] != nil
        ? ["notificationSettings": args["notificationSettings"]!]
        : [:]
    )
    upsertRecord(record)
    
    let fireDate = Date()
    scheduleNotification(record: record, fireDate: fireDate)
    scheduleAudioTimer(record: record, fireDate: fireDate)

    result(nil)
  }

  private func handleSchedule(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing schedule args", details: nil))
      return
    }
    guard
      let id = args["id"] as? String,
      !id.isEmpty,
      let timeUtcMs = args["timeUtcMs"] as? NSNumber
    else {
      result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing schedule id/time", details: nil))
      return
    }

    let data = args["data"] as? [String: Any] ?? [:]
    let payloadJson = jsonString(data)
    let scheduledMs = timeUtcMs.int64Value
    let localIso = (args["timeLocalIso"] as? String) ?? isoFromMillis(scheduledMs)
    let createdAt = int64Value(existingRecord(for: id)?["createdAtMs"]) ?? now()

    let record = buildRecord(
      id: id,
      scheduledTimeUtcMs: scheduledMs,
      scheduledTimeLocalIso: localIso,
      payloadJson: payloadJson,
      status: "scheduled",
      createdAtMs: createdAt,
      platformMeta: args["notificationSettings"] as? [String: Any] != nil 
        ? ["notificationSettings": args["notificationSettings"]!] 
        : [:]
    )
    upsertRecord(record)

    let fireDate = Date(timeIntervalSince1970: TimeInterval(scheduledMs) / 1000.0)
    
    scheduleNotification(record: record, fireDate: fireDate)
    scheduleAudioTimer(record: record, fireDate: fireDate)
    result(nil)
  }

  private func handleCancel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let id = args["id"] as? String
    else {
      result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing cancel id", details: nil))
      return
    }

    cancelAudioTimer(id: id)
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId(id: id)])
    updateStatus(id: id, status: "canceled")
    result(nil)
  }

  private func handleDelete(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let id = args["id"] as? String
    else {
      result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing delete id", details: nil))
      return
    }
    cancelAudioTimer(id: id)
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId(id: id)])
    var store = loadStore()
    store.removeValue(forKey: id)
    saveStore(store)
    result(nil)
  }

  private func handleStop(result: @escaping FlutterResult) {
    var store = loadStore()
    for key in store.keys {
      var item = store[key] ?? [:]
      if (item["status"] as? String) == "triggered" {
        item["status"] = "stopped"
        item["updatedAtMs"] = now()
        store[key] = item
        emitEvent(type: "stopped", id: key, alarm: item, meta: [:])
      }
    }
    saveStore(store)
    stopRinging()
    notificationCenter.removeAllDeliveredNotifications()
    result(nil)
  }

  private func handleSnooze(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let id = args["id"] as? String,
      let minutesNumber = args["minutes"] as? NSNumber
    else {
      result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing snooze args", details: nil))
      return
    }

    let minutes = max(1, minutesNumber.intValue)
    guard let existing = existingRecord(for: id) else {
      result(FlutterError(code: "ERR_ALARM_NOT_FOUND", message: "Alarm not found", details: nil))
      return
    }

    let nextMs = now() + Int64(minutes) * 60_000
    var record = existing
    record["scheduledTimeUtcMs"] = nextMs
    record["scheduledTimeLocalIso"] = isoFromMillis(nextMs)
    record["status"] = "snoozed"
    record["retryCount"] = 0
    record.removeValue(forKey: "nextRetryAtMs")
    record["platformMeta"] = existing["platformMeta"] ?? [:]
    if var meta = record["platformMeta"] as? [String: Any] {
        meta["snoozeMinutes"] = minutes
        record["platformMeta"] = meta
    }
    upsertRecord(record)

    let fireDate = Date(timeIntervalSince1970: TimeInterval(nextMs) / 1000.0)
    scheduleNotification(record: record, fireDate: fireDate)
    scheduleAudioTimer(record: record, fireDate: fireDate)
    emitEvent(type: "snoozed", id: id, alarm: record, meta: ["minutes": minutes])
    result(nil)
  }

  private func handleGetAll(result: @escaping FlutterResult) {
    let list = loadStore().values.map { $0 }
      .sorted { first, second in
        let firstMs = int64Value(first["scheduledTimeUtcMs"]) ?? 0
        let secondMs = int64Value(second["scheduledTimeUtcMs"]) ?? 0
        return firstMs < secondMs
      }
    result(list)
  }

  private func handleGetLaunchAlarm(result: @escaping FlutterResult) {
    guard let alarmId = defaults.string(forKey: Self.defaultsLaunchAlarmIdKey) else {
      result(nil)
      return
    }
    defaults.removeObject(forKey: Self.defaultsLaunchAlarmIdKey)
    result(existingRecord(for: alarmId))
  }

  private func handleGetPermissionStatus(result: @escaping FlutterResult) {
    notificationCenter.getNotificationSettings { settings in
      result(self.permissionMap(from: settings))
    }
  }

  private func handleRequestPermissions(result: @escaping FlutterResult) {
    notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
      self.notificationCenter.getNotificationSettings { settings in
        let map = self.permissionMap(from: settings)
        self.emitEvent(type: "permissionChanged", id: nil, alarm: nil, meta: map)
        result(map)
      }
    }
  }

  private func configureNotificationActions() {
    let stopAction = UNNotificationAction(
      identifier: Self.actionStopId,
      title: "Stop",
      options: [.foreground]
    )
    let snoozeAction = UNNotificationAction(
      identifier: Self.actionSnoozeId,
      title: "Snooze",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: Self.notificationCategoryId,
      actions: [stopAction, snoozeAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    notificationCenter.setNotificationCategories([category])
  }

  private func scheduleNotification(record: [String: Any], fireDate: Date) {
    let id = record["id"] as? String ?? UUID().uuidString
    let content = UNMutableNotificationContent()
    
    let platformMeta = record["platformMeta"] as? [String: Any]
    let ns = platformMeta?["notificationSettings"] as? [String: Any]
    
    content.title = ns?["title"] as? String ?? "Alarm"
    content.body = ns?["body"] as? String ?? "Alarm is ringing"
    
    if let soundAsset = ns?["soundAsset"] as? String,
       let soundName = resolveSoundAsset(soundAsset) {
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
    } else {
        content.sound = UNNotificationSound.default
    }
    
    if let bigPicture = ns?["bigPictureAsset"] as? String,
        let attachment = resolveImageAsset(bigPicture) {
        content.attachments = [attachment]
    } else if let largeIcon = ns?["largeIconAsset"] as? String,
              let attachment = resolveImageAsset(largeIcon) {
        content.attachments = [attachment]
    } else if let bigPictureUrl = ns?["bigPictureUrl"] as? String,
              let attachment = resolveImageUrl(bigPictureUrl) {
        content.attachments = [attachment]
    } else if let largeIconUrl = ns?["largeIconUrl"] as? String,
              let attachment = resolveImageUrl(largeIconUrl) {
        content.attachments = [attachment]
    }
    
    let stopText = ns?["stopButtonText"] as? String ?? "Stop"
    let snoozeText = ns?["snoozeButtonText"] as? String ?? "Snooze"
    
    let stopAction = UNNotificationAction(identifier: Self.actionStopId, title: stopText, options: [.foreground])
    let snoozeAction = UNNotificationAction(identifier: Self.actionSnoozeId, title: snoozeText, options: [.foreground])
    let categoryId = "alarm_plus_category_\(id)"
    let category = UNNotificationCategory(identifier: categoryId, actions: [stopAction, snoozeAction], intentIdentifiers: [], options: [.customDismissAction])
    
    notificationCenter.getNotificationCategories { categories in
        var newCategories = categories
        newCategories.insert(category)
        self.notificationCenter.setNotificationCategories(newCategories)
    }

    content.categoryIdentifier = categoryId
    content.userInfo = [
      Self.userInfoAlarmIdKey: id,
      Self.userInfoPayloadJsonKey: record["payloadJson"] as? String ?? ""
    ]

    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: fireDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let request = UNNotificationRequest(identifier: notificationId(id: id), content: content, trigger: trigger)

    notificationCenter.add(request) { error in
      if let error {
        self.updateStatus(id: id, status: "error")
        self.emitEvent(
          type: "error",
          id: id,
          alarm: self.existingRecord(for: id),
          errorCode: "ERR_SCHEDULE_FAILED",
          errorMessage: error.localizedDescription,
          meta: [:]
        )
      }
    }
  }

  private func buildRecord(
    id: String,
    scheduledTimeUtcMs: Int64,
    scheduledTimeLocalIso: String,
    payloadJson: String?,
    status: String,
    createdAtMs: Int64,
    platformMeta: [String: Any] = [:]
  ) -> [String: Any] {
    return [
      "id": id,
      "scheduledTimeUtcMs": scheduledTimeUtcMs,
      "scheduledTimeLocalIso": scheduledTimeLocalIso,
      "payloadJson": payloadJson as Any,
      "status": status,
      "createdAtMs": createdAtMs,
      "updatedAtMs": now(),
      "retryCount": 0,
      "platformMeta": platformMeta
    ]
  }

  private func upsertRecord(_ record: [String: Any]) {
    guard let id = record["id"] as? String else { return }
    var store = loadStore()
    store[id] = record
    saveStore(store)
  }

  private func existingRecord(for id: String) -> [String: Any]? {
    return loadStore()[id]
  }

  private func updateStatus(id: String, status: String) {
    var store = loadStore()
    guard var record = store[id] else { return }
    record["status"] = status
    record["updatedAtMs"] = now()
    store[id] = record
    saveStore(store)
  }

  private func loadStore() -> [String: [String: Any]] {
    guard let raw = defaults.dictionary(forKey: Self.defaultsStoreKey) else {
      return [:]
    }
    var store: [String: [String: Any]] = [:]
    for (key, value) in raw {
      if let item = value as? [String: Any] {
        store[key] = item
      }
    }
    return store
  }

  private func saveStore(_ store: [String: [String: Any]]) {
    defaults.set(store, forKey: Self.defaultsStoreKey)
  }

  private func notificationId(id: String) -> String {
    return "alarm_plus_\(id)"
  }

  private func permissionMap(from settings: UNNotificationSettings) -> [String: Any] {
    let granted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    return [
      "notificationsGranted": granted,
      "exactAlarmsGranted": false,
      "fullScreenIntentGranted": false,
      "canOpenExactAlarmSettings": false,
      "canOpenFullScreenSettings": false,
      "criticalAlertsEligible": settings.criticalAlertSetting == .enabled,
      "platformMeta": [
        "authorizationStatus": settings.authorizationStatus.rawValue,
        "soundSetting": settings.soundSetting.rawValue
      ]
    ]
  }

  private func jsonString(_ map: [String: Any]) -> String? {
    guard JSONSerialization.isValidJSONObject(map) else { return nil }
    let data = try? JSONSerialization.data(withJSONObject: map, options: [])
    return data.flatMap { String(data: $0, encoding: .utf8) }
  }

  private func now() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
  }

  private func isoFromMillis(_ millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private func emitEvent(
    type: String,
    id: String?,
    alarm: [String: Any]?,
    errorCode: String? = nil,
    errorMessage: String? = nil,
    meta: [String: Any]
  ) {
    eventSink?([
      "type": type,
      "atMs": now(),
      "id": id ?? NSNull(),
      "alarm": alarm ?? NSNull(),
      "errorCode": errorCode ?? NSNull(),
      "errorMessage": errorMessage ?? NSNull(),
      "meta": meta
    ])
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let id = notification.request.content.userInfo[Self.userInfoAlarmIdKey] as? String {
      markTriggeredAndEmit(id: id, triggerDate: Date())
      if activeTimers[id] == nil {
          // Trigger ringing if not already running via timer
          if let record = existingRecord(for: id) {
              startRinging(record: record)
          }
      }
    }
    if let previous = previousNotificationDelegate,
       previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
      previous.userNotificationCenter?(center, willPresent: notification) { previousOptions in
        if #available(iOS 14.0, *) {
          completionHandler(previousOptions.union([.banner, .sound, .list]))
        } else {
          completionHandler(previousOptions.union([.alert, .sound]))
        }
      }
      return
    }
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .list])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    guard let id = userInfo[Self.userInfoAlarmIdKey] as? String else {
      completionHandler()
      return
    }
    
    var explicitPayload: String? = nil
    if let existing = existingRecord(for: id),
       let meta = existing["platformMeta"] as? [String: Any],
       let ns = meta["notificationSettings"] as? [String: Any] {
        explicitPayload = ns["payload"] as? String
    }
    let payloadStr = explicitPayload ?? (userInfo[Self.userInfoPayloadJsonKey] as? String)
    
    defaults.set(id, forKey: Self.defaultsLaunchAlarmIdKey)
    markTriggeredAndEmit(id: id, triggerDate: Date())
    emitNotificationResponse(
      alarmId: id,
      actionId: response.actionIdentifier,
      payload: payloadStr,
      type: response.actionIdentifier == UNNotificationDefaultActionIdentifier ? 0 : 1
    )

    if response.actionIdentifier == Self.actionStopId {
      stopRinging()
      updateStatus(id: id, status: "stopped")
      emitEvent(type: "stopped", id: id, alarm: existingRecord(for: id), meta: [:])
    } else if response.actionIdentifier == Self.actionSnoozeId {
      stopRinging()
      if let existing = existingRecord(for: id) {
        let nextMs = now() + Int64(Self.defaultSnoozeMinutes) * 60_000
        var record = existing
        record["scheduledTimeUtcMs"] = nextMs
        record["scheduledTimeLocalIso"] = isoFromMillis(nextMs)
        record["status"] = "snoozed"
        record["updatedAtMs"] = now()
        record["platformMeta"] = ["snoozeMinutes": Self.defaultSnoozeMinutes]
        upsertRecord(record)
        let fireDate = Date(timeIntervalSince1970: TimeInterval(nextMs) / 1000.0)
        scheduleNotification(
          record: record,
          fireDate: fireDate
        )
        scheduleAudioTimer(record: record, fireDate: fireDate)
        emitEvent(
          type: "snoozed",
          id: id,
          alarm: record,
          meta: ["minutes": Self.defaultSnoozeMinutes]
        )
      }
    }
    if let previous = previousNotificationDelegate,
       previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      previous.userNotificationCenter?(center, didReceive: response) {
        completionHandler()
      }
      return
    }
    completionHandler()
  }

  private func markTriggeredAndEmit(id: String, triggerDate: Date) {
    var store = loadStore()
    guard var record = store[id] else { return }
    let nowMs = Int64(triggerDate.timeIntervalSince1970 * 1000)
    let scheduledMs = int64Value(record["scheduledTimeUtcMs"]) ?? nowMs
    record["status"] = "triggered"
    record["updatedAtMs"] = nowMs
    record["lastTriggeredAtMs"] = nowMs
    record["lastDriftMs"] = nowMs - scheduledMs
    store[id] = record
    saveStore(store)
    emitEvent(type: "triggered", id: id, alarm: record, meta: ["driftMs": nowMs - scheduledMs])
  }

  private func int64Value(_ value: Any?) -> Int64? {
    if let v = value as? Int64 {
      return v
    }
    if let v = value as? Int {
      return Int64(v)
    }
    if let v = value as? NSNumber {
      return v.int64Value
    }
    if let v = value as? String {
      return Int64(v)
    }
    return nil
  }

  private func emitNotificationResponse(
    alarmId: String,
    actionId: String?,
    payload: String?,
    type: Int
  ) {
    let responseMap: [String: Any] = [
      "notificationId": alarmId.hashValue,
      "alarmId": alarmId,
      "actionId": actionId ?? "",
      "input": NSNull(),
      "payload": payload ?? "",
      "notificationResponseType": type,
      "data": ["alarmId": alarmId]
    ]
    defaults.set(responseMap, forKey: Self.defaultsPendingNotificationResponseKey)
    methodChannel?.invokeMethod("didReceiveNotificationResponse", arguments: responseMap)
  }

    // MARK: - Asset Helpers
    private func resolveSoundAsset(_ assetPath: String?) -> String? {
    guard let assetPath = assetPath, !assetPath.isEmpty else { return nil }
    let fileName = URL(fileURLWithPath: assetPath).lastPathComponent
    let fileManager = FileManager.default
    guard let libraryUrl = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
    let soundsUrl = libraryUrl.appendingPathComponent("Sounds")
    let destinationUrl = soundsUrl.appendingPathComponent(fileName)

    if !fileManager.fileExists(atPath: destinationUrl.path) {
        guard let key = self.registrar?.lookupKey(forAsset: assetPath),
              let sourcePath = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
        do {
            try fileManager.createDirectory(at: soundsUrl, withIntermediateDirectories: true, attributes: nil)
            try fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: destinationUrl)
        } catch {
            return nil
        }
    }
    return fileName
    }

      private func resolveImageAsset(_ assetPath: String?) -> UNNotificationAttachment? {
        guard let assetPath = assetPath, !assetPath.isEmpty else { return nil }
        guard let key = self.registrar?.lookupKey(forAsset: assetPath),
              let sourcePath = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
        let url = URL(fileURLWithPath: sourcePath)
        do {
            return try UNNotificationAttachment(identifier: UUID().uuidString, url: url, options: nil)
        } catch {
            return nil
        }
      }

      private func resolveImageUrl(_ urlString: String?) -> UNNotificationAttachment? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        let fileManager = FileManager.default
        let tmpDir = NSTemporaryDirectory()
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let fileName = "alarm_plus_img_\(UUID().uuidString).\(ext)"
        let tmpFile = (tmpDir as NSString).appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: url)
            try data.write(to: URL(fileURLWithPath: tmpFile))
            let attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: URL(fileURLWithPath: tmpFile), options: nil)
            return attachment
        } catch {
            return nil
        }
      }

  // MARK: - Audio Timers and Background Logic

  private func scheduleAudioTimer(record: [String: Any], fireDate: Date) {
      guard let id = record["id"] as? String else { return }
      cancelAudioTimer(id: id)

      let timeInterval = fireDate.timeIntervalSinceNow
      if timeInterval <= 0 {
          startRinging(record: record)
      } else {
          let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
              self?.activeTimers.removeValue(forKey: id)
              self?.startRinging(record: record)
          }
          RunLoop.main.add(timer, forMode: .common)
          activeTimers[id] = timer
          startSilentPlayer()
      }
  }

  private func cancelAudioTimer(id: String) {
      activeTimers[id]?.invalidate()
      activeTimers.removeValue(forKey: id)
      if activeTimers.isEmpty && alarmAudioPlayer == nil {
          stopSilentPlayer()
      }
  }

  private func startSilentPlayer() {
      if silentAudioPlayer != nil { return }
      let audioSession = AVAudioSession.sharedInstance()
      do {
          try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
          try audioSession.setActive(true)
      } catch { }

      if let data = Data(base64Encoded: silentWavBase64) {
          do {
              silentAudioPlayer = try AVAudioPlayer(data: data)
              silentAudioPlayer?.numberOfLoops = -1
              silentAudioPlayer?.volume = 0.01
              silentAudioPlayer?.play()
              NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
          } catch { }
      }
  }

  private func stopSilentPlayer() {
      NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
      silentAudioPlayer?.stop()
      silentAudioPlayer = nil
  }

  @objc private func handleInterruption(notification: Notification) {
      guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

      if type == .began || type == .ended {
          silentAudioPlayer?.play()
      }
  }

  private func startRinging(record: [String: Any]) {
      let platformMeta = record["platformMeta"] as? [String: Any]
      let ns = platformMeta?["notificationSettings"] as? [String: Any]
      let soundAsset = ns?["soundAsset"] as? String
      let volumeSettings = ns?["volumeSettings"] as? [String: Any]
      let vibrationSettings = ns?["vibrationSettings"] as? [String: Any]

      let audioSession = AVAudioSession.sharedInstance()
      do {
          try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
          try audioSession.setActive(true)
      } catch { }

      var audioURL: URL?
      if let asset = soundAsset, let key = registrar?.lookupKey(forAsset: asset), let path = Bundle.main.path(forResource: key, ofType: nil) {
          audioURL = URL(fileURLWithPath: path)
      }

      if audioURL == nil {
          // Fallback to a system sound if asset not found or not provided
          audioURL = Bundle.main.url(forResource: "alarm", withExtension: "mp3") // Example fallback
      }

      guard let url = audioURL else { return }

      do {
          alarmAudioPlayer = try AVAudioPlayer(contentsOf: url)
          alarmAudioPlayer?.numberOfLoops = -1
          
          applyVolumeSettings(volumeSettings)
          applyVibrationSettings(vibrationSettings)
          
          alarmAudioPlayer?.play()
      } catch { }
  }

  private func applyVolumeSettings(_ settings: [String: Any]?) {
      guard let player = alarmAudioPlayer else { return }
      
      let vol = settings?["volume"] as? Double
      let fadeDurationMs = settings?["fadeDurationMs"] as? Double
      let fadeSteps = settings?["fadeSteps"] as? [[String: Any]]
      let volumeEnforced = settings?["volumeEnforced"] as? Bool ?? false

      let targetVolume = Float(vol ?? 1.0)
      
      if let steps = fadeSteps, !steps.isEmpty {
          player.volume = 0
          for step in steps {
              let stepVol = Float(step["volume"] as? Double ?? 1.0)
              let atMs = step["atMs"] as? Double ?? 0
              Timer.scheduledTimer(withTimeInterval: atMs / 1000.0, repeats: false) { _ in
                  player.setVolume(stepVol, fadeDuration: 0)
              }
          }
      } else if let fadeMs = fadeDurationMs, fadeMs > 0 {
          player.volume = 0
          player.setVolume(targetVolume, fadeDuration: fadeMs / 1000.0)
      } else {
          player.volume = targetVolume
      }

      if volumeEnforced {
          previousSystemVolume = AVAudioSession.sharedInstance().outputVolume
          volumeEnforcementTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
              // iOS doesn't allow programmatic system volume change easily without private APIs or MPVolumeView
              // But we can ensure OUR player volume stays at target
              if player.volume != targetVolume && (fadeSteps == nil || fadeSteps!.isEmpty) && (fadeDurationMs == nil || fadeDurationMs! <= 0) {
                  player.volume = targetVolume
              }
          }
      }
  }

  private func applyVibrationSettings(_ settings: [String: Any]?) {
      let enabled = settings?["enabled"] as? Bool ?? true
      if !enabled { return }
      
      let preset = settings?["preset"] as? String ?? "medium"
      let continuous = settings?["continuous"] as? Bool ?? true
      let customPattern = settings?["customPattern"] as? [Int]
      
      if preset == "custom", let pattern = customPattern, !pattern.isEmpty {
          var index = 0
          let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
              if index >= pattern.count {
                  if continuous {
                      index = 0
                  } else {
                      timer.invalidate()
                      return
                  }
              }
              
              let duration = Double(pattern[index]) / 1000.0
              if index % 2 != 0 {
                  // Vibrate during odd indices (wait, VIBRATE, wait, VIBRATE)
                  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
              }
              
              // We need a more precise way to handle variable durations if we want to follow 'pattern' exactly.
              // For now, this is a best-effort approximation for iOS background vibration.
              index += 1
          }
          activeTimers["vibration"] = timer
      } else {
          let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: continuous) { _ in
              switch preset {
              case "strong":
                  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
              case "heartbeat":
                  AudioServicesPlaySystemSound(1521)
              case "light":
                  AudioServicesPlaySystemSound(1519)
              default:
                  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
              }
          }
          activeTimers["vibration"] = timer
      }
  }

  private func stopRinging() {
      alarmAudioPlayer?.stop()
      alarmAudioPlayer = nil
      volumeEnforcementTimer?.invalidate()
      volumeEnforcementTimer = nil
      activeTimers["vibration"]?.invalidate()
      activeTimers.removeValue(forKey: "vibration")

      if activeTimers.isEmpty {
          stopSilentPlayer()
      } else {
          startSilentPlayer()
      }
  }

}
