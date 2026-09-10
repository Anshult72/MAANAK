# MAANAK mobile app

The app connects to the deployed MAANAK API on Railway by default:
`https://maanak-production.up.railway.app`

## Run on an Android phone

Connect an Android device with USB debugging enabled, then run:

```powershell
flutter run
```

## Build a shareable APK

```powershell
flutter build apk --release
```

The APK is created at `build\\outputs\\flutter-apk\\app-release.apk`.

## Use a local backend instead

Override the API at launch:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_IP:8000
```

## Environment Separation

| Environment | API Target | Command |
|---|---|---|
| **Production** | Railway (`https://maanak-production.up.railway.app`) | `flutter build apk --release` |
| **Development** | Local FastAPI | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000` |
