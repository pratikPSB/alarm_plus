/// Presets for vibration patterns.
enum VibrationPreset {
  /// Strong continuous-like pattern.
  strong,

  /// Medium intensity pattern.
  medium,

  /// Light subtle pattern.
  light,

  /// Pattern mimicking a heartbeat.
  heartbeat,

  /// A custom vibration pattern provided via [VibrationSettings.customPattern].
  custom,
}

/// Configuration for alarm vibration.
class VibrationSettings {
  /// Creates a new [VibrationSettings] instance.
  const VibrationSettings({
    this.enabled = true,
    this.preset = VibrationPreset.medium,
    this.continuous = true,
    this.customPattern,
  });

  /// Creates a [VibrationSettings] from a map.
  factory VibrationSettings.fromMap(Map<String, dynamic> map) {
    return VibrationSettings(
      enabled: map['enabled'] as bool? ?? true,
      preset: VibrationPreset.values.firstWhere(
        (e) => e.name == map['preset'],
        orElse: () => VibrationPreset.medium,
      ),
      continuous: map['continuous'] as bool? ?? true,
      customPattern: (map['customPattern'] as List?)?.cast<int>(),
    );
  }

  /// Whether vibration is enabled.
  final bool enabled;

  /// The vibration preset to use.
  ///
  /// If [customPattern] is provided, this should be set to
  /// [VibrationPreset.custom].
  final VibrationPreset preset;

  /// Whether the vibration should repeat continuously while the alarm rings.
  final bool continuous;

  /// A custom vibration pattern represented as a list of durations in ms.
  ///
  /// The pattern should alternate between wait and vibrate durations:
  /// [wait, vibrate, wait, vibrate, ...]
  ///
  /// This field is used when [preset] is [VibrationPreset.custom].
  final List<int>? customPattern;

  /// Converts this [VibrationSettings] to a map.
  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'preset': preset.name,
      'continuous': continuous,
      'customPattern': customPattern,
    };
  }
}
