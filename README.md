# Splitwise

Splitwise is a Flutter application that helps users manage and split expenses with friends and family. This project integrates Firebase for authentication and data storage.
# Splitwise (Flutter)

A lightweight Splitwise-style Flutter app that demonstrates: Firebase Authentication (email/password + Google Sign-In), Cloud Firestore data modeling for users, groups and expenses, push notifications (FCM), and a centralized dark theme.

This README explains how to set up and run the project locally, configure Firebase and Google Sign-In, and common troubleshooting steps.

---

## Table of contents
- Features
- Prerequisites
- Quick start
- Firebase setup (detailed)
    - Add Android/iOS apps
    - SHA‑1 / SHA‑256 fingerprints (Android)
    - Enable Google Sign-In in Firebase
    - Download `google-services.json` / `GoogleService-Info.plist`
- Configuration in this project
- Run commands
- Testing & debug tips
- Troubleshooting
- Contributing

---

## Features
- Email/password sign up (with email verification)
- Google Sign-In (web & mobile) with Firestore user document creation
- Cloud Firestore as primary app database (`users`, `groups`, `expenses` collections)
- Push notifications via Firebase Messaging (FCM)
- Centralized theming (`lib/theme.dart`) and accessible forms

## Prerequisites
- Flutter SDK (matching project SDK constraint; project has `environment: sdk: ^3.6.2`)
- Java JDK (for Android tooling / `keytool`)
- A Firebase project (console.firebase.google.com)
- Android/iOS devices or emulators for testing

## Quick start
1. Clone the repo

```bash
git clone https://github.com/chirag640/Flutter-splitWiseClone.git
cd Flutter-splitWiseClone
```

2. Install dependencies

```bash
flutter pub get
```

3. Follow the Firebase setup below (very important for Google Sign-In and FCM).

4. Run the app

```bash
flutter run
```

---

## Firebase setup (detailed)
This project expects Firebase to be set up and initialized in `main.dart` (already present). You must add your Android/iOS/web app in the Firebase console and download the platform config files.

### Android
1. In Firebase Console, select your project → Project settings → Your apps → Add app → Android.
2. Enter your Android package name (applicationId). It must exactly match `android/app/src/main/AndroidManifest.xml`.
3. (Important) Add SHA‑1 and SHA‑256 fingerprints:
     - For debug keystore (Windows cmd):

```cmd
keytool -list -v -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android
```

     - For a release keystore (replace values):

```cmd
keytool -list -v -alias YOUR_ALIAS -keystore "C:\path\to\keystore.jks" -storepass YOUR_STORE_PASS -keypass YOUR_KEY_PASS
```

     - If you publish via Google Play and use Play App Signing, copy the *App signing key* SHA‑256 from the Play Console and add it in Firebase as well.
4. Download the `google-services.json` and place it at `android/app/google-services.json` (replace the project file already present if any).
5. Verify `android/build.gradle` and `android/app/build.gradle` contain the Google services plugin lines (they are typically required):

- In `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15' // example
    }
}
```

- In `android/app/build.gradle` near the bottom:

```gradle
apply plugin: 'com.google.gms.google-services'
```

6. Rebuild the app.

### iOS
1. Add an iOS app in Firebase Console and download `GoogleService-Info.plist`.
2. Place `GoogleService-Info.plist` into `ios/Runner/` in Xcode (or copy it to the folder and ensure it is included in Runner target).
3. In `Info.plist`, ensure URL types and reverse client ID are present (Xcode adds this when you add the plist file).
4. Follow Firebase iOS setup: CocoaPods install and platform targets (see official docs).

### Web
1. Add a web app in Firebase Console and copy the Firebase config values to your web initialization if needed.
2. Ensure Authorized domains include `localhost` (for local testing) and your hosting domain.

### Enable Google Sign-In
- In Firebase Console → Authentication → Sign-in method → Enable `Google` provider.

---

## Configuration in this project
- Firebase initialization: `lib/main.dart` calls `Firebase.initializeApp()`; verify the platform-specific config files are present before running.
- Google Sign-In is wired in `lib/screens/login_signup.dart` and `lib/screens/sign_in.dart` (the landing & sign-in flows). After successful Google authentication the app writes/merges a Firestore user document at `users/{uid}`.
- User profile UI reads from `users/{uid}` (see `lib/widgets/user_profile.dart`). The code now creates a minimal user document when missing (useful for Google sign-ins).

## Run commands
- Get packages:

```bash
flutter pub get
```

- Analyze the project:

```bash
flutter analyze
```

- Run on connected device:

```bash
flutter run
```

- Run on Chrome (web):

```bash
flutter run -d chrome
```

---

## Troubleshooting
- "No user data found" after Google Sign-In:
    - Confirm the sign-in flow completed and user appears in Firebase Auth console.
    - Confirm Firestore has a `users/{uid}` document. The app now writes this automatically on sign-in; if you still see missing document, check logs for `Failed to write user doc` messages and ensure Firestore rules permit the write for authenticated users.

- Google Sign-In OAuth errors:
    - Make sure SHA‑1 and SHA‑256 fingerprints are added to the Android app in Firebase.
    - For Play-signed apps, add the Play App Signing key fingerprint.
    - Re-download `google-services.json` after adding fingerprints.

- FCM token is null on desktop or unsupported platforms: this is expected. The app uses a safe helper that returns null when Firebase Messaging is not supported.

- "No Material widget found" assertion when showing bottom sheets with TextField: ensure sheets are Material-wrapped — the codebase already addresses this.

---

## Notes for contributors
- Code style follows basic Flutter conventions; prefer const widgets and small reusable components.
- If you add new auth providers, mirror the Firestore user creation logic used in `lib/screens/login_signup.dart`.

---

## Contact
If you run into issues, open an issue on the repository or contact the maintainer.

---

License: MIT 
