# AGENTS.md - alarm_plus Development Guide

## Project Overview

**alarm_plus** is a production-reliability-focused Flutter alarm plugin providing:
- **Android**: Exact alarm scheduling via `AlarmManager.setExactAndAllowWhileIdle`, receiver→service chain, foreground ringing service with wake locks, full-screen intent for lock-screen display, Room persistence with boot/package/time-change reschedule
- **iOS**: Best-effort local notification scheduling via `UNUserNotificationCenter`, UserDefaults persistence, notification actions (stop/snooze), no background service emulation

**Design principle**: Android is reliability-first with deterministic timing guarantees; iOS is intentionally conservative and OS-compliant.

## Architecture Overview

```
Dart Layer (lib/)
  └─ AlarmPlus (public API) 
      └─ AlarmPlusPlatform (interface)
          └─ MethodChannelAlarmPlus (implementation)
                     │
          ┌──────────┴──────────┐
          │                     │
      Android (kotlin)      iOS (swift)
          │                     │
      Receiver Chain      UNUserNotificationCenter
      + AlarmRingingService
      + Room DB + Boot Receiver
```

### Dart-to-Native Communication

- **MethodChannel** (`alarm_plus`): Dart → native calls (schedule, cancel, etc.)
- **EventChannel** (`alarm_plus/events`): Native → Dart event stream (triggered, stopped, snoozed, error, permissionChanged)
- **Background Channel** (`alarm_plus/actions`): Background isolate notification responses via `alarmPlusCallbackDispatcher`

### Data Model Contract

All alarm state transitions share a common **AlarmModel** serialized as Map:
- `id` (String): unique identifier
- `scheduledTimeUtcMs` (int): epoch milliseconds, always UTC
- `scheduledTimeLocalIso` (String): ISO8601 local time for display
- `payloadJson` (String?): app-specific JSON data
- `status` (String): `scheduled|triggered|snoozed|stopped|canceled|error`
- `createdAtMs`, `updatedAtMs` (int): timestamps
- `lastTriggeredAtMs` (int?): when actually triggered
- `lastDriftMs` (int?): drift in ms (triggered time - scheduled time)
- `retryCount` (int): bounded retry metadata
- `nextRetryAtMs` (int?): next retry timestamp
- `platformMeta` (Map): platform-specific runtime metadata

**Critical**: `scheduledTimeUtcMs` is always milliseconds since epoch in UTC. Dart layer converts to UTC via `time.toUtc().millisecondsSinceEpoch`.

## Platform-Specific Conventions

### Android (Kotlin, API 24+)

**Package**: `com.psb.alarm_plus`

**Core Components** (see `android/src/main/kotlin/com/psb/alarm_plus/`):
- `AlarmPlusPlugin.kt`: Main plugin entry, channel handler, Room setup
- `runtime/AlarmTriggerReceiver`: Receives exact alarm triggers, forwards to foreground service
- `runtime/AlarmRingingService`: Foreground service loop-playing audio, holding wake lock, managing lifecycle
- `runtime/AlarmActionReceiver`: Handles stop/snooze actions from notification
- `runtime/AlarmBootReceiver`: Reschedules alarms on boot/package replace/time change
- `core/`: Alarm scheduling logic, drift tracking
- `data/`: Room database entities and DAO

**Persistence**: Room database (AlarmEntity) survives app kill, supports queries by ID/status.

**Permissions** (from AndroidManifest.xml):
- `SCHEDULE_EXACT_ALARM`: Request before `setExactAndAllowWhileIdle`
- `POST_NOTIFICATIONS`: Android 13+ runtime permission
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: Required for background playback
- `USE_FULL_SCREEN_INTENT`: Android 14+ capability gating
- `WAKE_LOCK`: Used by ringing service

**Key Pattern**: Receiver → Foreground Service → Wake Lock → Loop Audio + EventChannel emit. No background execution assumes foreground service keeps process alive during alarm.

### iOS (Swift, 13+)

**Core**: `ios/Classes/AlarmPlusPlugin.swift` (~800 lines, monolithic)

**Key Methods**:
- `userNotificationCenter(_:willPresent:withCompletionHandler:)`: Detect alarm trigger while app foreground
- `userNotificationCenter(_:didReceive:withCompletionHandler:)`: Handle tap/actions (stop/snooze)
- `scheduleNotification(record:fireDate:)`: Use UNCalendarNotificationTrigger for scheduling
- `markTriggeredAndEmit()`: Update status, emit "triggered" event with drift ms

**Persistence**: UserDefaults (key `alarm_plus_store`) stores all alarm records as nested dictionaries.

