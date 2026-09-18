# Setting Up Luna

## Step 1: Install Flutter SDK
1. Go to https://docs.flutter.dev/get-started/install/windows/mobile
2. Download the Flutter SDK (latest stable)
3. Extract to C:\flutter
4. Add C:\flutter\bin to your PATH environment variable
5. Run: flutter doctor (fix any issues it shows)

## Step 2: Install Android Studio
1. Download from https://developer.android.com/studio
2. During install, make sure to check "Android SDK" and "Android Virtual Device"
3. Accept all SDK licenses: flutter doctor --android-licenses

## Step 3: Build Luna
```
cd C:\Users\Rahul\.gemini\antigravity\scratch\luna_app
flutter pub get
flutter build apk --release
```

Your APK will be at:
  build\app\outputs\flutter-apk\app-release.apk

## Step 4: Install on Android phone
- Enable USB Debugging on your phone (Settings > Developer Options > USB Debugging)
- Connect via USB and run: flutter install
- OR transfer the APK to your phone and install it directly

## Firebase Setup (Optional - for account sync)
1. Go to https://console.firebase.google.com
2. Create a new project called "Luna"
3. Add an Android app with package name: app.vakya.luna
4. Download google-services.json and place it in: android/app/google-services.json
5. Follow FlutterFire CLI setup: https://firebase.flutter.dev/docs/overview

## API Key
The DeepSeek API key is already configured in lib/core/services/deepseek_service.dart
To update it, change the _apiKey constant in that file.

## Troubleshooting
- Run flutter doctor to check your setup
- Run flutter pub get before building
- If you get build errors, run flutter clean then flutter pub get
