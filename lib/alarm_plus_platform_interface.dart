import 'package:alarm_plus/alarm_plus_method_channel.dart';
import 'package:alarm_plus/src/models/alarm_event.dart';
import 'package:alarm_plus/src/models/alarm_model.dart';
import 'package:alarm_plus/src/models/alarm_notification_settings.dart';
import 'package:alarm_plus/src/models/alarm_permission_status.dart';
import 'package:alarm_plus/src/models/notification_response.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Abstract interface for platform-specific alarm implementations.
///
/// This interface defines the contract that platform-specific implementations
/// (Android, iOS) must fulfill. The Dart layer uses this interface to remain
/// abstracted from platform details.
///
/// Platform implementations should extend this class and override all methods.
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

  /// Initializes the platform-specific alarm implementation.
  ///
  /// Must be called once at app startup before any alarm operations.
  /// Sets up channels, listeners, and retrieves any pending notification responses.
  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Triggers an alarm immediately without persistent scheduling.
  Future<void> triggerNow({
    required Map<String, dynamic> data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    throw UnimplementedError('triggerNow() has not been implemented.');
  }

  /// Schedules a persistent alarm to fire at the given time.
  Future<void> schedule({
    required String id,
    required DateTime time,
    Map<String, dynamic>? data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    throw UnimplementedError('schedule() has not been implemented.');
  }

  /// Pauses (cancels) an alarm, transitioning it to "scheduled" status.
  Future<void> cancel(String id) {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Permanently removes an alarm from persistent storage.
  Future<void> delete(String id) {
    throw UnimplementedError('delete() has not been implemented.');
  }

  /// Stops the currently ringing alarm.
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Reschedules an alarm to fire after the specified number of minutes.
  Future<void> snooze({required String id, required int minutes}) {
    throw UnimplementedError('snooze() has not been implemented.');
  }

  /// Retrieves all scheduled alarms.
  Future<List<AlarmModel>> getAll() {
    throw UnimplementedError('getAll() has not been implemented.');
  }

  /// A broadcast stream of alarm state change events.
  Stream<AlarmEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Retrieves the alarm that triggered app launch, if any.
  Future<AlarmModel?> getLaunchAlarm() {
    throw UnimplementedError('getLaunchAlarm() has not been implemented.');
  }

  /// Queries current alarm-related permissions.
  Future<AlarmPermissionStatus> getPermissionStatus() {
    throw UnimplementedError('getPermissionStatus() has not been implemented.');
  }

  /// Requests necessary permissions from the user.
  Future<AlarmPermissionStatus> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }
}
