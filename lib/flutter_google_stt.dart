export 'flutter_google_stt_platform_interface.dart' show TranscriptionCallback;

import 'flutter_google_stt_platform_interface.dart';

class FlutterGoogleStt {
  static TranscriptionCallback? _onTranscript;
  
  /// Initialize the speech-to-text service with Google Cloud credentials
  /// [accessToken] - Google Cloud access token for authentication
  /// [languageCode] - Language code (e.g., 'en-US', 'es-ES')
  /// [sampleRateHertz] - Audio sample rate (default: 16000)
  static Future<bool> initialize({
    required String accessToken,
    String languageCode = 'en-US',
    int sampleRateHertz = 16000,
  }) {
    return FlutterGoogleSttPlatform.instance.initialize(
      accessToken: accessToken,
      languageCode: languageCode,
      sampleRateHertz: sampleRateHertz,
    );
  }
  
  /// Start listening for speech input
  /// [onTranscript] - Callback function that receives transcribed text and final status
  static Future<bool> startListening(TranscriptionCallback onTranscript) async {
    _onTranscript = onTranscript;
    return FlutterGoogleSttPlatform.instance.startListening();
  }
  
  /// Stop listening for speech input
  static Future<bool> stopListening() {
    return FlutterGoogleSttPlatform.instance.stopListening();
  }
  
  /// Check if currently listening
  static Future<bool> get isListening {
    return FlutterGoogleSttPlatform.instance.isListening();
  }
  
  /// Internal method called by platform channel
  static void onTranscriptReceived(String transcript, bool isFinal) {
    _onTranscript?.call(transcript, isFinal);
  }
  
  /// Check if microphone permission is granted
  static Future<bool> get hasMicrophonePermission {
    return FlutterGoogleSttPlatform.instance.hasMicrophonePermission();
  }
  
  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() {
    return FlutterGoogleSttPlatform.instance.requestMicrophonePermission();
  }
}
