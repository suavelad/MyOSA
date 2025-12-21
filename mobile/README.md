# MyOSA Mobile App

## Setup Instructions

Since this project was scaffolded manually, you **MUST** run the following command to generate the platform-specific files (Android/iOS) before running the app.

1.  Initialize the project:
    ```bash
    flutter create .
    ```
    *Note: This will verify the `pubspec.yaml` and create `android/`, `ios/`, `macos/`, `web/` directories.*

2.  Install dependencies:
    ```bash
    flutter pub get
    ```

3.  Run the app:
    ```bash
    flutter run
    ```

## Important
- **Close `mobile/api.dart` and `mobile/mqtt.dart`** if they are still open in your editor. They have been deleted and are not part of the project.
- If you see errors about `Dio`, ensure you are not looking at the deleted files.

## Troubleshooting

### "No supported devices connected"
1. **Start a Simulator/Emulator**:
   - **iOS**: Open Xcode or run `open -a Simulator`.
   - **Android**: Open Android Studio and start a Virtual Device (AVD).
2. **Run `flutter create .`**:
   - If you see "not supported by this project" for macOS/Web, running `flutter create .` will generate the necessary folders to run on desktop too.
