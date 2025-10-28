# Model Selection - Quick Reference

## Basic Usage

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  model: 'latest_long', // Add this parameter
);
```

## Quick Model Selector

### I'm building a... → Use this model:

| Use Case | Model | Why |
|----------|-------|-----|
| 📝 **Dictation app** | `latest_long` | Best accuracy for long content |
| 🎤 **Voice notes** | `latest_long` | Handles natural speech well |
| 🗣️ **Voice commands** | `command_and_search` | Lowest latency for quick commands |
| 🔍 **Voice search** | `latest_short` | Fast for short queries |
| 📞 **Call transcription** | `phone_call` | Optimized for phone audio |
| 🎬 **Video subtitles** | `video` | Handles background noise |
| 🤖 **Chatbot/Assistant** | `latest_short` | Good for conversational turns |
| 📊 **Meeting transcription** | `latest_long` | Best for multi-speaker content |

## Common Examples

### Example 1: General Dictation (Most Common)
```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 16000,
  model: 'latest_long', // ⭐ Best for most apps
);
```

### Example 2: Voice Commands
```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 16000,
  model: 'command_and_search', // ⚡ Fastest response
);
```

### Example 3: No Model (Use Default)
```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  // model not specified - Google chooses automatically
);
```

## Model Comparison at a Glance

```
Accuracy:  latest_long > phone_call = video > latest_short > command_and_search
Latency:   command_and_search < latest_short < latest_long = phone_call = video
```

## When to Use Each Model

### ✅ Use `latest_long` when:
- Audio is longer than 1 minute
- Accuracy is more important than speed
- Transcribing conversations, meetings, or dictation
- **This is the recommended default!**

### ✅ Use `latest_short` when:
- Audio is less than 1 minute
- Need balance between speed and accuracy
- Voice queries or short messages
- Quick voice notes

### ✅ Use `command_and_search` when:
- Need the fastest possible response
- Single word commands or short phrases
- Voice UI controls (play, stop, next, etc.)
- Search queries

### ✅ Use `phone_call` when:
- Audio source is a phone call
- Using 8kHz sample rate
- Call center transcriptions

### ✅ Use `video` when:
- Transcribing video content
- Background noise or music present
- Multiple speakers
- Creating subtitles

## Complete Working Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_stt/flutter_google_stt.dart';

class MySTTApp extends StatefulWidget {
  @override
  _MySTTAppState createState() => _MySTTAppState();
}

class _MySTTAppState extends State<MySTTApp> {
  String _transcript = '';
  
  Future<void> _initializeSTT() async {
    final serviceAccountJson = await rootBundle.loadString(
      'assets/service_account.json',
    );
    
    await FlutterGoogleStt.initializeWithServiceAccountString(
      serviceAccountJsonString: serviceAccountJson,
      languageCode: 'en-US',
      sampleRateHertz: 16000,
      model: 'latest_long', // 🎯 Choose your model here
    );
  }
  
  Future<void> _startListening() async {
    await FlutterGoogleStt.startListening(
      (transcript, isFinal) {
        setState(() {
          _transcript = transcript;
        });
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(_transcript)),
      floatingActionButton: FloatingActionButton(
        onPressed: _startListening,
        child: Icon(Icons.mic),
      ),
    );
  }
}
```

## Testing Multiple Models

```dart
// Easy model switching for testing
class _MyAppState extends State<MyApp> {
  String _currentModel = 'latest_long';
  
  List<String> _availableModels = [
    'latest_long',
    'latest_short',
    'command_and_search',
    'phone_call',
    'video',
  ];
  
  Future<void> _switchModel(String newModel) async {
    await FlutterGoogleStt.stopListening();
    
    final serviceAccountJson = await rootBundle.loadString(
      'assets/service_account.json',
    );
    
    await FlutterGoogleStt.initializeWithServiceAccountString(
      serviceAccountJsonString: serviceAccountJson,
      languageCode: 'en-US',
      model: newModel,
    );
    
    setState(() {
      _currentModel = newModel;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: _currentModel,
      items: _availableModels.map((model) {
        return DropdownMenuItem(
          value: model,
          child: Text(model),
        );
      }).toList(),
      onChanged: (newModel) {
        if (newModel != null) {
          _switchModel(newModel);
        }
      },
    );
  }
}
```

## Pro Tips 💡

1. **Start with `latest_long`** - It works great for most use cases
2. **Test with your audio** - Different models perform differently with various audio sources
3. **Consider latency** - If users complain about delays, try `latest_short`
4. **Match audio type** - Phone audio? Use `phone_call`. Video? Use `video`.
5. **No model = Default** - Omitting the model parameter uses Google's default (usually fine)

## Need More Details?

See the comprehensive [MODEL_GUIDE.md](MODEL_GUIDE.md) for:
- Detailed model descriptions
- Performance comparisons
- Language-specific considerations
- Cost information
- Advanced use cases

## Quick Debug

If transcription accuracy is poor:
1. ✅ Try `latest_long` for better accuracy
2. ✅ Check your audio quality (should be clear)
3. ✅ Verify language code matches spoken language
4. ✅ Ensure proper sample rate (16000 Hz recommended)

If transcription is slow:
1. ✅ Try `latest_short` for faster response
2. ✅ For commands only, use `command_and_search`
3. ✅ Check your internet connection
