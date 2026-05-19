import 'package:alarm_plus/alarm_plus.dart';

/// Represents the current permission status for alarm operations.
///
/// Returned by [AlarmPlus.getPermissionStatus] and
/// [AlarmPlus.requestPermissions].
/// Permissions differ significantly between Android and iOS.
///
/// **Android Permissions**:
/// - `notificationsGranted`: POST_NOTIFICATIONS (Android 13+)
/// - `exactAlarmsGranted`: SCHEDULE_EXACT_ALARM
/// - `fullScreenIntentGranted`: USE_FULL_SCREEN_INTENT (Android 14+)
/// - `canOpenExactAlarmSettings`: Can open system exact alarm settings
/// - `canOpenFullScreenSettings`: Can open full-screen intent settings
///
/// **iOS Permissions** (platform-specific adaptations):
/// - `notificationsGranted`: Whether notification authorization granted
/// - `exactAlarmsGranted`: Always `false` (iOS has no exact alarm guarantee)
/// - `fullScreenIntentGranted`: Always `false` (iOS has no full-screen intent)
/// - `criticalAlertsEligible`: Whether app can use critical alerts
///
/// **Example**:
/// ```dart
/// final status = await AlarmPlus.getPermissionStatus();
/// if (!status.notificationsGranted) {
///   print('Notifications not authorized');
///   await AlarmPlus.requestPermissions();
/// }
/// if (defaultTargetPlatform == TargetPlatform.android) {
///   if (!status.exactAlarmsGranted) {
///     print('Cannot schedule exact alarms');
///   }
/// }
/// ```
class AlarmPermissionStatus {
  /// Creates a permission status instance.
  const AlarmPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.fullScreenIntentGranted,
    required this.canOpenExactAlarmSettings,
    required this.canOpenFullScreenSettings,
    required this.criticalAlertsEligible,
    required this.platformMeta,
  });

  /// Deserializes permission status from a map.
  factory AlarmPermissionStatus.fromMap(Map<String, dynamic> map) {
    return AlarmPermissionStatus(
      notificationsGranted: map['notificationsGranted'] == true,
      exactAlarmsGranted: map['exactAlarmsGranted'] == true,
      fullScreenIntentGranted: map['fullScreenIntentGranted'] == true,
      canOpenExactAlarmSettings: map['canOpenExactAlarmSettings'] == true,
      canOpenFullScreenSettings: map['canOpenFullScreenSettings'] == true,
      criticalAlertsEligible: map['criticalAlertsEligible'] == true,
      platformMeta: (map['platformMeta'] is Map)
          ? Map<String, dynamic>.from(map['platformMeta'] as Map)
          : <String, dynamic>{},
    );
  }

  /// Whether notification permissions are granted.
  ///
  /// Required for any alarm notification display.
  /// - **Android**: POST_NOTIFICATIONS (Android 13+)
  /// - **iOS**: Notification authorization granted
  final bool notificationsGranted;

  /// Whether exact alarm scheduling permission is granted.
  ///
  /// Enables [AlarmPlus] to fire alarms at precise times.
  /// - **Android**: SCHEDULE_EXACT_ALARM (Android 12+)
  /// - **iOS**: Always `false` (not supported by OS)
  final bool exactAlarmsGranted;

  /// Whether full-screen intent permission is granted.
  ///
  /// Enables lock-screen display of alarms.
  /// - **Android**: USE_FULL_SCREEN_INTENT (Android 14+)
  /// - **iOS**: Always `false` (equivalent functionality via notifications)
  final bool fullScreenIntentGranted;

  /// Whether app can open system exact alarm settings page.
  ///
  /// Android only. Indicates if user can be directed to settings
  /// to grant exact alarm permission.
  final bool canOpenExactAlarmSettings;

  /// Whether app can open system full-screen intent settings page.
  ///
  /// Android only. Indicates if user can be directed to settings
  /// to grant full-screen intent permission.
  final bool canOpenFullScreenSettings;

  /// Whether app is eligible for critical alerts.
  ///
  /// iOS only. Critical alerts bypass Do Not Disturb and mute settings.
  /// Requires user opt-in and app configuration.
  final bool criticalAlertsEligible;

  /// Platform-specific metadata.
  ///
  /// Contains additional permission state from native layer.
  /// Example: Android power-saving mode status.
  final Map<String, dynamic> platformMeta;

  /// Serializes permission status to a map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'notificationsGranted': notificationsGranted,
      'exactAlarmsGranted': exactAlarmsGranted,
      'fullScreenIntentGranted': fullScreenIntentGranted,
      'canOpenExactAlarmSettings': canOpenExactAlarmSettings,
      'canOpenFullScreenSettings': canOpenFullScreenSettings,
      'criticalAlertsEligible': criticalAlertsEligible,
      'platformMeta': platformMeta,
    };
  }
}
