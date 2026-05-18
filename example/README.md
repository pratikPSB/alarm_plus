# alarm_plus_example

Demonstrates:

- permission request/status
- schedule exact alarm (Android) / notification alarm (iOS)
- trigger-now flow
- stop and snooze actions
- delete alarms
- list persisted alarms
- live event stream logs
- notification click -> custom screen routing

## Run

```bash
cd example
flutter pub get
flutter run
```

For Android 13+, grant notifications permission.  
For Android 12+, enable exact alarms if requested.
