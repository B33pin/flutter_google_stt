# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-07-12

### Added
- **Production Release**: First stable release of Flutter Google Speech-to-Text plugin
- Real-time speech recognition using Google Cloud Speech-to-Text REST API
- Cross-platform support for Android (Kotlin) and iOS (Swift)
- Google Cloud API key authentication support
- Microphone permission handling with native platform requests
- Configurable language codes and audio settings (16kHz PCM audio)
- Clean, production-ready codebase with proper error handling
- Comprehensive API documentation and examples
- Full test coverage with unit and integration tests

### Changed
- **Package Name**: Updated to `com.guptan404.flutter_google_stt`
- **API Implementation**: Uses REST API instead of gRPC for better compatibility
- **Error Handling**: Improved error reporting with specific error codes
- **Code Quality**: Removed debug logs and optimized for production use

### Technical Details
- Android implementation using AudioRecord and OkHttp3
- iOS implementation using AVAudioEngine and URLSession
- Method channel communication between Dart and native platforms
- Support for interim and final transcription results
- Automatic audio chunking and processing

## [0.0.1] - 2025-07-11

### Added
- Initial development release
- Basic speech recognition functionality
- Example app for testing
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
