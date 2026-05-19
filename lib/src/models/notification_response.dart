import 'package:alarm_plus/alarm_plus.dart';

/// Type of notification interaction.
enum NotificationResponseType {
  /// User tapped the notification body (not an action button).
  selectedNotification,

  /// User tapped an action button (stop/snooze).
  selectedNotificationAction,
}

/// Represents user interaction with a notification.
///
/// Passed to notification response callbacks when user taps a notification
/// or action button (stop/snooze). Can be handled in both foreground
/// (main isolate) and background (separate isolate) contexts.
///
/// **Example**:
/// ```dart
/// void handleNotificationResponse(NotificationResponse response) {
///   if (response.notificationResponseType ==
///       NotificationResponseType.selectedNotificationAction) {
///     if (response.actionId == 'stop') {
///       print('User tapped Stop for alarm ${response.alarmId}');
///     } else if (response.actionId == 'snooze') {
///       print('User tapped Snooze for alarm ${response.alarmId}');
///     }
///   }
/// }
/// ```
class NotificationResponse {
  /// Creates a notification response.
  const NotificationResponse({
    required this.notificationResponseType,
    this.id,
    this.alarmId,
    this.actionId,
    this.input,
    this.payload,
    this.data = const <String, dynamic>{},
  });

  /// Deserializes a notification response from a map.
  factory NotificationResponse.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['notificationResponseType'] as num?)?.toInt() ?? 0;
    return NotificationResponse(
      id: (map['notificationId'] as num?)?.toInt(),
      alarmId: map['alarmId']?.toString(),
      actionId: map['actionId']?.toString(),
      input: map['input']?.toString(),
      payload: map['payload']?.toString(),
      notificationResponseType:
          NotificationResponseType.values[typeIndex < 0 ||
                  typeIndex >= NotificationResponseType.values.length
              ? 0
              : typeIndex],
      data: (map['data'] is Map)
          ? Map<String, dynamic>.from(map['data'] as Map)
          : <String, dynamic>{},
    );
  }

  /// OS-level notification ID.
  ///
  /// Platform-specific identifier. Used internally; not typically needed
  /// by app code unless querying notification status.
  final int? id;

  /// ID of the alarm associated with this notification.
  ///
  /// Matches the `id` parameter used in [AlarmPlus.schedule].
  /// Use to identify which alarm prompted the notification.
  final String? alarmId;

  /// ID of the action button tapped (if applicable).
  ///
  /// Values:
  /// - `'stop'`: User tapped stop/dismiss button
  /// - `'snooze'`: User tapped snooze button
  /// - `null`: User tapped notification body (not an action)
  final String? actionId;

  /// User text input from notification action (if supported).
  ///
  /// Android platforms may support input from action buttons.
  /// iOS does not support text input in notification actions.
  final String? input;

  /// Custom payload from notification settings.
  ///
  /// Value of [AlarmNotificationSettings.payload].
  /// App-specific; not used by plugin.
  final String? payload;

  /// Type of interaction (body tap vs. action button).
  final NotificationResponseType notificationResponseType;

  /// Additional app-specific data.
  ///
  /// Custom metadata passed from platform layer. Empty by default.
  final Map<String, dynamic> data;

  /// Serializes this response to a map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'notificationId': id,
      'alarmId': alarmId,
      'actionId': actionId,
      'input': input,
      'payload': payload,
      'notificationResponseType': notificationResponseType.index,
      'data': data,
    };
  }
}

/// Callback signature for notification responses in the main isolate.
///
/// Called when user interacts with a notification while app is running
/// in foreground or when app is resumed.
///
/// **Example**:
/// ```dart
/// void onNotificationResponse(NotificationResponse response) {
///   print('Notification response: ${response.alarmId}');
/// }
///
/// await AlarmPlus.initialize(
///   onDidReceiveNotificationResponse: onNotificationResponse,
/// );
/// ```
typedef DidReceiveNotificationResponseCallback =
    void Function(NotificationResponse details);

/// Callback signature for background notification responses.
///
/// Called in a **separate background isolate** when user interacts with
/// a notification after the app is swiped up or killed. The callback
/// must be a top-level or static function (not a lambda/closure).
///
/// **Important**: The background isolate is separate from the main app
/// isolate. Main isolate state, singletons, and widgets are NOT accessible.
/// Use MethodChannel to fetch state if needed.
///
/// **Example** (must be top-level):
/// ```dart
/// @pragma('vm:entry-point')
/// void backgroundNotificationHandler(NotificationResponse response) {
///   // This runs in a separate isolate
///   print('Background: User tapped ${response.alarmId}');
///   // Cannot access main isolate state here
///   // Use MethodChannel if you need to fetch state
/// }
///
/// await AlarmPlus.initialize(
///   onDidReceiveBackgroundNotificationResponse: backgroundNotificationHandler,
/// );
/// ```
typedef DidReceiveBackgroundNotificationResponseCallback =
    void Function(NotificationResponse details);
