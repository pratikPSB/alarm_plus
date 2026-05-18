enum NotificationResponseType {
  selectedNotification,
  selectedNotificationAction,
}

class NotificationResponse {
  const NotificationResponse({
    required this.notificationResponseType,
    this.id,
    this.alarmId,
    this.actionId,
    this.input,
    this.payload,
    this.data = const <String, dynamic>{},
  });

  final int? id;
  final String? alarmId;
  final String? actionId;
  final String? input;
  final String? payload;
  final NotificationResponseType notificationResponseType;
  final Map<String, dynamic> data;

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
}

typedef DidReceiveNotificationResponseCallback =
    void Function(NotificationResponse details);

typedef DidReceiveBackgroundNotificationResponseCallback =
    void Function(NotificationResponse details);
