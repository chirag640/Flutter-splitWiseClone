# Splitwise

Splitwise is a Flutter application that helps users manage and split expenses with friends and family. This project integrates Firebase for authentication and data storage.

## Features

- User authentication with Firebase
- Expense tracking and management
- Cloud Firestore for data storage
- UUID for unique identifiers
- Shared preferences for local storage

## Getting Started

### Prerequisites

- Flutter SDK: ^3.6.2
- Dart SDK
- Firebase account

### Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/chirag640/Flutter-splitWiseClone.git
    cd splitwise
    ```

2. Install dependencies:
    ```sh
    flutter pub get
    ```

3. Set up Firebase:
    - Follow the [Firebase setup guide](https://firebase.google.com/docs/flutter/setup) to add Firebase to your Flutter project.
    - Add your `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) to the respective directories.

### Running the App

To run the app on an emulator or physical device, use the following command:
```sh
flutter run
```
## Project Structure
- lib/: Contains the main source code for the application.
- assets/images/: Contains image assets used in the application.
- ios/ and android/: Platform-specific code and configurations.
- pubspec.yaml: Project dependencies and configurations.

## Dependencies
- firebase_core: ^3.12.1
- firebase_auth: ^5.5.1
- image_picker: ^1.1.2
- cloud_firestore: ^5.6.5
- uuid: ^4.5.1
- flutter_launcher_icons: ^0.14.3
- shared_preferences: ^2.5.2

## Contributing
- Contributions are welcome! Please open an issue or submit a pull request.
