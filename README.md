# Campus Hoops Editor — Flutter

## Build
Install Flutter, then from this folder:

```bash
flutter pub get
flutter run
```

Android APK:
```bash
flutter build apk --release
```

The APK will be under `build/app/outputs/flutter-apk/`.

Windows:
```bash
flutter config --enable-windows-desktop
flutter run -d windows
```

## Features
- Open `.campushoops`
- Reads ZIP container and `session.json.gz`
- Finds teams and players
- Defaults to Jackson State when present
- Edit player height and overall rating
- Set detected team ratings to 99
- Save as a new `.campushoops`

Back up saves before editing. The exact game version may change its save schema, so test edited files on a copy first.
