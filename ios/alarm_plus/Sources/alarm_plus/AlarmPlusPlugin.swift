import Flutter
import UIKit

public class AlarmPlusPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var manager: PluginAlarmManager?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AlarmPlusPlugin()
    instance.manager = PluginAlarmManager(registrar: registrar)

    let channel = FlutterMethodChannel(name: AlarmConstants.methodChannelName, binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: AlarmConstants.eventChannelName, binaryMessenger: registrar.messenger())

    instance.manager?.methodChannel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let manager = manager else {
        result(FlutterError(code: "ERR_NOT_INITIALIZED", message: "AlarmManager not initialized", details: nil))
        return
    }

    switch call.method {
    case "initialize": result(nil)
    case "getBackgroundCallbackHandle": result(nil)
    case "getLastNotificationResponse": manager.getLastNotificationResponse(result: result)
    case "triggerNow":
      let args = call.arguments as? [String: Any] ?? [:]
      manager.triggerNow(data: args["data"] as? [String: Any] ?? [:], settings: args["notificationSettings"] as? [String: Any], result: result)
    case "schedule":
      manager.schedule(args: call.arguments as? [String: Any] ?? [:], result: result)
    case "cancel":
      let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
      manager.cancel(id: id, result: result)
    case "delete":
      let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
      manager.delete(id: id, result: result)
    case "stop": manager.stop(result: result)
    case "snooze":
      let args = call.arguments as? [String: Any] ?? [:]
      let id = args["id"] as? String ?? ""
      let mins = (args["minutes"] as? NSNumber)?.intValue ?? AlarmConstants.defaultSnoozeMinutes
      manager.snooze(id: id, minutes: mins, result: result)
    case "getAll": manager.getAll(result: result)
    case "getLaunchAlarm": manager.getLaunchAlarm(result: result)
    case "getPermissionStatus": manager.getPermissionStatus(result: result)
    case "requestPermissions": manager.requestPermissions(result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    manager?.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager?.eventSink = nil
    return nil
  }
}