**Notification Actions**: 
- `alarm_plus_stop`: Stops current alarm, emits "stopped" event
- `alarm_plus_snooze`: Adds default 10 minutes to scheduled time, reschedules, emits "snoozed" event
- Category: `alarm_plus_category` with both actions

**Permission Model** (note: iOS fields are mostly dummy in PermissionStatus):
- `notificationsGranted`: Derived from UNNotificationSettings.authorizationStatus
- `exactAlarmsGranted`: Always false (iOS has no exact alarm guarantee)
- `fullScreenIntentGranted`: Always false (no iOS equivalent)
- `criticalAlertsEligible`: From UNNotificationSettings.criticalAlertSetting

**Key Pattern**: UNUserNotificationCenter delegate + UserDefaults store. No retry logic; relies on OS notification delivery.

## Dart Layer Conventions

### Event Stream Pattern

All events emitted via EventChannel map conform to:
```dart
{
  "type": "triggered|stopped|snoozed|error|permissionChanged",
  "atMs": int,          // event emission timestamp
  "id": String | null,  // alarm ID (null for permissionChanged)
  "alarm": Map | null,  // full AlarmModel map
  "errorCode": String | null,
  "errorMessage": String | null,
  "meta": Map           // type-specific metadata
}
```

**Event Types**:
- `triggered`: Alarm fired. meta = `{"driftMs": <delay in ms>}`
- `stopped`: Alarm stopped (user action). meta = `{}`
- `snoozed`: Snooze activated. meta = `{"minutes": <snooze duration>}`
- `error`: Scheduling failed. Contains errorCode/errorMessage.
- `permissionChanged`: Permission status changed. meta = entire permission status map

### Callback Entry Points

Background notification responses require `@pragma('vm:entry-point')`:
```dart
@pragma('vm:entry-point')
void receiveBackgroundNotification(NotificationResponse response) {
  // Called in background isolate when user interacts with notification
  // This isolate is separate from main app isolate
}
```

The callback handle is passed to native code at initialization, retrieved via `alarmPlusCallbackDispatcher()` (Dart side) and `getBackgroundCallbackHandle` (native side).

### Model Serialization

All models use `.fromMap()` factory and `.toMap()` method:
- `AlarmModel.fromMap(Map<String, dynamic>)`: Defensive casting; uses `.toString()` on strings, `.toInt()` on numbers
- `AlarmEvent.fromMap()`: Similar defensive pattern
- `NotificationResponse.fromMap()`: Parses action ID and payload JSON

**Defensive Pattern Example** (from AlarmModel):
```dart
scheduledTimeUtcMs: (map['scheduledTimeUtcMs'] as num?)?.toInt() ?? 0,
payloadJson: map['payloadJson']?.toString(),
platformMeta: (map['platformMeta'] is Map)
    ? Map<String, dynamic>.from(map['platformMeta'] as Map)
    : <String, dynamic>{},
```

This allows native code to send slightly mistyped data without crashing Dart.

## Testing Patterns

### Test Structure

- `test/alarm_models_test.dart`: Unit tests for model serialization (.fromMap/.toMap round-trip)
- `test/alarm_plus_method_channel_test.dart`: Mock MethodChannel for Dart API testing
- `test/alarm_plus_platform_test.dart`: Mock PlatformInterface testing

### Running Tests

```bash
flutter test                          # All unit tests
flutter test test/alarm_models_test.dart
flutter test --coverage               # Generate coverage
```

### Test Conventions

- Use `testWidgets()` for UI integration fixtures
- Mock MethodChannel via `TestDefaultBinaryMessenger`
- Defensive casting mirrors production model factories
- Example app serves as manual integration test

## Build & Release Workflows

### Local Development

```bash
# Analyze code (Dart)
flutter analyze

# Run tests
flutter test

# Run example app (requires connected device/emulator)
cd example
flutter run

# Build for Android (example)
cd example
flutter build apk --debug
flutter build appbundle

# Build for iOS (example)
cd example
flutter build ios --debug
pods install / pod repo update
```

### Plugin-Specific Commands

```bash
# Check plugin structure
flutter pub analyze

# Generate coverage
flutter test --coverage
genhtml coverage/lcov.report -o coverage/html

# Format code
dart format lib/ test/ android/src/main/kotlin ios/Classes example/lib
dart fix --apply
```

### Android Build Configuration

- **Gradle**: Kotlin DSL (`.kts` files)
- **Min SDK**: 24, **Compile SDK**: 36, **Target JVM**: 17
- **Room Compiler**: Kotlin Symbol Processing (KSP) via `com.google.devtools.ksp` plugin
- **Key Dependencies**: androidx.room, androidx.core-ktx, gson, kotlinx-coroutines-android, coil

