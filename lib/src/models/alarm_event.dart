import 'package:alarm_plus/alarm_plus.dart';

/// Represents a state change event for an alarm.
///
/// Emitted through [AlarmPlus.events] stream whenever an alarm transitions
/// state (triggered, stopped, snoozed, error, etc.).
///
/// **Event Types** and metadata:
///
/// | Type | Meaning | Meta Fields |
/// |------|---------|-------------|
/// | `triggered` | Alarm fired and started ringing | `driftMs`: delay in ms |
/// | `stopped` | Alarm audio stopped | (empty) |
/// | `snoozed` | Snooze activated | `minutes`: snooze duration |
/// | `error` | Scheduling or runtime error | N/A; check errorCode |
/// | `permissionChanged` | Permission status changed | status map |
///
/// **Example**:
/// ```dart
/// AlarmPlus.events.listen((event) {
///   print('Event at ${event.at}: ${event.type}');
///   print('Alarm ID: ${event.id}');
///   print('Metadata: ${event.meta}');
/// });
/// ```
class AlarmEvent {
  /// Creates an [AlarmEvent].
  const AlarmEvent({
    required this.type,
    required this.atMs,
    this.id,
    this.alarm,
    this.errorCode,
    this.errorMessage,
    this.meta = const <String, dynamic>{},
  });

  /// Deserializes an event from a map (from native platform).
  factory AlarmEvent.fromMap(Map<String, dynamic> map) {
    final dynamic alarmMap = map['alarm'];
    return AlarmEvent(
      type: (map['type'] ?? '').toString(),
      atMs:
          (map['atMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      id: map['id']?.toString(),
      alarm: alarmMap is Map
          ? AlarmModel.fromMap(Map<String, dynamic>.from(alarmMap))
          : null,
      errorCode: map['errorCode']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
      meta: (map['meta'] is Map)
          ? Map<String, dynamic>.from(map['meta'] as Map)
          : <String, dynamic>{},
    );
  }

  /// The type of event.
  ///
  /// One of: `triggered`, `stopped`, `snoozed`, `error`, `permissionChanged`.
  final String type;

  /// Timestamp when event occurred (milliseconds since epoch, UTC).
  final int atMs;

  /// ID of the alarm that triggered this event.
  ///
  /// Null for `permissionChanged` events which are global, not alarm-specific.
  final String? id;

  /// Full alarm state at the time of event (nullable).
  ///
  /// Present for `triggered`, `stopped`, `snoozed` events.
  /// Null for `error` and `permissionChanged` events.
  final AlarmModel? alarm;

  /// Error code if this is an `error` type event.
  ///
  /// Examples: `ERR_SCHEDULE_FAILED`, `ERR_PERMISSION_DENIED`.
  /// Null for non-error events.
  final String? errorCode;

  /// Human-readable error message if this is an `error` type event.
  ///
  /// Null for non-error events.
  final String? errorMessage;

  /// Event-type-specific metadata.
  ///
  /// - For `triggered`: `{ 'driftMs': <int> }`
  /// - For `snoozed`: `{ 'minutes': <int> }`
  /// - For `permissionChanged`: full `AlarmPermissionStatus` map
  /// - Otherwise: empty map
  final Map<String, dynamic> meta;

  /// Converts [atMs] to a [DateTime] in UTC.
  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  /// Serializes this event to a map.
  ///
  /// Inverse of [AlarmEvent.fromMap].
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'atMs': atMs,
      'id': id,
      'alarm': alarm?.toMap(),
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'meta': meta,
    };
  }
}
