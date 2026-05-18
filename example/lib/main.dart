import 'package:flutter/material.dart';
import 'package:alarm_plus/alarm_plus.dart';
import 'dart:async';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final StreamController<NotificationResponse> _notificationResponseStream =
    StreamController<NotificationResponse>.broadcast();

@pragma('vm:entry-point')
void receiveBackgroundNotification(NotificationResponse notificationResponse) {
  debugPrint(
    'background notification action=${notificationResponse.actionId} alarmId=${notificationResponse.alarmId}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmPlus.initialize(
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      _notificationResponseStream.add(response);
    },
    onDidReceiveBackgroundNotificationResponse: receiveBackgroundNotification,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _idController = TextEditingController(
    text: 'morning_alarm',
  );
  final List<String> _logs = <String>[];
  final List<AlarmModel> _alarms = <AlarmModel>[];
  AlarmPermissionStatus? _permissionStatus;
  StreamSubscription<AlarmEvent>? _eventSub;
  StreamSubscription<NotificationResponse>? _notificationResponseSub;

  @override
  void initState() {
    super.initState();
    _eventSub = AlarmPlus.events.listen(
      _onEvent,
      onError: (Object error) {
        _appendLog('event-error: $error');
      },
    );
    _notificationResponseSub = _notificationResponseStream.stream.listen(
      _onNotificationResponse,
    );
    _refreshAll();
    _checkLaunchAlarm();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _notificationResponseSub?.cancel();
    _idController.dispose();
    super.dispose();
  }

  void _onEvent(AlarmEvent event) {
    _appendLog(
      '${event.type} id=${event.id ?? "-"} at=${DateTime.fromMillisecondsSinceEpoch(event.atMs)}',
    );
    _refreshAlarms();
  }

  void _onNotificationResponse(NotificationResponse response) {
    _appendLog(
      'notification response action=${response.actionId} alarmId=${response.alarmId}',
    );
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AlarmActionScreen(response: response),
      ),
    );
  }

  Future<void> _checkLaunchAlarm() async {
    final alarm = await AlarmPlus.getLaunchAlarm();
    if (alarm != null) {
      _appendLog('launchAlarm id=${alarm.id} status=${alarm.status}');
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      _refreshAlarms(),
      _refreshPermissions(),
    ]);
  }

  Future<void> _refreshAlarms() async {
    final alarms = await AlarmPlus.getAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _alarms
        ..clear()
        ..addAll(alarms);
    });
  }

  Future<void> _refreshPermissions() async {
    final status = await AlarmPlus.getPermissionStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionStatus = status;
    });
  }

  Future<void> _requestPermissions() async {
    try {
      final status = await AlarmPlus.requestPermissions();
      if (!mounted) {
        return;
      }
      setState(() {
        _permissionStatus = status;
      });
      _appendLog('permissions requested');
    } catch (error) {
      _appendLog('requestPermissions failed: $error');
    }
  }

  Future<void> _scheduleInOneMinute() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _appendLog('id is required');
      return;
    }
    final time = DateTime.now().add(const Duration(minutes: 1));
    try {
      await AlarmPlus.schedule(
        id: id,
        time: time,
        data: <String, dynamic>{
          'title': 'Alarm + Example',
          'source': 'example_app',
        },
        notificationSettings: const AlarmNotificationSettings(
          title: 'Wake up!',
          body: 'It is time for your custom alarm.',
          stopButtonText: 'Dismiss',
          snoozeButtonText: 'Snooze 5m',
          payload: 'custom_action_payload',
          // Assuming these assets exist or fallbacks handle missing
          soundAsset: 'assets/audio/alarm.mp3',
          icon: 'ic_lock_idle_alarm', 
        ),
      );
      _appendLog('scheduled id=$id at=$time');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('schedule failed: $error');
    }
  }

  Future<void> _triggerNow() async {
    final id = _idController.text.trim();
    try {
      await AlarmPlus.triggerNow(
        data: <String, dynamic>{
          'id': id.isEmpty ? 'quick_trigger' : id,
          'title': 'Trigger Now',
        },
        notificationSettings: const AlarmNotificationSettings(
          title: 'Instant Alarm',
          body: 'Triggered immediately for testing.',
          stopButtonText: 'Stop Now',
          snoozeButtonText: 'Wait 5m',
        ),
      );
      _appendLog('triggerNow invoked');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('triggerNow failed: $error');
    }
  }

  Future<void> _snooze() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _appendLog('id is required');
      return;
    }
    try {
      await AlarmPlus.snooze(id, 5);
      _appendLog('snooze requested for id=$id');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('snooze failed: $error');
    }
  }

  Future<void> _stop() async {
    try {
      await AlarmPlus.stop();
      _appendLog('stop requested');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('stop failed: $error');
    }
  }

  Future<void> _cancel() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _appendLog('id is required');
      return;
    }
    try {
      await AlarmPlus.cancel(id);
      _appendLog('cancel requested for id=$id');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('cancel failed: $error');
    }
  }

  Future<void> _delete() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _appendLog('id is required');
      return;
    }
    try {
      await AlarmPlus.delete(id);
      _appendLog('delete requested for id=$id');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('delete failed: $error');
    }
  }

  Future<void> _scheduleWithUrl() async {
    final id = '${_idController.text.trim()}_url';
    if (id.isEmpty) {
      _appendLog('id is required');
      return;
    }
    final time = DateTime.now().add(const Duration(minutes: 1));
    try {
      await AlarmPlus.schedule(
        id: id,
        time: time,
        data: <String, dynamic>{
          'title': 'Alarm + URL Example',
          'source': 'example_app',
        },
        notificationSettings: const AlarmNotificationSettings(
          title: 'Wake up with URL!',
          body: 'This alarm uses URL-based images.',
          stopButtonText: 'Dismiss',
          snoozeButtonText: 'Snooze 5m',
          payload: 'url_action_payload',
          // Example URLs - replace with actual working URLs
          largeIconUrl: 'https://via.placeholder.com/96x96.png?text=Icon',
          bigPictureUrl: 'https://via.placeholder.com/400x200.png?text=Big+Picture',
        ),
      );
      _appendLog('scheduled with URL id=$id at=$time');
      await _refreshAlarms();
    } catch (error) {
      _appendLog('schedule with URL failed: $error');
    }
  }

  void _appendLog(String message) {
    final line = '[${DateTime.now().toIso8601String()}] $message';
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.insert(0, line);
      if (_logs.length > 80) {
        _logs.removeRange(80, _logs.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('alarm_plus Example')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Alarm ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      child: const Text('Request Permissions'),
                    ),
                    ElevatedButton(
                      onPressed: _scheduleInOneMinute,
                      child: const Text('Schedule +1 min'),
                    ),
                    ElevatedButton(
                      onPressed: _triggerNow,
                      child: const Text('Trigger Now'),
                    ),
                    ElevatedButton(
                      onPressed: _snooze,
                      child: const Text('Snooze 5 min'),
                    ),
                    ElevatedButton(onPressed: _stop, child: const Text('Stop')),
                    ElevatedButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: _delete,
                      child: const Text('Delete'),
                    ),
                    ElevatedButton(
                      onPressed: _refreshAll,
                      child: const Text('Refresh'),
                    ),
                    ElevatedButton(
                      onPressed: _scheduleWithUrl,
                      child: const Text('Schedule with URL'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Permission Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _permissionStatus == null
                      ? 'Loading...'
                      : 'notifications=${_permissionStatus!.notificationsGranted} '
                            'exact=${_permissionStatus!.exactAlarmsGranted} '
                            'fullScreen=${_permissionStatus!.fullScreenIntentGranted}',
                ),
                const SizedBox(height: 16),
                Text(
                  'Alarms (${_alarms.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      for (final AlarmModel alarm in _alarms)
                        ListTile(
                          dense: true,
                          title: Text('${alarm.id} [${alarm.status}]'),
                          subtitle: Text(
                            '${DateTime.fromMillisecondsSinceEpoch(alarm.scheduledTimeUtcMs, isUtc: true).toLocal()}'
                            ' retry=${alarm.retryCount} drift=${alarm.lastDriftMs ?? '-'}',
                          ),
                        ),
                    ],
                  ),
                ),
                Text('Events', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  height: 160,
                  child: ListView(
                    children: _logs
                        .map(
                          (String e) =>
                              Text(e, style: const TextStyle(fontSize: 12)),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlarmActionScreen extends StatelessWidget {
  const AlarmActionScreen({required this.response, super.key});

  final NotificationResponse response;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm Notification Action')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('alarmId: ${response.alarmId ?? '-'}'),
            Text('actionId: ${response.actionId ?? '-'}'),
            Text('payload: ${response.payload ?? '-'}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
