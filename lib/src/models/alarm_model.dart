class AlarmModel {
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

  final String id;
  final int scheduledTimeUtcMs;
  final String scheduledTimeLocalIso;
  final String? payloadJson;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;
  final int? lastTriggeredAtMs;
  final int? lastDriftMs;
  final int retryCount;
  final int? nextRetryAtMs;
  final Map<String, dynamic> platformMeta;

  DateTime get scheduledTimeUtc =>
      DateTime.fromMillisecondsSinceEpoch(scheduledTimeUtcMs, isUtc: true);

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
}
