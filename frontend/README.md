# MAANAK mobile app

The app connects to the deployed MAANAK API by default:
`https://maanak-85bh.onrender.com`

## Run on an Android phone

Connect an Android device with USB debugging enabled, then run:

```powershell
flutter run
```

## Build a shareable APK

```powershell
flutter build apk --release
```

The APK is created at `build\\app\\outputs\\flutter-apk\\app-release.apk`.

## Use a local backend instead

Override the API at launch:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_IP:8000
```
