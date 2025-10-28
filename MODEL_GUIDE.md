# Google Speech-to-Text Models Guide

## Overview
Google Cloud Speech-to-Text offers various models optimized for different use cases. You can now specify which model to use when initializing the plugin.

## Available Models

### 1. **latest_long** (Recommended for most use cases)
- **Best for**: Long-form audio content, dictation, conversations
- **Optimized for**: General transcription with enhanced accuracy
- **Audio length**: Best for audio longer than 1 minute
- **Languages**: Wide language support
- **Features**: Supports all recognition features including automatic punctuation

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  model: 'latest_long',
);
```

### 2. **latest_short**
- **Best for**: Short audio clips, voice commands, queries
- **Optimized for**: Low-latency transcription
- **Audio length**: Best for audio shorter than 1 minute
- **Use cases**: Voice search, voice commands, short utterances
- **Features**: Faster processing with good accuracy

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  model: 'latest_short',
);
```

### 3. **command_and_search**
- **Best for**: Voice commands and voice search queries
- **Optimized for**: Short commands, keywords, search queries
- **Audio length**: Very short audio (typically less than a few seconds)
- **Use cases**: Voice UI controls, search queries, navigation commands
- **Features**: Very low latency, optimized for single words/phrases

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  model: 'command_and_search',
);
```

### 4. **phone_call**
- **Best for**: Audio from phone calls
- **Optimized for**: Telephony audio (8kHz sample rate)
- **Audio length**: Any length
- **Use cases**: Call center transcriptions, phone interviews
- **Features**: Enhanced for phone call audio quality
- **Note**: Works best with 8kHz sample rate

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 8000, // Phone call quality
  model: 'phone_call',
);
```

### 5. **video**
- **Best for**: Audio extracted from video content
- **Optimized for**: Video transcription, subtitles/captions
- **Audio length**: Any length
- **Use cases**: Video subtitles, video indexing, media content
- **Features**: Handles background noise and multiple speakers

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  model: 'video',
);
```

### 6. **default** (No model specified)
- **Best for**: General purpose when you're unsure
- **Optimized for**: Balanced performance
- **Audio length**: Any length
- **Use cases**: General transcription needs
- **Features**: Google automatically selects appropriate model

```dart
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  // model parameter omitted - uses default
);
```

## Model Selection Guide

### Choose **latest_long** if:
- ✅ Recording conversations or dictation
- ✅ Audio is longer than 1 minute
- ✅ You need the highest accuracy
- ✅ Latency is not critical (still real-time)
- ✅ **This is the recommended default for most apps**

### Choose **latest_short** if:
- ✅ Processing short voice commands or queries
- ✅ Audio is less than 1 minute
- ✅ You need faster response times
- ✅ Use case involves quick interactions

### Choose **command_and_search** if:
- ✅ Building voice UI controls
- ✅ Implementing voice search
- ✅ Need very low latency
- ✅ Audio is very short (few seconds)

### Choose **phone_call** if:
- ✅ Transcribing phone conversations
- ✅ Audio source is telephony (landline/mobile)
- ✅ Audio quality is 8kHz sample rate
- ✅ Building call center solutions

### Choose **video** if:
- ✅ Transcribing video content
- ✅ Generating subtitles/captions
- ✅ Multiple speakers or background noise
- ✅ Media production workflows

## Usage Examples

### Example 1: Dictation App
```dart
// Use latest_long for best accuracy in long-form content
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 16000,
  model: 'latest_long',
);
```

### Example 2: Voice Command Interface
```dart
// Use command_and_search for quick voice commands
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 16000,
  model: 'command_and_search',
);
```

### Example 3: Call Recording Transcription
```dart
// Use phone_call with 8kHz for phone audio
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 8000,
  model: 'phone_call',
);
```

### Example 4: Video Subtitle Generator
```dart
// Use video model for video content
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'en-US',
  sampleRateHertz: 16000,
  model: 'video',
);
```

## Language-Specific Models

Some models have language-specific variants. For example:
- `en-US` - English (United States)
- `en-GB` - English (United Kingdom)
- `es-ES` - Spanish (Spain)
- `fr-FR` - French (France)
- `de-DE` - German (Germany)
- `ja-JP` - Japanese (Japan)
- `ko-KR` - Korean (South Korea)
- `zh-CN` - Chinese (Simplified)

### Example with Different Languages:
```dart
// Spanish transcription with latest_long
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'es-ES',
  model: 'latest_long',
);

// Japanese transcription with video model
await FlutterGoogleStt.initializeWithServiceAccountString(
  serviceAccountJsonString: serviceAccountJson,
  languageCode: 'ja-JP',
  model: 'video',
);
```

## Performance Considerations

### Accuracy vs. Latency
| Model | Accuracy | Latency | Best For |
|-------|----------|---------|----------|
| latest_long | ⭐⭐⭐⭐⭐ | Medium | Long content |
| latest_short | ⭐⭐⭐⭐ | Low | Short queries |
| command_and_search | ⭐⭐⭐ | Very Low | Commands |
| phone_call | ⭐⭐⭐⭐ | Medium | Phone audio |
| video | ⭐⭐⭐⭐ | Medium | Video content |

### Cost Considerations
- All models have the same pricing structure
- Choose based on accuracy and use case, not cost
- See [Google Cloud Pricing](https://cloud.google.com/speech-to-text/pricing) for details

## Testing Different Models

You can easily switch models to find the best fit:

```dart
class _MyAppState extends State<MyApp> {
  String _selectedModel = 'latest_long';
  
  Future<void> _initializeWithModel(String model) async {
    final serviceAccountJson = await rootBundle.loadString(
      'assets/service_account.json',
    );
    
    await FlutterGoogleStt.initializeWithServiceAccountString(
      serviceAccountJsonString: serviceAccountJson,
      languageCode: 'en-US',
      model: model,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<String>(
          value: _selectedModel,
          items: [
            DropdownMenuItem(value: 'latest_long', child: Text('Latest Long')),
            DropdownMenuItem(value: 'latest_short', child: Text('Latest Short')),
            DropdownMenuItem(value: 'command_and_search', child: Text('Command & Search')),
            DropdownMenuItem(value: 'phone_call', child: Text('Phone Call')),
            DropdownMenuItem(value: 'video', child: Text('Video')),
          ],
          onChanged: (value) async {
            setState(() => _selectedModel = value!);
            await _initializeWithModel(value!);
          },
        ),
      ],
    );
  }
}
```

## Additional Resources

- [Google Cloud Speech-to-Text Models Documentation](https://cloud.google.com/speech-to-text/docs/speech-to-text-requests#select-model)
- [Language Support](https://cloud.google.com/speech-to-text/docs/languages)
- [Best Practices](https://cloud.google.com/speech-to-text/docs/best-practices)

## FAQ

**Q: What happens if I don't specify a model?**  
A: Google will use the default model, which provides balanced performance for general use cases.

**Q: Can I change the model while the app is running?**  
A: Yes, you need to stop listening, re-initialize with the new model, and start listening again.

**Q: Which model should I use for real-time dictation?**  
A: Use `latest_long` for the best accuracy in dictation scenarios.

**Q: Do all models support all languages?**  
A: Most models support major languages, but check [Google's language support documentation](https://cloud.google.com/speech-to-text/docs/languages) for specific model-language combinations.

**Q: Will using a specific model increase costs?**  
A: No, all models have the same pricing. Choose based on your use case and accuracy needs.
