# alarm_plus

`alarm_plus` is a Flutter alarm plugin focused on production reliability:

- Android: exact alarms + foreground ringing service + lock-screen/full-screen flow
- iOS: OS-compliant notification-based best-effort alarms

It uses `MethodChannel` + `EventChannel` and does **not** depend on `flutter_local_notifications` internally.

## Features

- Unified Dart API:
  - `initialize`
  - `triggerNow`
  - `schedule`
  - `cancel`
  - `delete`
  - `stop`
  - `snooze`
  - `getAll`
- Helper APIs:
  - `events` stream: `triggered | stopped | snoozed | error | permissionChanged`
  - `getLaunchAlarm()`
  - `getPermissionStatus()`
  - `requestPermissions()`
- Android Room persistence + reboot/package-replace reschedule.
- Android notification actions (`STOP`, `SNOOZE`) work via receivers/service.
- **Deep UI & Sound Customization**: Support for custom notification titles, bodies, custom action button texts, icons, big pictures, and custom audio assets (`.mp3`/`.wav` from Flutter assets) for both platforms via `AlarmNotificationSettings`.
- **URL-based Images**: Load notification large icons and big pictures from HTTP/HTTPS URLs (Android uses Coil, iOS downloads synchronously).
- **Vibration & Volume Customization**: 
  - Android & iOS: Set custom volume levels (0.0-1.0), implement linear volume fading, or custom volume fade steps.
  - Android & iOS: Vibration presets (strong, medium, light, heartbeat) and continuous vibration support.
  - Android & iOS: Volume enforcement to prevent users from lowering volume during an active alarm.

## Platform Behavior

| Capability                   | Android                                        | iOS                                                |
|------------------------------|------------------------------------------------|----------------------------------------------------|
| Exact alarm timing           | Yes (`AlarmManager.setExactAndAllowWhileIdle`) | No (system-managed local notifications)            |
| Foreground ringing service   | Yes                                            | Yes (Background Audio keep-alive & AVAudioSession) |
| Wake lock-managed playback   | Yes                                            | Yes (AVAudioPlayer looping)                        |
| Full-screen/lock-screen path | Yes (full-screen intent + activity flags)      | No equivalent                                      |
| Reboot reschedule            | Yes                                            | N/A (notification requests survive per OS policy)  |

## Installation

Add dependency:

```yaml
dependencies:
  alarm_plus: ^0.1.0
```

### Android setup

`alarm_plus` manifest includes required permissions and components. Host apps should still verify policy and UX:

- `POST_NOTIFICATIONS` (Android 13+ runtime permission)
- `SCHEDULE_EXACT_ALARM` (Android 12+ exact alarm policy)
- `USE_FULL_SCREEN_INTENT` (Android 14+ capability gating)
- Optional battery optimization exemptions for aggressive OEM firmware

For lock-screen experience, ensure your launcher/Flutter activity can show over lock screen. Example app sets:

- `setShowWhenLocked(true)`
- `setTurnScreenOn(true)`

### iOS setup

- iOS minimum target: `13.0`
- Request notification permission from app flow (`requestPermissions()`).
- **Required for true background alarms:** You must add the Audio Background Mode to your app's Xcode project. This allows alarms to ring out loud even if the physical silent switch is engaged and the app is in the background.
  1. Open `ios/Runner.xcworkspace`.
  2. Go to the `Runner` target -> **Signing & Capabilities**.
  3. Add **Background Modes** and check **Audio, AirPlay, and Picture in Picture**. (This automatically adds `UIBackgroundModes: audio` to your `Info.plist`).

## Permissions

### Permission Status

Before scheduling alarms, check permission status:

```dart
final status = await AlarmPlus.getPermissionStatus();
print("Notifications: ${status.notificationsGranted}");
print("Exact Alarms (Android): ${status.exactAlarmsGranted}");
print("Full-Screen Intent (Android 14+): ${status.fullScreenIntentGranted}");
```

**Platform Differences**:

| Permission                | Android                                    | iOS                               |
|---------------------------|--------------------------------------------|-----------------------------------|
| `notificationsGranted`    | Post notification permission (Android 13+) | Notification authorization status |
| `exactAlarmsGranted`      | SCHEDULE_EXACT_ALARM permission            | Always `false` (not applicable)   |
| `fullScreenIntentGranted` | USE_FULL_SCREEN_INTENT (Android 14+)       | Always `false` (not applicable)   |

### Requesting Permissions

