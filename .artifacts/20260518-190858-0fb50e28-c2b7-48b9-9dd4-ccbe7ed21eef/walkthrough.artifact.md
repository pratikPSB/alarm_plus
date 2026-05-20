# Walkthrough - Vibration and Volume Settings

I have implemented vibration and volume customization for the `alarm_plus` plugin. This allows users to set specific volume levels, implement volume fading, use vibration presets, and enforce volume levels during an active alarm.

## Changes Made

### Dart Models
- Added `VibrationSettings` and `VibrationPreset` in [vibration_settings.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/src/models/vibration_settings.dart).
- Added `VolumeSettings` and `VolumeFadeStep` in [volume_settings.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/src/models/volume_settings.dart).
- Updated `AlarmNotificationSettings` in [alarm_notification_settings.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/lib/src/models/alarm_notification_settings.dart) to include these new settings.

### Android Implementation
- Updated `AlarmRingingService.kt` in [AlarmRingingService.kt](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/android/src/main/kotlin/com/psb/alarm_plus/runtime/AlarmRingingService.kt) to:
    - Apply target volume level to the alarm audio stream.
    - Implement linear volume fading over a specified duration.
    - Support custom volume fade steps.
    - Implement vibration presets (`strong`, `medium`, `light`, `heartbeat`) and continuous vibration.
    - Implement volume enforcement that resets the system volume if the user attempts to lower it.

### iOS Implementation
- Updated `AlarmPlusPlugin.swift` in [AlarmPlusPlugin.swift](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/ios/Classes/AlarmPlusPlugin.swift) to:
    - Set `AVAudioPlayer` volume.
    - Implement volume fading using `setVolume(_:fadeDuration:)` for linear fades.
    - Implement custom fade steps using `Timer`.
    - Support vibration presets using `AudioServicesPlaySystemSound`.
    - Implement volume enforcement for the `AVAudioPlayer` instance.

### Example App
- Added UI controls in [main.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/example/lib/main.dart) to allow users to test:
    - Target volume slider.
    - Fade duration slider.
    - Volume enforcement toggle.
    - Vibration toggle and preset dropdown.

### Documentation
- Updated [README.md](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/README.md) with new usage examples and advanced volume control sections.
- Updated [CHANGELOG.md](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/CHANGELOG.md) for version `0.1.3`.

## Verification Results

### Automated Tests
- Added new serialization tests in [alarm_models_test.dart](file:///Users/pratikbharad/PSB/Projects/02_downloads/alarm_plus/test/alarm_models_test.dart).
- Ran `flutter test test/alarm_models_test.dart`: **PASSED** (6 tests).
- Ran `flutter analyze`: **PASSED** (No issues in lib/ or test/).

### Manual Verification (Expected behavior)
- On Android, the `AlarmRingingService` will now correctly adjust the system's `STREAM_ALARM` volume and apply the chosen vibration pattern.
- On iOS, the `AVAudioPlayer` will start with the specified volume and fade in as configured. Vibration will be triggered periodically while the alarm is ringing.