**Common Issues**:
- KSP/Room compilation issues → clear `.gradle` cache, run `flutter clean` && `flutter pub get`
- Plugin not found → ensure `flutter pub get` runs before build
- Manifest conflicts → check receiver/service declarations unique to alarm_plus

### iOS Build Configuration

- **Min Target**: 13.0
- **Swift**: 5.0+
- **Podspec**: `ios/alarm_plus.podspec` defines dependencies

**Common Issues**:
- NotificationCenter delegate conflicts → plugin saves/restores previous delegate
- UserDefaults persistence → ensure key `alarm_plus_store` not used elsewhere
- Full-screen intent → iOS doesn't support; fields always false in permission status

## Common Development Tasks

### Adding a New Method to Dart API

1. **Define abstract method** in `lib/alarm_plus_platform_interface.dart`:
   ```dart
   Future<Something> myNewMethod() {
     throw UnimplementedError('myNewMethod() has not been implemented.');
   }
   ```

2. **Add static wrapper** in `lib/alarm_plus.dart`:
   ```dart
   static Future<Something> myNewMethod() {
     return AlarmPlusPlatform.instance.myNewMethod();
   }
   ```

3. **Implement in Dart/native bridge** in `lib/alarm_plus_method_channel.dart`:
   ```dart
   @override
   Future<Something> myNewMethod() {
     return methodChannel.invokeMethod<Something>('myNewMethod');
   }
   ```

4. **Implement on Android** (Kotlin): Add case in `AlarmPlusPlugin.handle()` method
5. **Implement on iOS** (Swift): Add case in `handle(_:result:)` switch statement
6. **Emit events** via EventChannel if state changes; test round-trip serialization

### Debugging Multi-Isolate Background Callbacks

Background notification responses run in **separate isolate**. To debug:
- Print statements go to Logcat (Android) / Console (iOS)
- State from main isolate is NOT shared; use MethodChannel to fetch state
- `@pragma('vm:entry-point')` must be on top-level or static function; lambda closures will not be compiled

### Handling Platform-Specific Edge Cases

iOS permission model differs significantly from Android:
- iOS: `notificationsGranted` is binary (authorized or not)
- Android: Granular permissions (exact alarms, full-screen intent, notifications separate)

Check in Dart before calling platform methods:
```dart
final status = await AlarmPlus.getPermissionStatus();
if (!status.notificationsGranted) {
  await AlarmPlus.requestPermissions();
}
```

## Key Integration Points & Dependencies

### External Dependencies

**Dart/Flutter**:
- SDK constraints (from `pubspec.yaml`): `sdk: ^3.8.0`, `flutter: '>=3.3.0'` — use these when running `dart`/`flutter` tooling and CI
- `plugin_platform_interface`: ^2.1.8 (plugin contract)  
- `flutter_lints`: ^6.0.0 (analysis)

**Dev / analysis tools**:
- `very_good_analysis`: ^10.2.0 (present in `dev_dependencies` in `pubspec.yaml`) — some CI/dev flows in this repo use the Very Good CLI/analysis config in addition to `flutter_lints`

**Android** (Kotlin):
- `androidx.room:room-runtime` + `room-compiler`: 2.7.2 (persistence via KSP)
- `androidx.core:core-ktx`: 1.16.0 (compatibility utilities)
- `com.google.code.gson`: 2.13.1 (JSON serialization)
- `org.jetbrains.kotlinx:kotlinx-coroutines-android`: 1.8.1 (async/coroutine support)
- `io.coil-kt:coil`: 2.6.0 (image loading for notification assets)

**iOS**: 
- Native frameworks only (UserNotifications, Foundation)

### Cross-Component Communication

1. **Dart → Android**: MethodChannel ("alarm_plus") invokes Kotlin methods in AlarmPlusPlugin
2. **Dart → iOS**: MethodChannel ("alarm_plus") invokes Swift methods in AlarmPlusPlugin
3. **Android/iOS → Dart**: EventChannel ("alarm_plus/events") streams AlarmEvent maps
4. **Background Action → Dart**: EventChannel ("alarm_plus/actions") or MethodChannel callback
5. **Notification Responses**: Stored in platform defaults (UserDefaults on iOS, SharedPreferences pattern on Android), delivered on app resume via `onDidReceiveNotificationResponse`

## Reliability & Error Handling

### Android Reliability

