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
  double _soundLevel = 0.0;
  List<double> _waveform = [];

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

      final bool
      success = await FlutterGoogleStt.initializeWithServiceAccountString(
        serviceAccountJsonString: serviceAccountJson,
        languageCode: 'en-US',
        sampleRateHertz: 16000,
        // Optional: Specify a model for better accuracy
        // Available models: 'latest_long', 'latest_short', 'command_and_search',
        // 'phone_call', 'video', 'default'
        // model: 'latest_long', // Uncomment to use a specific model
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
      final bool success = await FlutterGoogleStt.startListening(
        (transcript, isFinal) {
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
        },
        onSoundLevelChange: (double level) {
          // Convert dB level to normalized value (0.0 to 1.0)
          // Sound level ranges from -160 dB (silence) to 0 dB (max)
          // More negative = quieter, closer to 0 = louder
          // Adjusted range based on typical microphone input: -80 to -20 dB

          // Clamp the dB value to our working range
          // -80 dB = very quiet/background noise -> 0%
          // -20 dB = loud speech -> 100%
          double clampedDb = level.clamp(-80, -20);

          // Map from [-80, -20] to [0, 100]
          int normalizedValue = (((clampedDb + 80) / 60) * 100).round();

          // Ensure bounds
          normalizedValue = normalizedValue.clamp(0, 100);

          print('level : $level dB, normalized: $normalizedValue%');

          setState(() {
            _soundLevel = normalizedValue / 100;
            // Keep last 50 values for waveform visualization
            _waveform.add(_soundLevel);
            if (_waveform.length > 50) {
              _waveform.removeAt(0);
            }
          });
        },
      );

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
        _soundLevel = 0.0;
        _waveform.clear();
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
              // Sound level visualization
              if (_isListening)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Sound Level',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        // Sound level bar
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: LinearProgressIndicator(
                              value: _soundLevel,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _soundLevel > 0.7
                                    ? Colors.red
                                    : _soundLevel > 0.4
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              minHeight: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_soundLevel * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Waveform visualization
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CustomPaint(
                            painter: WaveformPainter(_waveform),
                            size: const Size(double.infinity, 80),
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

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> waveform;

  WaveformPainter(this.waveform);

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final step = width / (waveform.length - 1).clamp(1, double.infinity);

    for (int i = 0; i < waveform.length; i++) {
      final x = i * step;
      final y = height - (waveform[i] * height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return true; // Repaint on every frame for smooth animation
  }
}
