/// Represents the complete state of a scheduled alarm.
///
/// This is the primary data model for alarms, persisted on both Android
/// (Room database) and iOS (UserDefaults). Contains alarm identification,
/// scheduling details, status, timing metrics, and retry information.
///
/// **Status Values**:
/// - `scheduled`: Alarm is waiting to fire
/// - `triggered`: Alarm has fired (currently ringing)
/// - `snoozed`: Alarm was snoozed; will reschedule
/// - `stopped`: Alarm was manually stopped by user
/// - `canceled`: Alarm was cancelled (paused)
/// - `error`: Scheduling or trigger error occurred
///
/// **Example**:
/// ```dart
/// final alarms = await AlarmPlus.getAll();
/// for (final alarm in alarms) {
///   print('ID: ${alarm.id}, Status: ${alarm.status}');
///   print('Scheduled: ${alarm.scheduledTimeLocalIso}');
///   if (alarm.lastDriftMs != null) {
///     print('Last drift: ${alarm.lastDriftMs}ms');
///   }
/// }
/// ```
class AlarmModel {
  /// Creates an [AlarmModel] instance.
  const AlarmModel({
    required this.id,
    required this.scheduledTimeUtcMs,
    required this.scheduledTimeLocalIso,
    required this.payloadJson,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.lastTriggeredAtMs,
    required this.lastDriftMs,
    required this.retryCount,
    required this.nextRetryAtMs,
    required this.platformMeta,
  });

  /// Deserializes an alarm from a map (typically from native platform).
  ///
  /// Uses defensive casting to handle platform data type mismatches.
  /// Converts numeric strings to integers, handles missing fields gracefully.
  factory AlarmModel.fromMap(Map<String, dynamic> map) {
    return AlarmModel(
      id: (map['id'] ?? '').toString(),
      scheduledTimeUtcMs: (map['scheduledTimeUtcMs'] as num?)?.toInt() ?? 0,
      scheduledTimeLocalIso: (map['scheduledTimeLocalIso'] ?? '').toString(),
      payloadJson: map['payloadJson']?.toString(),
      status: (map['status'] ?? '').toString(),
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt() ?? 0,
      lastTriggeredAtMs: (map['lastTriggeredAtMs'] as num?)?.toInt(),
      lastDriftMs: (map['lastDriftMs'] as num?)?.toInt(),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      nextRetryAtMs: (map['nextRetryAtMs'] as num?)?.toInt(),
      platformMeta: (map['platformMeta'] is Map)
          ? Map<String, dynamic>.from(map['platformMeta'] as Map)
          : <String, dynamic>{},
    );
  }

  /// Unique identifier for this alarm.
  ///
  /// Used to reference, update, or delete alarms. Should be alphanumeric
  /// and unique across all scheduled alarms in the app.
  final String id;

  /// Scheduled fire time in milliseconds since epoch (UTC).
  ///
  /// Always stored and transmitted in UTC. Convert to local time using
  /// [scheduledTimeLocalIso] for display, or [scheduledTimeUtc] getter.
  final int scheduledTimeUtcMs;

  /// Scheduled fire time in ISO8601 local format (human-readable).
  ///
  /// String representation in the device's local timezone. Use for
  /// UI display without additional conversion.
  /// Example: `"2026-05-19T07:30:00.000"`
  final String scheduledTimeLocalIso;

  /// Custom payload as JSON string (nullable).
  ///
  /// Application-specific metadata passed at scheduling. Not used by
  /// the plugin; purely for app data storage. Persisted to database.
  final String? payloadJson;

  /// Current status of the alarm.
  ///
  /// One of: `scheduled`, `triggered`, `snoozed`, `stopped`, `canceled`,
  /// `error`.
  /// Indicates the lifecycle state of the alarm.
  final String status;

  /// Timestamp when alarm was created (milliseconds since epoch, UTC).
  final int createdAtMs;

  /// Timestamp when alarm was last updated (milliseconds since epoch, UTC).
  final int updatedAtMs;

  /// Timestamp when alarm was last triggered (milliseconds since epoch, UTC).
  ///
  /// Null if alarm has not triggered yet. Useful for detecting if an
  /// alarm has fired at least once.
  final int? lastTriggeredAtMs;

  /// Drift in milliseconds: (actual trigger time - scheduled time).
  ///
  /// Indicates scheduling accuracy. Positive means late, negative means early.
  /// Null if alarm never triggered. On Android, tracks within ~100ms. On iOS,
  /// limited accuracy due to OS notification dispatch timing.
  ///
  /// **Example**:
  /// ```dart
  /// if (alarm.lastDriftMs != null) {
  ///   if (alarm.lastDriftMs! > 1000) {
  ///     print('Alarm was ${alarm.lastDriftMs}ms late');
  ///   }
  /// }
  /// ```
  final int? lastDriftMs;

  /// Number of retry attempts (if applicable).
  ///
  /// For future use. Currently bounded between 0 and 3. Allows apps to
  /// track and react to repeating failures.
  final int retryCount;

  /// Timestamp of next scheduled retry (milliseconds since epoch, UTC).
  ///
  /// Null if no retry is pending. Used internally by the plugin for
  /// bounded retry scheduling.
  final int? nextRetryAtMs;

  /// Platform-specific runtime metadata.
  ///
  /// Contains platform-unique state during execution. Example on Android:
  /// `{ 'wake_lock_tag': 'AlarmPlus::1234', 'foreground_service_id': 5001 }`.
  /// Empty on first creation; populated by native layer at runtime.
  final Map<String, dynamic> platformMeta;

  /// Converts [scheduledTimeUtcMs] to a UTC [DateTime].
  DateTime get scheduledTimeUtc =>
      DateTime.fromMillisecondsSinceEpoch(scheduledTimeUtcMs, isUtc: true);

  /// Serializes this alarm to a map (for transmission to native platform).
  ///
  /// Inverse of [AlarmModel.fromMap]. Use when passing alarm state to native
  /// code or storing in local JSON.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'scheduledTimeUtcMs': scheduledTimeUtcMs,
      'scheduledTimeLocalIso': scheduledTimeLocalIso,
      'payloadJson': payloadJson,
      'status': status,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
      'lastTriggeredAtMs': lastTriggeredAtMs,
      'lastDriftMs': lastDriftMs,
      'retryCount': retryCount,
      'nextRetryAtMs': nextRetryAtMs,
      'platformMeta': platformMeta,
    };
  }
}
