import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter_google_stt/flutter_google_stt.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _finalTranscript = '';
  String _interimTranscript = '';
  bool _isListening = false;
  bool _isInitialized = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    try {
      // Load service account JSON from assets
      final String serviceAccountJson = await rootBundle.loadString(
        'assets/service_account.json',
      );

      final bool success =
          await FlutterGoogleStt.initializeWithServiceAccountString(
            serviceAccountJsonString: serviceAccountJson,
            languageCode: 'en-US',
            sampleRateHertz: 16000,
          );

      setState(() {
        _isInitialized = success;
        _status = success ? 'Initialized successfully' : 'Failed to initialize';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      await _initializePlugin();
      return;
    }

    bool hasPermission = await FlutterGoogleStt.hasMicrophonePermission;

    if (!hasPermission) {
      try {
        hasPermission = await FlutterGoogleStt.requestMicrophonePermission()
            .timeout(const Duration(seconds: 10), onTimeout: () => false);
      } catch (e) {
        hasPermission = false;
      }

      if (!hasPermission) {
        setState(() {
          _status = 'Microphone permission denied';
        });
        return;
      }
    }

    try {
      final bool success = await FlutterGoogleStt.startListening((
        transcript,
        isFinal,
      ) {
        print('transcript: $transcript, isFinal: $isFinal');
        setState(() {
          if (isFinal) {
            _finalTranscript += '$transcript ';
            _interimTranscript = '';
            _status = 'Listening...';
          } else {
            _interimTranscript = transcript;
            _status = 'Listening...';
          }
        });
      });

      setState(() {
        _isListening = success;
        if (!success) _status = 'Failed to start listening';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _stopListening() async {
    try {
      final bool success = await FlutterGoogleStt.stopListening();

      setState(() {
        _isListening = false;
        _status = success ? 'Stopped' : 'Failed to stop';
        _interimTranscript = '';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Google Speech-to-Text Demo'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: TextStyle(
                          color: _isInitialized ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Transcript',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              children: [
                                // Final transcript in normal text
                                TextSpan(
                                  text: _finalTranscript,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                // Interim transcript in gray italic
                                if (_interimTranscript.isNotEmpty)
                                  TextSpan(
                                    text: _interimTranscript,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                // Default text if nothing yet
                                if (_finalTranscript.isEmpty &&
                                    _interimTranscript.isEmpty)
                                  const TextSpan(
                                    text: 'No speech detected yet...',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!_isInitialized)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Initializing...',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _isListening ? _stopListening : _startListening,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(
                    _isListening ? 'Stop Listening' : 'Start Listening',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Place your service account JSON file in assets/service_account.json',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
