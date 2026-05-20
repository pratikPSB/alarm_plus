import 'package:alarm_plus/src/models/vibration_settings.dart';
import 'package:alarm_plus/src/models/volume_settings.dart';

/// Customizes alarm notification appearance and behavior.
///
/// Use this to define custom titles, bodies, button text, audio,
/// icons, and images for both Android and iOS notifications.
///
/// All fields are optional; platform defaults are used for null values.
///
/// **Platform Differences**:
/// - **Android**: Supports custom sound assets, drawable icons, and URL-based
///   images via Coil
/// - **iOS**: Supports sound assets; URL images are downloaded synchronously
///
/// **Example**:
/// ```dart
/// const settings = AlarmNotificationSettings(
///   title: 'Morning Alarm',
///   body: 'Time to wake up!',
///   stopButtonText: 'Dismiss',
///   snoozeButtonText: 'Snooze 5 min',
///   soundAsset: 'assets/sounds/alarm.mp3',
///   icon: 'ic_alarm',
///   bigPictureUrl: 'https://example.com/banner.png',
///   payload: 'custom_data',
/// );
///
/// await AlarmPlus.schedule(
///   id: 'morning',
///   time: tomorrow7am,
///   notificationSettings: settings,
/// );
/// ```
class AlarmNotificationSettings {
  /// Creates notification settings for an alarm.
  const AlarmNotificationSettings({
    this.title,
    this.body,
    this.stopButtonText,
    this.snoozeButtonText,
    this.soundAsset,
    this.icon,
    this.largeIconAsset,
    this.bigPictureAsset,
    this.largeIconUrl,
    this.bigPictureUrl,
    this.payload,
    this.vibrationSettings = const VibrationSettings(),
    this.volumeSettings = const VolumeSettings(),
  });

  /// Deserializes notification settings from a map.
  factory AlarmNotificationSettings.fromMap(Map<String, dynamic> map) {
    return AlarmNotificationSettings(
      title: map['title']?.toString(),
      body: map['body']?.toString(),
      stopButtonText: map['stopButtonText']?.toString(),
      snoozeButtonText: map['snoozeButtonText']?.toString(),
      soundAsset: map['soundAsset']?.toString(),
      icon: map['icon']?.toString(),
      largeIconAsset: map['largeIconAsset']?.toString(),
      bigPictureAsset: map['bigPictureAsset']?.toString(),
      largeIconUrl: map['largeIconUrl']?.toString(),
      bigPictureUrl: map['bigPictureUrl']?.toString(),
      payload: map['payload']?.toString(),
      vibrationSettings: map['vibrationSettings'] != null
          ? VibrationSettings.fromMap(
              Map<String, dynamic>.from(map['vibrationSettings'] as Map),
            )
          : const VibrationSettings(),
      volumeSettings: map['volumeSettings'] != null
          ? VolumeSettings.fromMap(
              Map<String, dynamic>.from(map['volumeSettings'] as Map),
            )
          : const VolumeSettings(),
    );
  }

  /// Notification title (heading).
  ///
  /// Example: "Wake Up!"
  final String? title;

  /// Notification body text (content).
  ///
  /// Example: "You have an alarm in 5 minutes."
  final String? body;

  /// Label for the stop/dismiss action button.
  ///
  /// Android only (iOS uses system action buttons).
  /// Example: "Dismiss" or "Stop"
  final String? stopButtonText;

  /// Label for the snooze action button.
  ///
  /// Example: "Snooze 5m"
  /// Not used by iOS; included for cross-platform consistency.
  final String? snoozeButtonText;
  
  /// Path to a custom sound asset (e.g. 'assets/audio/alarm.mp3')
  ///
  /// Must be included in pubspec.yaml assets.
  /// Platform playback rules:
  /// - **Android**: Looped during ringing service
  /// - **iOS**: Looped via AVAudioPlayer; respects silent switch settings
  final String? soundAsset;
  
  /// The icon name for Android small icon (e.g. 'ic_notification')
  ///
  /// Name of an Android drawable in `android/app/src/main/res/drawable/`.
  /// iOS uses app icon automatically.
  final String? icon;
  
  /// Path to a large icon asset for the notification (e.g. 'assets/images/alarm.png')
  ///
  /// Used on Android for the large icon display.
  /// iOS does not use large icons.
  final String? largeIconAsset;
  
  /// Path to a big picture asset for the notification (e.g. 'assets/images/banner.png')
  ///
  /// Used on Android for big picture notification style.
  /// iOS does not use big picture.
  final String? bigPictureAsset;

  /// URL to a large icon image for the notification.
  ///
  /// HTTP/HTTPS URL. Downloaded at notification display time.
  /// - **Android**: Via Coil image loading library
  /// - **iOS**: Synchronous download
  /// Takes precedence over [largeIconAsset] if both provided.
  final String? largeIconUrl;

  /// URL to a big picture image for the notification.
  ///
  /// HTTP/HTTPS URL. Downloaded at notification display time.
  /// - **Android**: Via Coil; used in big picture notification style
  /// - **iOS**: Not used
  /// Takes precedence over [bigPictureAsset] if both provided.
  final String? bigPictureUrl;

  /// Custom payload string for notification interaction.
  ///
  /// Application-specific data passed to notification response handler.
  /// Not used by the plugin; purely for app use when handling actions.
  /// For structured data, serialize to JSON string yourself.
  final String? payload;

  /// Configuration for vibration pattern and behavior.
  final VibrationSettings vibrationSettings;

  /// Configuration for volume level, fading, and enforcement.
  final VolumeSettings volumeSettings;

  /// Serializes notification settings to a map.
  ///
  /// Only non-null fields are included (sparse representation).
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (stopButtonText != null) 'stopButtonText': stopButtonText,
      if (snoozeButtonText != null) 'snoozeButtonText': snoozeButtonText,
      if (soundAsset != null) 'soundAsset': soundAsset,
      if (icon != null) 'icon': icon,
      if (largeIconAsset != null) 'largeIconAsset': largeIconAsset,
      if (bigPictureAsset != null) 'bigPictureAsset': bigPictureAsset,
      if (largeIconUrl != null) 'largeIconUrl': largeIconUrl,
      if (bigPictureUrl != null) 'bigPictureUrl': bigPictureUrl,
      if (payload != null) 'payload': payload,
      'vibrationSettings': vibrationSettings.toMap(),
      'volumeSettings': volumeSettings.toMap(),
    };
  }
}
