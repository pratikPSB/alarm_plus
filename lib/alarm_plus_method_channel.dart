import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'alarm_plus_platform_interface.dart';
import 'src/callback_dispatcher.dart';
import 'src/models/alarm_event.dart';
import 'src/models/alarm_model.dart';
import 'src/models/alarm_notification_settings.dart';
import 'src/models/alarm_permission_status.dart';
import 'src/models/notification_response.dart';

/// An implementation of [AlarmPlusPlatform] that uses method channels.
class MethodChannelAlarmPlus extends AlarmPlusPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('alarm_plus');
  final EventChannel _eventChannel = const EventChannel('alarm_plus/events');
  Stream<AlarmEvent>? _events;
  DidReceiveNotificationResponseCallback? _onDidReceiveNotificationResponse;

  @override
  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    _onDidReceiveNotificationResponse = onDidReceiveNotificationResponse;
    methodChannel.setMethodCallHandler(_handleMethodCall);
    final Map<String, Object> arguments = <String, Object>{};
    _evaluateBackgroundCallback(
      onDidReceiveBackgroundNotificationResponse,
      arguments,
    );
    await methodChannel.invokeMethod<void>('initialize', arguments);
    final Map<dynamic, dynamic>? pending = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('getLastNotificationResponse');
    if (pending != null) {
      _onDidReceiveNotificationResponse?.call(
        NotificationResponse.fromMap(Map<String, dynamic>.from(pending)),
      );
    }
  }

  @override
  Future<void> triggerNow({
    required Map<String, dynamic> data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    return methodChannel.invokeMethod<void>('triggerNow', {
      'data': data,
      if (notificationSettings != null)
        'notificationSettings': notificationSettings.toMap(),
    });
  }

  @override
  Future<void> schedule({
    required String id,
    required DateTime time,
    Map<String, dynamic>? data,
    AlarmNotificationSettings? notificationSettings,
  }) {
    return methodChannel.invokeMethod<void>('schedule', {
      'id': id,
      'timeUtcMs': time.toUtc().millisecondsSinceEpoch,
      'timeLocalIso': time.toIso8601String(),
      'data': data ?? <String, dynamic>{},
      if (notificationSettings != null)
        'notificationSettings': notificationSettings.toMap(),
    });
  }

  @override
  Future<void> cancel(String id) {
    return methodChannel.invokeMethod<void>('cancel', {'id': id});
  }

  @override
  Future<void> delete(String id) {
    return methodChannel.invokeMethod<void>('delete', {'id': id});
  }

  @override
  Future<void> stop() {
    return methodChannel.invokeMethod<void>('stop');
  }

  @override
  Future<void> snooze({required String id, required int minutes}) {
    return methodChannel.invokeMethod<void>('snooze', {
      'id': id,
      'minutes': minutes,
    });
  }

  @override
  Future<List<AlarmModel>> getAll() async {
    final List<dynamic> items =
        await methodChannel.invokeMethod<List<dynamic>>('getAll') ??
        <dynamic>[];
    return items
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => AlarmModel.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Stream<AlarmEvent> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((dynamic value) {
      final map = Map<String, dynamic>.from(value as Map);
      return AlarmEvent.fromMap(map);
    });
    return _events!;
  }

  @override
  Future<AlarmModel?> getLaunchAlarm() async {
    final Map<dynamic, dynamic>? raw = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('getLaunchAlarm');
    if (raw == null) {
      return null;
    }
    return AlarmModel.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<AlarmPermissionStatus> getPermissionStatus() async {
    final Map<dynamic, dynamic> raw =
        await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
          'getPermissionStatus',
        ) ??
        <dynamic, dynamic>{};
    return AlarmPermissionStatus.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<AlarmPermissionStatus> requestPermissions() async {
    final Map<dynamic, dynamic> raw =
        await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
          'requestPermissions',
        ) ??
        <dynamic, dynamic>{};
    return AlarmPermissionStatus.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'didReceiveNotificationResponse') {
      return;
    }
    final args = call.arguments;
    if (args is Map) {
      _onDidReceiveNotificationResponse?.call(
        NotificationResponse.fromMap(Map<String, dynamic>.from(args)),
      );
    }
  }
}

void _evaluateBackgroundCallback(
  DidReceiveBackgroundNotificationResponseCallback? callback,
  Map<String, Object> arguments,
) {
  if (callback == null) {
    return;
  }
  final callbackHandle = PluginUtilities.getCallbackHandle(callback);
  assert(callbackHandle != null, '''
The background callback needs to be either a static function or a top-level
function so it can be resolved as a Flutter entry point.
''');
  final dispatcherHandle = PluginUtilities.getCallbackHandle(
    alarmPlusCallbackDispatcher,
  );
  arguments['dispatcher_handle'] = dispatcherHandle!.toRawHandle();
  arguments['callback_handle'] = callbackHandle!.toRawHandle();
}
