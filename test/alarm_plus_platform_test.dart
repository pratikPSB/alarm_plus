import 'package:alarm_plus/alarm_plus_method_channel.dart';
import 'package:alarm_plus/alarm_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Default platform instance is method channel', () {
    expect(AlarmPlusPlatform.instance, isA<MethodChannelAlarmPlus>());
  });
}
