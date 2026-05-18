class AlarmPermissionStatus {
  const AlarmPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.fullScreenIntentGranted,
    required this.canOpenExactAlarmSettings,
    required this.canOpenFullScreenSettings,
    required this.criticalAlertsEligible,
    required this.platformMeta,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool fullScreenIntentGranted;
  final bool canOpenExactAlarmSettings;
  final bool canOpenFullScreenSettings;
  final bool criticalAlertsEligible;
  final Map<String, dynamic> platformMeta;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'notificationsGranted': notificationsGranted,
      'exactAlarmsGranted': exactAlarmsGranted,
      'fullScreenIntentGranted': fullScreenIntentGranted,
      'canOpenExactAlarmSettings': canOpenExactAlarmSettings,
      'canOpenFullScreenSettings': canOpenFullScreenSettings,
      'criticalAlertsEligible': criticalAlertsEligible,
      'platformMeta': platformMeta,
    };
  }

  factory AlarmPermissionStatus.fromMap(Map<String, dynamic> map) {
    return AlarmPermissionStatus(
      notificationsGranted: map['notificationsGranted'] == true,
      exactAlarmsGranted: map['exactAlarmsGranted'] == true,
      fullScreenIntentGranted: map['fullScreenIntentGranted'] == true,
      canOpenExactAlarmSettings: map['canOpenExactAlarmSettings'] == true,
      canOpenFullScreenSettings: map['canOpenFullScreenSettings'] == true,
      criticalAlertsEligible: map['criticalAlertsEligible'] == true,
      platformMeta: (map['platformMeta'] is Map)
          ? Map<String, dynamic>.from(map['platformMeta'] as Map)
          : <String, dynamic>{},
    );
  }
}
