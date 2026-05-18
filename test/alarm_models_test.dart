import 'package:alarm_plus/alarm_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AlarmModel round trip map', () {
    const model = AlarmModel(
      id: 'a1',
      scheduledTimeUtcMs: 1000,
      scheduledTimeLocalIso: '2026-01-01T00:00:01Z',
      payloadJson: '{"a":1}',
      status: 'scheduled',
      createdAtMs: 10,
      updatedAtMs: 20,
      lastTriggeredAtMs: null,
      lastDriftMs: null,
      retryCount: 1,
      nextRetryAtMs: 3000,
      platformMeta: <String, dynamic>{'k': 'v'},
    );

    final map = model.toMap();
    final parsed = AlarmModel.fromMap(map);
    expect(parsed.id, 'a1');
    expect(parsed.retryCount, 1);
    expect(parsed.platformMeta['k'], 'v');
  });

  test('AlarmEvent parse', () {
    final event = AlarmEvent.fromMap(<String, dynamic>{
      'type': 'error',
      'atMs': 123,
      'id': 'a1',
      'errorCode': 'ERR',
      'errorMessage': 'bad',
      'meta': <String, dynamic>{'m': 1},
    });

    expect(event.type, 'error');
    expect(event.errorCode, 'ERR');
    expect(event.meta['m'], 1);
  });

  test('AlarmPermissionStatus parse', () {
    final status = AlarmPermissionStatus.fromMap(<String, dynamic>{
      'notificationsGranted': true,
      'exactAlarmsGranted': false,
      'fullScreenIntentGranted': true,
      'canOpenExactAlarmSettings': true,
      'canOpenFullScreenSettings': false,
      'criticalAlertsEligible': false,
      'platformMeta': <String, dynamic>{'sdkInt': 34},
    });
    expect(status.notificationsGranted, isTrue);
    expect(status.fullScreenIntentGranted, isTrue);
    expect(status.platformMeta['sdkInt'], 34);
  });

  test('NotificationResponse parse', () {
    final response = NotificationResponse.fromMap(<String, dynamic>{
      'notificationId': 99,
      'alarmId': 'a1',
      'actionId': 'tap',
      'payload': '{"a":1}',
      'notificationResponseType': 1,
      'data': <String, dynamic>{'alarmId': 'a1'},
    });
    expect(response.id, 99);
    expect(response.alarmId, 'a1');
    expect(
      response.notificationResponseType,
      NotificationResponseType.selectedNotificationAction,
    );
  });

  test('AlarmNotificationSettings round trip map', () {
    const settings = AlarmNotificationSettings(
      title: 'Test Title',
      body: 'Test Body',
      stopButtonText: 'Stop',
      snoozeButtonText: 'Snooze',
      soundAsset: 'assets/sound.mp3',
      icon: 'ic_icon',
      largeIconAsset: 'assets/large.png',
      bigPictureAsset: 'assets/big.jpg',
      largeIconUrl: 'https://example.com/large.png',
      bigPictureUrl: 'https://example.com/big.jpg',
      payload: 'test_payload',
    );

    final map = settings.toMap();
    final parsed = AlarmNotificationSettings.fromMap(map);

    expect(parsed.title, 'Test Title');
    expect(parsed.body, 'Test Body');
    expect(parsed.stopButtonText, 'Stop');
    expect(parsed.snoozeButtonText, 'Snooze');
    expect(parsed.soundAsset, 'assets/sound.mp3');
    expect(parsed.icon, 'ic_icon');
    expect(parsed.largeIconAsset, 'assets/large.png');
    expect(parsed.bigPictureAsset, 'assets/big.jpg');
    expect(parsed.largeIconUrl, 'https://example.com/large.png');
    expect(parsed.bigPictureUrl, 'https://example.com/big.jpg');
    expect(parsed.payload, 'test_payload');
  });
}