```dart
// Returns true if user granted permissions
final granted = await AlarmPlus.requestPermissions();

if (!granted) {
  // Show dialog explaining why permissions are needed
  // User can open app settings via platform channel if desired
}
```

**On Android**: After `requestPermissions()`, if exact alarms fail, user must enable "Schedule exact alarm" in app settings.

**On iOS**: Permission request shows system notification authorization dialog once. Subsequent calls don't show dialog.

## Usage

```dart
import 'package:alarm_plus/alarm_plus.dart';

@pragma('vm:entry-point')
void receiveBackgroundNotification(NotificationResponse notificationResponse) {
  // handle stop/snooze action in background isolate
}

Future<void> setup() async {
  await AlarmPlus.initialize(
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // open your custom alarm screen
    },
    onDidReceiveBackgroundNotificationResponse: receiveBackgroundNotification,
  );
  await AlarmPlus.requestPermissions();
  
  // Schedule alarm for local time (automatically converted to UTC internally)
  final alarmTime = DateTime.now().add(const Duration(minutes: 2));
  
  await AlarmPlus.schedule(
    id: 'wake_up',
    time: alarmTime,  // Use local time — plugin handles UTC conversion
    data: {'title': 'Morning alarm'},
    notificationSettings: const AlarmNotificationSettings(
      title: 'Wake Up!',
      body: 'Time to start your day.',
      stopButtonText: 'Dismiss',
      snoozeButtonText: 'Snooze',
      payload: 'custom_payload_data',
      soundAsset: 'assets/audio/alarm.mp3', // Remember to add to pubspec.yaml
      icon: 'ic_lock_idle_alarm', // Android drawable name
      largeIconUrl: 'https://example.com/icon.png', // URL for large icon
      bigPictureUrl: 'https://example.com/banner.jpg', // URL for big picture
      volumeSettings: VolumeSettings(
        volume: 0.8, // 80% volume
        fadeDuration: Duration(seconds: 10), // Fade in over 10s
        volumeEnforced: true, // Reset if user lowers volume
      ),
      vibrationSettings: VibrationSettings(
        enabled: true,
        preset: VibrationPreset.strong,
        continuous: true,
        // For custom patterns:
        // preset: VibrationPreset.custom,
        // customPattern: [0, 1000, 500, 1000], // [wait, vibrate, wait, vibrate]
      ),
    ),
  );
}
```

### Volume Fading with Custom Steps

For advanced volume control, use `VolumeFadeStep`:

```dart
      volumeSettings: VolumeSettings(
        fadeSteps: [
          VolumeFadeStep(volume: 0.1, at: Duration(seconds: 0)),
          VolumeFadeStep(volume: 0.5, at: Duration(seconds: 30)),
          VolumeFadeStep(volume: 1.0, at: Duration(minutes: 1)),
        ],
      ),
```

**Time Handling**: Always pass **local DateTime** to `schedule()`. The plugin automatically converts to UTC internally (`scheduledTimeUtcMs`). The `scheduledTimeLocalIso` field in AlarmModel is for UI display.

### Trigger now

```dart
await AlarmPlus.triggerNow(
  data: {'id': 'quick_alarm', 'source': 'debug'},
  notificationSettings: const AlarmNotificationSettings(
    title: 'Instant Alarm',
    body: 'Triggered immediately.',
  ),
);
```

### Listen for events

The `events` stream emits `AlarmEvent` objects with detailed metadata. Full event map structure:

```dart
final sub = AlarmPlus.events.listen((event) {
  event.type;             // "triggered" | "stopped" | "snoozed" | "error" | "permissionChanged"
  event.id;               // alarm ID (null for permissionChanged)
  event.alarm;            // full AlarmModel (null for permissionChanged)
  event.errorCode;        // for error type only
  event.errorMessage;     // for error type only
  event.meta;             // type-specific metadata (see below)
});
```

**Event Types & Metadata**:

- `triggered`: Alarm fired. `meta = {"driftMs": <ms delay from scheduled time>}` — use `driftMs` to monitor scheduling accuracy.
- `stopped`: User dismissed alarm. `meta = {}`
- `snoozed`: User snoozed alarm. `meta = {"minutes": <snooze duration>}`
- `error`: Scheduling failed (e.g., permission denied). Contains `errorCode` and `errorMessage`.
- `permissionChanged`: User changed notification/alarm permissions. `meta = entire PermissionStatus`

**Error Handling Example**:

