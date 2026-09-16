## 0.2.0
- iOS: adopted AlarmKit on iOS 26+ for real system alarms, with the existing `UNUserNotificationCenter` path kept as the best-effort fallback on iOS 15-25.
  - Host apps must add `NSAlarmKitUsageDescription` to `Info.plist`; `requestPermissions()` now requests AlarmKit authorization on iOS 26+.
  - On iOS 26+ AlarmKit owns the alert sound and haptics, so app-level volume and vibration settings do not apply there.
- iOS: restructured the plugin from the single `ios/Classes/AlarmPlusPlugin.swift` file into a Swift Package under `ios/alarm_plus/Sources/alarm_plus/`, split into `Core/`, `Services/`, `Models/` and `Utils/`. This adds Swift Package Manager support.
- iOS: raised the minimum deployment target from 13.0 to 15.0.
- Example/tooling: moved the example app to Flutter 3.47 (AGP 9.3.2, Gradle 9.5, Kotlin 2.3.20, compileSdk 37) and to `package:material_ui`. The plugin's own Dart and Android configuration is unchanged, so consumers on older Flutter versions are unaffected.

## 0.1.3
- Added Vibration and Volume customization:
  - New `VibrationSettings` model with presets: `strong`, `medium`, `light`, `heartbeat`, and support for custom vibration patterns.
  - New `VolumeSettings` model with support for:
    - Direct volume level (0.0 to 1.0).
    - Linear volume fading over a specific duration.
    - Custom volume fade steps using `VolumeFadeStep`.
    - `volumeEnforced` to prevent users from lowering volume during an alarm.
  - Android: Implemented volume control, fading, and vibration using `MediaPlayer` and `Vibrator`.
  - iOS: Implemented volume control, fading, and vibration using `AVAudioPlayer` and `AudioServices`.
- Updated example app with UI controls for vibration and volume settings.
- Updated README with vibration and volume usage examples.

## 0.1.2
- refactoring the pubspec to properly bind the home page and issue tracker.

## 0.1.1

- Added URL-based image support for notifications:
  - `AlarmNotificationSettings.largeIconUrl` and `bigPictureUrl` fields
  - Android: Coil library for efficient image loading from URLs
  - iOS: Synchronous download and caching for notification attachments
  - Fallback to asset-based images if URL loading fails
- Updated example app with "Schedule with URL" button demonstrating URL images
- Updated README with URL usage examples and platform notes

## 0.1.0

- Introduced production-oriented `alarm_plus` API:
  - `initialize`
  - `triggerNow`, `schedule`, `cancel`, `stop`, `snooze`, `getAll`
  - `delete`
  - `events`, `getLaunchAlarm`, `getPermissionStatus`, `requestPermissions`
- Added flutter_local_notifications-style notification response callbacks:
  - foreground callback via `onDidReceiveNotificationResponse`
  - background callback isolate via
    `onDidReceiveBackgroundNotificationResponse` with `@pragma('vm:entry-point')`
- Added notification-response data model (`NotificationResponse`,
  `NotificationResponseType`) and pending response delivery on app launch.
- Added `AlarmModel`, `AlarmEvent`, and `AlarmPermissionStatus` model layer.
- Implemented Android reliability path:
  - `AlarmManager.setExactAndAllowWhileIdle`
  - trigger receiver + action receiver + boot receiver
  - foreground ringing service with wake lock + looping audio
  - full-screen notification intent path
  - Room persistence and reboot/package/time-change rescheduling
- Implemented iOS best-effort notification path:
  - `UNUserNotificationCenter` scheduling
  - stop/snooze notification actions
  - persisted local alarm state + event emission
- Added example app covering schedule/trigger/snooze/stop/cancel/list/events/permissions.
- Added pub.dev-ready README with platform behavior and troubleshooting details.
