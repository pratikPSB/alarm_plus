import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models/notification_response.dart';

@pragma('vm:entry-point')
void alarmPlusCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('alarm_plus');
  const EventChannel backgroundChannel = EventChannel('alarm_plus/actions');

  channel.invokeMethod<int>('getBackgroundCallbackHandle').then((int? handle) {
    final DidReceiveBackgroundNotificationResponseCallback? callback =
        handle == null
        ? null
        : PluginUtilities.getCallbackFromHandle(
                CallbackHandle.fromRawHandle(handle),
              )
              as DidReceiveBackgroundNotificationResponseCallback?;

    backgroundChannel
        .receiveBroadcastStream()
        .map<Map<dynamic, dynamic>>((dynamic event) => event)
        .map<Map<String, dynamic>>(
          (Map<dynamic, dynamic> event) => Map<String, dynamic>.from(event),
        )
        .listen((Map<String, dynamic> event) {
          callback?.call(NotificationResponse.fromMap(event));
        });
  });
}