- **Exact Alarm Guarantee**: `setExactAndAllowWhileIdle()` works even in Doze mode (API 31+)
- **Wake Lock**: RingingService holds CPU wake lock during playback
- **Boot Reschedule**: AlarmBootReceiver reschedules all DB alarms after reboot
- **Reboot Flags**: DB stores alarm state; rescheduler queries for `status = "scheduled"` records
- **Drift Tracking**: `lastDriftMs` calculated as (actual trigger time - scheduled time)

### iOS Reliability Limitations

- **No Exact Timing**: UNCalendarNotificationTrigger uses OS scheduling, not guaranteed at exact second
- **No Guaranteed Delivery**: OS may coalesce/suppress notifications
- **No Reboot Reschedule**: Notification requests survive reboot per OS policy, but no explicit reschedule needed
- **Local Only**: Alarms stored in UserDefaults; no server-side persistence

### Error Emission

Errors flow through EventChannel:
```dart
{
  "type": "error",
  "errorCode": "ERR_SCHEDULE_FAILED",
  "errorMessage": "<platform error detail>",
  "id": <alarm id>,
  "alarm": <partial AlarmModel>
}
```

Dart app should listen to `AlarmPlus.events` and handle error types.

## Patterns to Avoid

1. **Blocking MethodChannel calls**: Never call `invokeMethodSync()`; use `invokeMethod<T>()` with await
2. **Mutable listeners**: Don't pass lambda closures as background callbacks; use top-level functions with `@pragma('vm:entry-point')`
3. **Accessing main isolate state in background**: Background callback runs in separate isolate; use MethodChannel to fetch state if needed
4. **Ignoring permission checks**: Always check `getPermissionStatus()` before scheduling on Android
5. **Concurrent modification in event stream**: Don't modify alarm list while EventChannel is streaming; copy to separate list
6. **Mixing scheduled vs UTC timestamps**: All internal timestamps are UTC milliseconds; convert display time locally in Dart
7. **Room DAO direct async calls without coroutine context**: Android Room DAOs return suspend functions; Kotlin plugin must provide coroutine scope

## File Structure Reference

```
lib/
  ├─ alarm_plus.dart                       # Public API (static methods)
  ├─ alarm_plus_platform_interface.dart    # Abstract platform interface
  ├─ alarm_plus_method_channel.dart        # MethodChannel implementation
  └─ src/
      ├─ callback_dispatcher.dart          # Background callback entry point
      └─ models/
          ├─ alarm_model.dart              # Main alarm state model
          ├─ alarm_event.dart              # Event stream model
          ├─ alarm_notification_settings.dart  # Notification UI/audio config
          ├─ alarm_permission_status.dart  # Permission model
          └─ notification_response.dart    # Notification tap/action model

android/src/main/kotlin/com/psb/alarm_plus/
  ├─ AlarmPlusPlugin.kt                    # Main plugin, channel handler
  ├─ core/                                 # Core scheduling & utility logic
  │   ├─ AlarmScheduler.kt                 # Exact alarm scheduling with AlarmManager
  │   ├─ AlarmEventDispatcher.kt           # EventChannel stream emission
  │   ├─ AlarmPermissionManager.kt         # Permission checking & enforcement
  │   ├─ AlarmNotificationResponseMapper.kt # Maps notification intents to events
  │   ├─ AlarmConstants.kt                 # Intent actions, notification IDs
  │   ├─ AlarmIds.kt                       # Unique ID generation & management
  │   ├─ AlarmJson.kt                      # JSON serialization helpers
  │   └─ AlarmLog.kt                       # Logging utilities
  ├─ runtime/                              # Runtime components & broadcast receivers
  │   ├─ AlarmTriggerReceiver.kt           # Receives exact alarm broadcasts
  │   ├─ AlarmRingingService.kt            # Foreground service for audio playback
  │   ├─ AlarmActionReceiver.kt            # Handles stop/snooze notification actions
  │   ├─ AlarmBootReceiver.kt              # Reschedules on boot/time-change
  │   └─ background/                       # Background isolate & callback handling
  │       ├─ AlarmBackgroundActionDispatcher.kt  # Routes background notification actions
  │       └─ AlarmBackgroundIsolatePreferences.kt # Stores callback handle for background
  └─ data/                                 # Persistence layer via Room
      ├─ AlarmEntity.kt                    # Room entity (database schema)
      ├─ AlarmDao.kt                       # Room DAO (query interface)
      ├─ AlarmDatabase.kt                  # Room database singleton
      └─ AlarmRepository.kt                # Data access abstraction

ios/Classes/
  └─ AlarmPlusPlugin.swift                 # Single file with all iOS logic
```

