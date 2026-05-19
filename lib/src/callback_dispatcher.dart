import 'dart:ui';

import 'package:alarm_plus/alarm_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Entry point for background notification handling (separate isolate).
///
/// **INTERNAL USE ONLY** - Do not call directly. This is registered as
/// a callback dispatcher entry point and invoked by the Flutter engine
/// when background notification events occur.
///
/// This function:
/// 1. Initializes the Dart environment (WidgetsFlutterBinding)
/// 2. Retrieves the user's background callback handle from native code
/// 3. Deserializes the callback from the handle
/// 4. Listens to background notification events via EventChannel
/// 5. Invokes user's [DidReceiveBackgroundNotificationResponseCallback]
///
/// **Background Isolate Isolation**:
/// - Runs in a **separate isolate** from the main app
/// - No shared state with main app isolate
/// - Singletons are NOT shared
/// - Global variables are local to this isolate only
/// - Widgets and UI code not accessible
///
/// **To use background callbacks**:
/// 1. Define a top-level function with `@pragma('vm:entry-point')`
/// 2. Pass as `onDidReceiveBackgroundNotificationResponse` to
///    [AlarmPlus.initialize].
/// 3. Use [flutter/services:MethodChannel] to fetch app state if needed
///
/// **Example** (from app code):
/// ```dart
/// @pragma('vm:entry-point')
/// void onBackgroundNotification(NotificationResponse response) {
///   // This is called in a background isolate
///   print('Background handler: ${response.alarmId}');
/// }
///
/// await AlarmPlus.initialize(
///   onDidReceiveBackgroundNotificationResponse: onBackgroundNotification,
/// );
/// ```
@pragma('vm:entry-point')
Future<void> alarmPlusCallbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('alarm_plus');
  const backgroundChannel = EventChannel('alarm_plus/actions');

  await channel.invokeMethod<int>('getBackgroundCallbackHandle').then((handle) {
    final callback = handle == null
        ? null
        : PluginUtilities.getCallbackFromHandle(
                CallbackHandle.fromRawHandle(handle),
              )
              as DidReceiveBackgroundNotificationResponseCallback?;

    backgroundChannel
        .receiveBroadcastStream()
        .map<Map<dynamic, dynamic>>(
          (dynamic event) => event as Map<dynamic, dynamic>,
        )
        .map<Map<String, dynamic>>(
          Map<String, dynamic>.from,
        )
        .listen((event) {
          callback?.call(NotificationResponse.fromMap(event));
        });
  });
}
