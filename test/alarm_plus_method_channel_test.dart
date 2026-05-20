import 'package:alarm_plus/alarm_plus_method_channel.dart';
import 'package:alarm_plus/src/models/alarm_notification_settings.dart';
import 'package:alarm_plus/src/models/vibration_settings.dart';
import 'package:alarm_plus/src/models/volume_settings.dart';
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

  test(
    'triggerNow forwards volume and vibration settings in notificationSettings',
    () async {
      MethodCall? capturedCall;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'triggerNow') {
              capturedCall = methodCall;
            }
            return null;
          });

      await platform.triggerNow(
        data: <String, dynamic>{'id': 'quick_trigger'},
        notificationSettings: const AlarmNotificationSettings(
          volumeSettings: VolumeSettings(
            volume: 0.3,
            fadeDuration: Duration(seconds: 7),
            volumeEnforced: true,
          ),
          vibrationSettings: VibrationSettings(
            enabled: false,
            preset: VibrationPreset.light,
          ),
        ),
      );

      expect(capturedCall, isNotNull);

      final args = Map<String, dynamic>.from(capturedCall!.arguments as Map);
      final notificationSettings = Map<String, dynamic>.from(
        args['notificationSettings'] as Map,
      );
      final volumeSettings = Map<String, dynamic>.from(
        notificationSettings['volumeSettings'] as Map,
      );
      final vibrationSettings = Map<String, dynamic>.from(
        notificationSettings['vibrationSettings'] as Map,
      );

      expect(volumeSettings['volume'], 0.3);
      expect(volumeSettings['fadeDurationMs'], 7000);
      expect(volumeSettings['volumeEnforced'], isTrue);

      expect(vibrationSettings['enabled'], isFalse);
      expect(vibrationSettings['preset'], 'light');
    },
  );
}
