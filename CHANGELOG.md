# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-07-11

### Added
- Initial release of Flutter Google Speech-to-Text plugin
- Real-time speech recognition using Google Cloud Speech-to-Text API
- Cross-platform support for Android and iOS
- MethodChannel communication between Dart and native code
- Android implementation using AudioRecord and Kotlin with gRPC streaming
- iOS implementation using AVAudioEngine and Swift with REST API calls
- Microphone permission handling for both platforms
- Configurable language codes and audio settings
- Secure token-based authentication
- Comprehensive example app demonstrating usage
- Full API documentation and setup instructions

### Features
- `initialize()` method for setting up Google Cloud credentials
- `startListening()` method with real-time transcript callbacks
- `stopListening()` method for ending speech recognition
- `isListening` property to check current state
- `hasMicrophonePermission` and `requestMicrophonePermission` for permission management
- Support for interim and final transcription results
- Error handling with detailed error messages

### Technical Details
- Android: Uses AudioRecord for audio capture and Google Cloud Speech gRPC client
- iOS: Uses AVAudioEngine for audio capture and REST API calls
- Proper audio session management on iOS
- Privacy manifest support for iOS App Store requirements
- Gradle dependencies management for Android
- CocoaPods integration for iOS

### Documentation
- Comprehensive README with setup instructions
- API reference documentation
- Example usage code
- Google Cloud setup guide
- Platform-specific configuration instructions
