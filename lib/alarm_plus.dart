import 'package:alarm_plus/alarm_plus_platform_interface.dart';
import 'package:alarm_plus/src/models/alarm_event.dart';
import 'package:alarm_plus/src/models/alarm_model.dart';
import 'package:alarm_plus/src/models/alarm_notification_settings.dart';
import 'package:alarm_plus/src/models/alarm_permission_status.dart';
import 'package:alarm_plus/src/models/notification_response.dart';

export 'src/models/alarm_event.dart';
export 'src/models/alarm_model.dart';
export 'src/models/alarm_notification_settings.dart';
export 'src/models/alarm_permission_status.dart';
export 'src/models/notification_response.dart';

/// The main public API for the alarm_plus plugin.
/// 
/// Provides unified cross-platform alarm scheduling and management.
/// Use this class to schedule alarms, listen to events, manage permissions,
/// and control active alarms.
/// 
/// **Initialization**: Call [initialize] once at app start before scheduling
///  alarms.
/// 
/// **Example**:
/// ```dart
/// await AlarmPlus.initialize(
///   onDidReceiveNotificationResponse: (response) {
///     // Handle foreground notification tap
///   },
/// );
/// await AlarmPlus.schedule(
///   id: 'my_alarm',
///   time: DateTime.now().add(Duration(minutes: 5)),
/// );
/// ```
class AlarmPlus {
  AlarmPlus._();

  /// Initializes the alarm_plus plugin.
  ///
  /// Must be called once at app startup before scheduling alarms.
  /// Registers callbacks for notification interactions.
  ///
  /// **Parameters**:
  /// - `onDidReceiveNotificationResponse`: Callback when user taps notification
  ///   in foreground. Called in the main isolate.
  /// - `onDidReceiveBackgroundNotificationResponse`: Callback when user interacts
  ///   with notification in background (after swiping up/app killed). Called in
  ///   a separate background isolate. Must be a top-level or static function
  ///   annotated with `@pragma('vm:entry-point')`.
  ///
  /// **Example**:
  /// ```dart
  /// @pragma('vm:entry-point')
  /// void backgroundCallback(NotificationResponse resp) {
  ///   // Handle background notification action (stop/snooze)
  /// }
  ///
  /// await AlarmPlus.initialize(
  ///   onDidReceiveNotificationResponse: (resp) => print('Tapped: ${resp.alarmId}'),
  ///   onDidReceiveBackgroundNotificationResponse: backgroundCallback,
  /// );
  /// ```
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

