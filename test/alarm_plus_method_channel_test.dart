import 'package:alarm_plus/alarm_plus_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelAlarmPlus();
  const channel = MethodChannel('alarm_plus');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getAll maps response into AlarmModel list', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'getAll') {
            return <dynamic>[
              <String, dynamic>{
                'id': 'a1',
                'scheduledTimeUtcMs': 123,
                'scheduledTimeLocalIso': '2026-01-01T00:00:00Z',
                'payloadJson': '{"foo":"bar"}',
                'status': 'scheduled',
                'createdAtMs': 1,
                'updatedAtMs': 2,
                'retryCount': 0,
                'platformMeta': <String, dynamic>{'x': 'y'},
              },
            ];
          }
          return null;
        });

    final items = await platform.getAll();
    expect(items.length, 1);
    expect(items.first.id, 'a1');
    expect(items.first.status, 'scheduled');
  });

  test('permission status maps response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method == 'getPermissionStatus') {
            return <String, dynamic>{
              'notificationsGranted': true,
              'exactAlarmsGranted': false,
              'fullScreenIntentGranted': true,
              'canOpenExactAlarmSettings': true,
              'canOpenFullScreenSettings': false,
              'criticalAlertsEligible': false,
              'platformMeta': <String, dynamic>{},
            };
          }
          return null;
        });

    final status = await platform.getPermissionStatus();
    expect(status.notificationsGranted, true);
    expect(status.exactAlarmsGranted, false);
    expect(status.fullScreenIntentGranted, true);
  });
}
