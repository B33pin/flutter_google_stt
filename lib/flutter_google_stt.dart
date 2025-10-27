export 'flutter_google_stt_platform_interface.dart'
    show TranscriptionCallback, SoundLevelCallback;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'flutter_google_stt_platform_interface.dart';
import 'src/streaming_recognizer.dart';
import 'src/token_manager.dart';

class FlutterGoogleStt {
  static TranscriptionCallback? _onTranscript;
  static SoundLevelCallback? _onSoundLevelChange;
  static StreamingRecognizer? _streamingRecognizer;
  static StreamSubscription? _streamSubscription;
  static bool _isListening = false;

  // Streaming configuration
  static String? _accessToken;
  static String _languageCode = 'en-US';
  static int _sampleRateHertz = 16000;
  static bool _useServiceAccount = false;

  /// Initialize with service account JSON map (RECOMMENDED)
  /// [serviceAccountJson] - The service account JSON as a Map
  /// [languageCode] - Language code (e.g., 'en-US', 'es-ES')
  /// [sampleRateHertz] - Audio sample rate (default: 16000)
  static Future<bool> initializeWithServiceAccount({
    required Map<String, dynamic> serviceAccountJson,
    String languageCode = 'en-US',
    int sampleRateHertz = 16000,
  }) async {
    print('🔧 FlutterGoogleStt - Initializing with service account');

    try {
      // Initialize token manager with service account
      await TokenManager.initializeWithServiceAccount(serviceAccountJson);

      // Store configuration
      _languageCode = languageCode;
      _sampleRateHertz = sampleRateHertz;
      _useServiceAccount = true;

      // Get initial access token
      _accessToken = await TokenManager.getAccessToken();
      print('🔧 FlutterGoogleStt - Access token obtained');

      // Initialize platform for audio capture
      final result = await FlutterGoogleSttPlatform.instance.initialize(
        accessToken: _accessToken!,
        languageCode: languageCode,
        sampleRateHertz: sampleRateHertz,
      );

      print('🔧 FlutterGoogleStt - Platform initialized: $result');
      return result;
    } catch (e) {
      print('❌ FlutterGoogleStt - Initialization failed: $e');
      return false;
    }
  }

  /// Initialize with service account JSON string
  /// [serviceAccountJsonString] - The service account JSON as a String
  /// [languageCode] - Language code (e.g., 'en-US', 'es-ES')
  /// [sampleRateHertz] - Audio sample rate (default: 16000)
  static Future<bool> initializeWithServiceAccountString({
    required String serviceAccountJsonString,
    String languageCode = 'en-US',
    int sampleRateHertz = 16000,
  }) async {
    print('🔧 FlutterGoogleStt - Parsing service account JSON string');
    try {
      final Map<String, dynamic> serviceAccountJson = json.decode(
        serviceAccountJsonString,
      );
      return await initializeWithServiceAccount(
        serviceAccountJson: serviceAccountJson,
        languageCode: languageCode,
        sampleRateHertz: sampleRateHertz,
      );
    } catch (e) {
      print('❌ FlutterGoogleStt - Failed to parse service account JSON: $e');
      return false;
    }
  }

  /// Initialize the speech-to-text service with Google Cloud credentials
  /// [accessToken] - Google Cloud access token for authentication
  /// [languageCode] - Language code (e.g., 'en-US', 'es-ES')
  /// [sampleRateHertz] - Audio sample rate (default: 16000)
  ///
  /// @deprecated Use initializeWithServiceAccount instead for automatic token management
  @Deprecated('Use initializeWithServiceAccount for better token management')
  static Future<bool> initialize({
    required String accessToken,
    String languageCode = 'en-US',
    int sampleRateHertz = 16000,
  }) async {
    // Store configuration for streaming
    _accessToken = accessToken;
    _languageCode = languageCode;
    _sampleRateHertz = sampleRateHertz;

    // Initialize platform for audio capture only
    return FlutterGoogleSttPlatform.instance.initialize(
      accessToken: accessToken,
      languageCode: languageCode,
      sampleRateHertz: sampleRateHertz,
    );
  }