  /// Triggers an alarm immediately without scheduling.
  ///
  /// Useful for testing or displaying an instant alarm notification.
  /// The alarm will not be persisted and will not reschedule on reboot.
  ///
  /// **Parameters**:
  /// - `data`: Custom app data (e.g., `{'title': 'Test', 'id': 'debug'}`).
  ///   Not persisted; for immediate use only.
  /// - `notificationSettings`: Customizes notification UI/audio. If null,
  ///   platform defaults are used.
  ///
  /// **Example**:
  /// ```dart
  /// await AlarmPlus.triggerNow(
  ///   data: {'source': 'debug'},
  ///   notificationSettings: const AlarmNotificationSettings(
  ///     title: 'Quick Alarm',
  ///     body: 'Testing notification',
  ///   ),
  /// );
  /// ```
  static Future<void> triggerNow({
    required Map<String, dynamic> data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    return AlarmPlusPlatform.instance.triggerNow(
      data: data,
      notificationSettings: notificationSettings,
    );
  }

  /// Schedules an alarm to fire at a specific time.
  ///
  /// **Android**: Uses exact alarm scheduling (`AlarmManager.setExactAndAllowWhileIdle`).
  /// Alarms persist in device database and reschedule after reboot.
  ///
  /// **iOS**: Uses `UNUserNotificationCenter` for best-effort scheduling.
  /// Notifications survive reboot per OS policy.
  ///
  /// **Parameters**:
  /// - `id`: Unique identifier for this alarm. Used to cancel/snooze.
  ///   Should be alphanumeric and unique across all scheduled alarms.
  /// - `time`: Local DateTime when alarm should fire. Plugin automatically
  ///   converts to UTC for storage. Pass local time; it will be converted.
  /// - `data`: Custom app-specific JSON data (e.g., alarm metadata).
  ///   Serialized as JSON string. Persisted to database.
  /// - `notificationSettings`: Customizes notification appearance, audio, and action texts.
  ///
  /// **Returns**: Completes when scheduling request is sent to native platform.
  ///
  /// **Throws**: Platform exceptions if permissions denied or scheduling fails.
  ///
  /// **Example**:
  /// ```dart
  /// final tomorrow = DateTime.now().add(Duration(days: 1)).copyWith(
  ///   hour: 7, minute: 0, second: 0, millisecond: 0,
  /// );
  /// await AlarmPlus.schedule(
  ///   id: 'morning_alarm',
  ///   time: tomorrow,
  ///   data: {'type': 'morning', 'label': 'Wake up'},
  ///   notificationSettings: const AlarmNotificationSettings(
  ///     title: 'Good Morning',
  ///     body: 'Time to start your day',
  ///     soundAsset: 'assets/alarm.mp3',
  ///   ),
  /// );
  /// ```
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

  /// Pauses (snoozes) an alarm without deleting it.
  ///
  /// Moves alarm to "scheduled" status and reschedules for a later time.
  /// The alarm is kept in the database.
  ///
  /// **Android**: Reschedules via `AlarmManager.setExactAndAllowWhileIdle`.
  ///
  /// **iOS**: Updates notification trigger time and reschedules via
  /// `UNUserNotificationCenter`.
  ///
  /// **Parameters**:
  /// - `id`: The alarm ID to cancel. If not found, request completes silently.
  ///
  /// **Note**: Differs from [stop] which halts the current alarm sound.
  ///
  /// **Example**:
  /// ```dart
  /// await AlarmPlus.cancel('morning_alarm');
  /// ```
  static Future<void> cancel(String id) {
    return AlarmPlusPlatform.instance.cancel(id);
  }

  /// Permanently removes an alarm from storage.
  ///
  /// Deletes the alarm record from database. Alarm cannot be recovered.
  /// Does not affect currently ringing alarm.
  ///
  /// **Android**: Deletes from Room database. Cancels any pending alarm.
  ///
  /// **iOS**: Removes notification request from `UNUserNotificationCenter`
  /// and deletes from UserDefaults.
  ///
  /// **Parameters**:
  /// - `id`: The alarm ID to delete.
  ///
  /// **Example**:
  /// ```dart
  /// await AlarmPlus.delete('morning_alarm');
  /// ```
  static Future<void> delete(String id) {
    return AlarmPlusPlatform.instance.delete(id);
  }

  /// Stops the currently ringing alarm.
  ///
  /// Halts audio playback and transitions alarm to "stopped" status.
  /// Alarm remains in database (not deleted).
  ///
  /// **Android**: Stops foreground ringing service and releases wake lock.
  ///
  /// **iOS**: Stops `AVAudioPlayer` looping.
  ///
  /// **Note**: This is different from [snooze] (reschedule) or [cancel]
  /// (change status to paused).
  ///
  /// **Example**:
  /// ```dart
  /// await AlarmPlus.stop();
  /// ```
  static Future<void> stop() {
    return AlarmPlusPlatform.instance.stop();
  }

  /// Reschedules a triggered alarm to fire again after [minutes].
  ///
  /// User-triggered snooze action. Alarm status changes to "snoozed",
  /// and notification is rescheduled for current time + [minutes].
  ///
  /// **Parameters**:
  /// - `id`: The alarm ID to snooze.
  /// - `minutes`: Duration in minutes to snooze. Typical value: 5–10.
  ///
  /// **Android**: Cancels current trigger and reschedules via AlarmManager.
  ///
  /// **iOS**: Updates notification trigger and reschedules via
  /// `UNUserNotificationCenter`.
  ///
  /// **Example**:
  /// ```dart
  /// await AlarmPlus.snooze('morning_alarm', 5); // Snooze 5 minutes
  /// ```
  static Future<void> snooze(String id, int minutes) {
    return AlarmPlusPlatform.instance.snooze(id: id, minutes: minutes);
  }

  /// Retrieves all scheduled alarms.
  ///
  /// Returns a list of [AlarmModel] objects sorted by scheduled time.
  /// Includes alarms in any status (scheduled, triggered, snoozed, etc.).
  ///
  /// **Android**: Queries Room database.
  ///
  /// **iOS**: Loads from UserDefaults.
  ///
  /// **Returns**: List of all alarms. Empty list if none exist.
  ///
  /// **Example**:
  /// ```dart
  /// final alarms = await AlarmPlus.getAll();
  /// for (final alarm in alarms) {
  ///   print('${alarm.id}: ${alarm.status}');
  /// }
  /// ```
  static Future<List<AlarmModel>> getAll() {
    return AlarmPlusPlatform.instance.getAll();
  }

  /// Stream of alarm state change events.
  ///
  /// Listens to [AlarmEvent] objects emitted whenever an alarm state
  /// transitions (triggered, stopped, snoozed, error, permissionChanged).
  ///
  /// This is a broadcast stream; multiple listeners can subscribe.
  ///
  /// **Event Types**:
  /// - `triggered`: Alarm fired. Includes `driftMs` (delay vs scheduled time).
  /// - `stopped`: Alarm audio stopped (user action or [stop] call).
  /// - `snoozed`: Snooze activated. Includes new snooze duration.
  /// - `error`: Scheduling or platform error. Contains error code/message.
  /// - `permissionChanged`: Permission status changed.
  ///
  /// **Example**:
  /// ```dart
  /// AlarmPlus.events.listen((event) {
  ///   switch (event.type) {
  ///     case 'triggered':
  ///       print('Alarm ${event.id} fired with ${event.meta['driftMs']}ms drift');
  ///     case 'snoozed':
  ///       print('Snoozed for ${event.meta['minutes']} minutes');
  ///     case 'error':
  ///       print('Error: ${event.errorCode} - ${event.errorMessage}');
  ///     default:
  ///       break;
  ///   }
  /// });
  /// ```
  static Stream<AlarmEvent> get events => AlarmPlusPlatform.instance.events;

  /// Retrieves the alarm that triggered app launch.
  ///
  /// When user taps a full-screen intent notification or notification while
  /// app is closed, returns the corresponding [AlarmModel].
  ///
  /// **Android**: Restored from intent extras passed to activity.
  ///
  /// **iOS**: Loaded from UserDefaults if present.
  ///
  /// **Returns**: The alarm that triggered launch, or null if none.
  /// Should be checked during app initialization.
  ///
  /// **Example**:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await AlarmPlus.initialize(...);
  ///
  ///   final launchAlarm = await AlarmPlus.getLaunchAlarm();
  ///   if (launchAlarm != null) {
  ///     print('App opened due to alarm: ${launchAlarm.id}');
  ///     // Open custom alarm screen
  ///   }
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<AlarmModel?> getLaunchAlarm() {
    return AlarmPlusPlatform.instance.getLaunchAlarm();
  }

  /// Queries current permission status across platforms.
  ///
  /// Returns [AlarmPermissionStatus] with granular permission flags.
  /// Does not request permissions; use [requestPermissions] to prompt user.
  ///
  /// **Android Flags**:
  /// - `notificationsGranted`: POST_NOTIFICATIONS (Android 13+)
  /// - `exactAlarmsGranted`: SCHEDULE_EXACT_ALARM
  /// - `fullScreenIntentGranted`: USE_FULL_SCREEN_INTENT (Android 14+)
  ///
  /// **iOS Flags** (platform differences; some always false on iOS):
  /// - `notificationsGranted`: Notification authorization status
  /// - `exactAlarmsGranted`: Always false (iOS has no exact alarm guarantee)
  /// - `fullScreenIntentGranted`: Always false (no iOS equivalent)
  /// - `criticalAlertsEligible`: Whether app can use critical alerts
  ///
  /// **Example**:
  /// ```dart
  /// final status = await AlarmPlus.getPermissionStatus();
  /// if (!status.notificationsGranted) {
  ///   print('Notifications not granted');
  /// }
  /// if (defaultTargetPlatform == TargetPlatform.android &&
  ///     !status.exactAlarmsGranted) {
  ///   print('Cannot use exact alarms');
  /// }
  /// ```
  static Future<AlarmPermissionStatus> getPermissionStatus() {
    return AlarmPlusPlatform.instance.getPermissionStatus();
  }

  /// Requests necessary permissions from the user.
  ///
  /// Prompts user for notifications, exact alarms (Android), and full-screen
  /// intent (Android 14+). Returns updated [AlarmPermissionStatus].
  ///
  /// **Android**: Shows system permission dialogs if not yet granted.
  /// May redirect to Settings app for exact alarm/full-screen intent.
  ///
  /// **iOS**: Shows notification authorization prompt if not authorized.
  ///
  /// **Returns**: Updated permission status after request completes.
  ///
  /// **Important**: Always call this before scheduling alarms to ensure
  /// user expectations align with granted permissions.
  ///
  /// **Example**:
  /// ```dart
  /// final status = await AlarmPlus.requestPermissions();
  /// if (status.notificationsGranted && status.exactAlarmsGranted) {
  ///   // Safe to schedule alarms
  ///   await AlarmPlus.schedule(...);
  /// } else {
  ///   print('Some permissions denied');
  /// }
  /// ```
  static Future<AlarmPermissionStatus> requestPermissions() {
    return AlarmPlusPlatform.instance.requestPermissions();
  }
}
