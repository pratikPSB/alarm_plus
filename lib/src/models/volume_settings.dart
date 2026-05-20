/// Represents a single step in a volume fade sequence.
class VolumeFadeStep {
  /// Creates a [VolumeFadeStep].
  const VolumeFadeStep({
    required this.volume,
    required this.at,
  });

  /// Creates a [VolumeFadeStep] from a map.
  factory VolumeFadeStep.fromMap(Map<String, dynamic> map) {
    return VolumeFadeStep(
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      at: Duration(milliseconds: (map['atMs'] as num?)?.toInt() ?? 0),
    );
  }

  /// The volume level at this step (0.0 to 1.0).
  final double volume;

  /// The duration from the start of the alarm when this
  /// volume should be reached.
  final Duration at;

  /// Converts this [VolumeFadeStep] to a map.
  Map<String, dynamic> toMap() {
    return {
      'volume': volume,
      'atMs': at.inMilliseconds,
    };
  }
}

/// Configuration for alarm volume and fading.
class VolumeSettings {
  /// Creates a new [VolumeSettings] instance.
  const VolumeSettings({
    this.volume,
    this.fadeDuration,
    this.fadeSteps = const [],
    this.volumeEnforced = false,
  });

  /// Creates a [VolumeSettings] from a map.
  factory VolumeSettings.fromMap(Map<String, dynamic> map) {
    return VolumeSettings(
      volume: (map['volume'] as num?)?.toDouble(),
      fadeDuration: map['fadeDurationMs'] != null
          ? Duration(milliseconds: (map['fadeDurationMs'] as num).toInt())
          : null,
      fadeSteps: (map['fadeSteps'] as List?)
              ?.map((e) => VolumeFadeStep.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          const [],
      volumeEnforced: map['volumeEnforced'] as bool? ?? false,
    );
  }

  /// Sets system volume level (0.0 to 1.0).
  /// Reverts on alarm stop. Defaults to current volume if null.
  final double? volume;

  /// Duration over which to fade the alarm ringtone.
  /// If provided, volume starts at 0 and reaches [volume] or 1.0
  /// linearly over this duration.
  final Duration? fadeDuration;

  /// Controls how the alarm volume will fade over time with custom steps.
  /// If provided, [fadeDuration] is ignored.
  final List<VolumeFadeStep> fadeSteps;

  /// Automatically resets to the target alarm volume if the user
  /// attempts to adjust it.
  final bool volumeEnforced;

  /// Converts this [VolumeSettings] to a map.
  Map<String, dynamic> toMap() {
    return {
      'volume': volume,
      'fadeDurationMs': fadeDuration?.inMilliseconds,
      'fadeSteps': fadeSteps.map((e) => e.toMap()).toList(),
      'volumeEnforced': volumeEnforced,
    };
  }
}
