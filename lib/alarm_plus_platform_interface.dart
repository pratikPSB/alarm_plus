import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'alarm_plus_method_channel.dart';
import 'src/models/alarm_event.dart';
import 'src/models/alarm_model.dart';
import 'src/models/alarm_notification_settings.dart';
import 'src/models/alarm_permission_status.dart';
import 'src/models/notification_response.dart';

abstract class AlarmPlusPlatform extends PlatformInterface {
  /// Constructs a AlarmPlusPlatform.
  AlarmPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static AlarmPlusPlatform _instance = MethodChannelAlarmPlus();

  /// The default instance of [AlarmPlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelAlarmPlus].
  static AlarmPlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AlarmPlusPlatform] when
  /// they register themselves.
  static set instance(AlarmPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> triggerNow({
    required Map<String, dynamic> data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    throw UnimplementedError('triggerNow() has not been implemented.');
  }

  Future<void> schedule({
    required String id,
    required DateTime time,
    Map<String, dynamic>? data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    throw UnimplementedError('schedule() has not been implemented.');
  }

  Future<void> cancel(String id) {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  Future<void> delete(String id) {
    throw UnimplementedError('delete() has not been implemented.');
  }

  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  Future<void> snooze({required String id, required int minutes}) {
    throw UnimplementedError('snooze() has not been implemented.');
  }

  Future<List<AlarmModel>> getAll() {
    throw UnimplementedError('getAll() has not been implemented.');
  }

  Stream<AlarmEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  Future<AlarmModel?> getLaunchAlarm() {
    throw UnimplementedError('getLaunchAlarm() has not been implemented.');
  }

  Future<AlarmPermissionStatus> getPermissionStatus() {
    throw UnimplementedError('getPermissionStatus() has not been implemented.');
  }

  Future<AlarmPermissionStatus> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }
}