  /// Start listening for speech input with streaming recognition
  /// [onTranscript] - Callback function that receives transcribed text and final status
  /// [onSoundLevelChange] - Optional callback function that receives sound level updates (in dB, typically -160 to 0)
  static Future<bool> startListening(
    TranscriptionCallback onTranscript, {
    SoundLevelCallback? onSoundLevelChange,
  }) async {
    if (_isListening) {
      return true;
    }

    _onTranscript = onTranscript;
    _onSoundLevelChange = onSoundLevelChange;

    if (_accessToken == null) {
      throw Exception(
        'Must call initialize() or initializeWithServiceAccount() before startListening()',
      );
    }

    try {
      // Refresh token if using service account (in case it expired)
      if (_useServiceAccount) {
        print('🔄 FlutterGoogleStt - Refreshing access token');
        _accessToken = await TokenManager.getAccessToken();
      }

      // Initialize streaming recognizer
      _streamingRecognizer = StreamingRecognizer();

      // Start WebSocket streaming
      await _streamingRecognizer!.startStreaming(
        accessToken: _accessToken!,
        languageCode: _languageCode,
        sampleRateHertz: _sampleRateHertz,
      );

      // Listen to transcript stream
      _streamSubscription = _streamingRecognizer!.transcriptStream.listen(
        (result) {
          if (result.containsKey('error')) {
            // Handle error
            _onTranscript?.call('Error: ${result['error']}', true);
          } else {
            // Handle transcript
            final transcript = result['transcript'] as String? ?? '';
            final isFinal = result['isFinal'] as bool? ?? false;
            _onTranscript?.call(transcript, isFinal);
          }
        },
        onError: (error) {
          _onTranscript?.call('Stream error: $error', true);
        },
      );

      // Start native audio capture
      final success = await FlutterGoogleSttPlatform.instance.startListening();
      if (success) {
        _isListening = true;
      } else {
        await _cleanupStreaming();
      }

      return success;
    } catch (e) {
      await _cleanupStreaming();
      throw Exception('Failed to start listening: $e');
    }
  }

  /// Stop listening for speech input
  static Future<bool> stopListening() async {
    if (!_isListening) {
      return true;
    }

    _isListening = false;

    // Stop native audio capture
    final platformResult = await FlutterGoogleSttPlatform.instance
        .stopListening();

    // Stop streaming
    await _cleanupStreaming();

    return platformResult;
  }

  /// Check if currently listening
  static Future<bool> get isListening async {
    return _isListening;
  }

  /// Internal method called by platform channel to receive audio data
  static Future<void> onAudioData(Uint8List audioData) async {
    if (_streamingRecognizer?.isStreaming == true) {
      _streamingRecognizer!.sendAudioData(audioData);
    }
  }

  /// Clean up streaming resources
  static Future<void> _cleanupStreaming() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    await _streamingRecognizer?.dispose();
    _streamingRecognizer = null;
  }

  /// Legacy method - replaced by streaming implementation
  @Deprecated('This method is replaced by streaming implementation')
  static void onTranscriptReceived(String transcript, bool isFinal) {
    _onTranscript?.call(transcript, isFinal);
  }

  /// Handle audio data received from native platforms
  static void onAudioDataReceived(List<int> audioData) {
    if (_streamingRecognizer != null) {
      _streamingRecognizer!.sendAudioData(Uint8List.fromList(audioData));
    }
  }

  /// Handle errors received from native platforms
  static void onErrorReceived(String error) {
    // Could also call onTranscript with error information if needed
  }

  /// Handle sound level changes received from native platforms
  static void onSoundLevelChanged(double level) {
    _onSoundLevelChange?.call(level);
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
