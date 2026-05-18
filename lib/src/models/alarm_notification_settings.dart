class AlarmNotificationSettings {
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
  });

  final String? title;
  final String? body;
  final String? stopButtonText;
  final String? snoozeButtonText;
  
  /// Path to a custom sound asset (e.g. 'assets/audio/alarm.mp3')
  final String? soundAsset;
  
  /// The icon name for Android small icon (e.g. 'ic_notification')
  final String? icon;
  
  /// Path to a large icon asset for the notification
  final String? largeIconAsset;
  
  /// Path to a big picture asset for the notification
  final String? bigPictureAsset;

  /// URL to a large icon image for the notification
  final String? largeIconUrl;

  /// URL to a big picture image for the notification
  final String? bigPictureUrl;

  /// Custom payload specifically for the notification interaction
  final String? payload;

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
    };
  }

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
    );
  }
}
