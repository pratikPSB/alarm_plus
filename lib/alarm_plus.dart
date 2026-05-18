import 'package:alarm_plus/src/models/alarm_notification_settings.dart';

import 'alarm_plus_platform_interface.dart';
import 'src/models/alarm_event.dart';
import 'src/models/alarm_model.dart';
import 'src/models/alarm_permission_status.dart';
import 'src/models/notification_response.dart';

export 'src/models/alarm_event.dart';
export 'src/models/alarm_model.dart';
export 'src/models/alarm_notification_settings.dart';
export 'src/models/alarm_permission_status.dart';
export 'src/models/notification_response.dart';

class AlarmPlus {
  AlarmPlus._();

  static Future<void> initialize({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) {
    return AlarmPlusPlatform.instance.initialize(
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );
  }

  static Future<void> triggerNow({
    required Map<String, dynamic> data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    return AlarmPlusPlatform.instance.triggerNow(
      data: data,
      notificationSettings: notificationSettings,
    );
  }

  static Future<void> schedule({
    required String id,
    required DateTime time,
    Map<String, dynamic>? data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    return AlarmPlusPlatform.instance.schedule(
      id: id,
      time: time,
      data: data,
      notificationSettings: notificationSettings,
    );
  }

  static Future<void> cancel(String id) {
    return AlarmPlusPlatform.instance.cancel(id);
  }

  static Future<void> delete(String id) {
    return AlarmPlusPlatform.instance.delete(id);
  }

  static Future<void> stop() {
    return AlarmPlusPlatform.instance.stop();
  }

  static Future<void> snooze(String id, int minutes) {
    return AlarmPlusPlatform.instance.snooze(id: id, minutes: minutes);
  }

  static Future<List<AlarmModel>> getAll() {
    return AlarmPlusPlatform.instance.getAll();
  }

  static Stream<AlarmEvent> get events => AlarmPlusPlatform.instance.events;

  static Future<AlarmModel?> getLaunchAlarm() {
    return AlarmPlusPlatform.instance.getLaunchAlarm();
  }

  static Future<AlarmPermissionStatus> getPermissionStatus() {
    return AlarmPlusPlatform.instance.getPermissionStatus();
  }

  static Future<AlarmPermissionStatus> requestPermissions() {
    return AlarmPlusPlatform.instance.requestPermissions();
  }
}