```dart
final sub = AlarmPlus.events.listen((event) {
  if (event.type == "error") {
    print("Alarm ${event.id} failed: ${event.errorCode} - ${event.errorMessage}");
    // Log, retry, or show user dialog
  }
});
```

### Inspect and control alarms

```dart
final alarms = await AlarmPlus.getAll();
await AlarmPlus.snooze('wake_up', 5);
await AlarmPlus.stop();
await AlarmPlus.cancel('wake_up');
await AlarmPlus.delete('wake_up');
```

### Background Notification Responses

When users tap stop/snooze buttons on an alarm notification **while the app is in the background or killed**, the callback function runs in a **separate Dart isolate**:

```dart
@pragma('vm:entry-point')
void receiveBackgroundNotification(NotificationResponse notificationResponse) {
  // This runs in a SEPARATE isolate, not your main app isolate
  // Main app state (shared variables, singletons) is NOT accessible here
  // Only use this to log, update persistence, or call MethodChannel
  
  print("Stop/Snooze tapped: ${notificationResponse.actionId}");
}
```

**Key Constraints**:
- Do NOT rely on static variables or singletons from main app
- Do NOT modify UI
- Do use MethodChannel if you need data from main isolate
- Do use top-level functions only — lambda closures won't be compiled as background entry points
- Always include `@pragma('vm:entry-point')` above the function declaration

## `AlarmModel`

Represents the full state of a scheduled or triggered alarm.

**Fields**:

- `id` (String): Unique identifier for the alarm
- `scheduledTimeUtcMs` (int): Scheduled trigger time as milliseconds since epoch (UTC). Always in UTC; convert to local time for display.
- `scheduledTimeLocalIso` (String): ISO8601 local time string for UI display (e.g., "2026-05-18T07:30:00.000")
- `payloadJson` (String?): App-specific JSON data passed to callback
- `status` (String): Current state: `scheduled|triggered|snoozed|stopped|canceled|error`
- `createdAtMs`, `updatedAtMs` (int): Record creation/update timestamps
- `lastTriggeredAtMs` (int?): When the alarm actually fired (may differ from scheduled time)
- `lastDriftMs` (int?): **Drift tracking** — difference in milliseconds: `(lastTriggeredAtMs - scheduledTimeUtcMs)`. Use to monitor scheduler accuracy. Positive = late, negative = early.
- `retryCount` (int): Number of retry attempts (Android only; bounded retry metadata)
- `nextRetryAtMs` (int?): Timestamp of next retry attempt (if applicable)
- `platformMeta` (Map): Platform-specific runtime metadata (e.g., Android notification ID, iOS notification request ID)

**Usage Example** (check drift):

```dart
final alarm = await AlarmPlus.getById('wake_up');
if (alarm != null && alarm.lastDriftMs != null) {
  print("Alarm triggered ${alarm.lastDriftMs}ms ${alarm.lastDriftMs! > 0 ? 'late' : 'early'}");
}
```


## Reliability Notes

Android path is reliability-first:

- exact alarm scheduling
- receiver -> immediate foreground service handoff
- wake-lock-backed playback
- persisted alarm state transitions
- boot/package/time-change reschedule
- trigger drift metrics persisted in model
- bounded retry metadata (`retryCount`, `nextRetryAtMs`)

iOS path provides a robust hybrid approach:

- **True Background Alarms**: Uses `AVAudioSession` and a silent keep-alive player to play looping alarm audio and bypass the physical silent switch.
- **Local Notification Fallback**: In case the app is explicitly killed (swiped up), OS-timed local notifications guarantee delivery.
- Notification actions for stop/snooze.

## Troubleshooting

- If Android alarms are delayed on vendor ROMs: verify battery/background restrictions for the app.
- If exact alarms fail: check `getPermissionStatus().exactAlarmsGranted`.
- If full-screen doesn’t appear on Android 14+: check `fullScreenIntentGranted` and open settings via `requestPermissions()`.
- If no banner/sound on iOS: verify notification authorization and system notification settings.

## Example

`example/` includes a runnable app for:

- schedule
- trigger now
- snooze
- stop
- cancel
- permissions/status
- event stream logs
- launch-alarm handoff

---
### References and Learnings
#### 1) `alarm`
Source: [pub.dev/packages/alarm](https://pub.dev/packages/alarm)
#### 2) `flutter_local_notifications`
Source: [pub.dev/packages/flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

---

* _Appreciate my work? Show some ❤️ and star the repo to support this package._

* For more information about the properties, look at the [API reference](https://pub.dev/documentation/alarm_plus/latest/).