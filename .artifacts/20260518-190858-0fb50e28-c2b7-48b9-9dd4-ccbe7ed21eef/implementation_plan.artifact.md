# Implementation Plan - Vibration and Volume Settings

Add vibration and volume customization to `AlarmNotificationSettings` and implement them on Android and iOS.

## Proposed Changes

### Dart Models

Add new models for vibration and volume settings and update `AlarmNotificationSettings`.

#### [vibration_settings.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/src/models/vibration_settings.dart) [NEW]
- Define `VibrationPreset` enum: `strong`, `medium`, `light`, `heartbeat`.
- Define `VibrationSettings` class with `enabled`, `preset`, and `continuous`.

#### [volume_settings.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/src/models/volume_settings.dart) [NEW]
- Define `VolumeFadeStep` class with `volume` and `at` (Duration).
- Define `VolumeSettings` class with `volume`, `fadeDuration`, `fadeSteps`, and `volumeEnforced`.

#### [alarm_notification_settings.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/src/models/alarm_notification_settings.dart)
- Add `vibrationSettings` and `volumeSettings` fields.
- Update `fromMap` and `toMap` to handle nested serialization.

#### [alarm_plus.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/alarm_plus.dart)
- Export the new model files.

---

### Android Implementation

#### [AlarmRingingService.kt](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/android/src/main/kotlin/com/psb/alarm_plus/runtime/AlarmRingingService.kt)
- Update `startAlarmAudio` to apply volume and vibration settings.
- Implement volume fading logic using a `Handler` or `ValueAnimator`.
- Implement volume enforcement by listening to `STREAM_ALARM` changes (optional/best effort) or periodically resetting player volume.
- Implement vibration patterns for presets using `VibrationEffect` (API 26+) or `Vibrator` patterns.
- Ensure continuous vibration if requested.

---

### iOS Implementation

#### [AlarmPlusPlugin.swift](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/ios/Classes/AlarmPlusPlugin.swift)
- Update `startRinging` to apply volume settings to `AVAudioPlayer`.
- Use `setVolume(_:fadeDuration:)` for simple fading.
- Implement custom `fadeSteps` using a `Timer`.
- Implement vibration using `AudioServicesPlaySystemSound` or `CHHapticEngine` (best effort for background audio).

---

### Documentation & Example

#### [README.md](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/README.md)
- Add "Vibration and Volume" section with usage examples.

#### [main.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/example/lib/main.dart)
- Add UI controls (sliders, dropdowns) to test volume and vibration settings in the example app.

#### [CHANGELOG.md](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/CHANGELOG.md)
- Log the new features under version `0.1.3`.

## Verification Plan

### Automated Tests
- `test/alarm_models_test.dart`: Add tests for `AlarmNotificationSettings` serialization with new fields.
- Run `flutter test`.

### Manual Verification
- **Android**:
  - Run example app.
  - Schedule alarm with 50% volume and 10s fade.
  - Verify volume starts low and increases.
  - Test different vibration presets.
  - Test `volumeEnforced` by trying to lower volume during ringing.
- **iOS**:
  - Run example app.
  - Verify volume and fading on physical device (vibration is best verified on device).
