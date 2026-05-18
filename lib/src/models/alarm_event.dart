import 'alarm_model.dart';

class AlarmEvent {
  const AlarmEvent({
    required this.type,
    required this.atMs,
    this.id,
    this.alarm,
    this.errorCode,
    this.errorMessage,
    this.meta = const <String, dynamic>{},
  });

  final String type;
  final int atMs;
  final String? id;
  final AlarmModel? alarm;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic> meta;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

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
}
