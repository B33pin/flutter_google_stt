package com.guptan404.flutter_google_stt

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import com.google.gson.Gson
import com.google.gson.JsonObject
import android.util.Base64
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.io.ByteArrayOutputStream

/** FlutterGoogleSttPlugin */
class FlutterGoogleSttPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  
  // Audio recording variables
  private var audioRecord: AudioRecord? = null
  private var isRecording = false
  private var recordingJob: Job? = null
  private var audioBuffer = ByteArrayOutputStream()
  
  // Google Speech variables
  private val httpClient = OkHttpClient.Builder()
    .connectTimeout(30, TimeUnit.SECONDS)
    .writeTimeout(30, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .build()
  private val gson = Gson()
  private var accessToken: String? = null
  private var languageCode: String = "en-US"
  private var sampleRateHertz: Int = 16000
  
  // Audio recording parameters
  private val channelConfig = AudioFormat.CHANNEL_IN_MONO
  private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
  private val bufferSize = AudioRecord.getMinBufferSize(16000, channelConfig, audioFormat)
  
  // Permission request code
  private val MICROPHONE_PERMISSION_REQUEST_CODE = 1001
  private var pendingResult: Result? = null
  
  companion object {
    private const val SPEECH_API_URL = "https://speech.googleapis.com/v1/speech:recognize"
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_google_stt")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> handleInitialize(call, result)
      "startListening" -> handleStartListening(result)
      "stopListening" -> handleStopListening(result)
      "isListening" -> result.success(isRecording)
      "hasMicrophonePermission" -> result.success(hasMicrophonePermission())
      "requestMicrophonePermission" -> handleRequestMicrophonePermission(result)
      else -> result.notImplemented()
    }
  }

  private fun handleInitialize(call: MethodCall, result: Result) {
    try {
      accessToken = call.argument<String>("accessToken")
      languageCode = call.argument<String>("languageCode") ?: "en-US"
      sampleRateHertz = call.argument<Int>("sampleRateHertz") ?: 16000
      
      if (accessToken.isNullOrEmpty()) {
        result.error("INVALID_TOKEN", "Access token is required", null)
        return
      }
      
      result.success(true)
    } catch (e: Exception) {
      result.error("INITIALIZATION_ERROR", "Failed to initialize: ${e.message}", null)
    }
  }

  private fun handleStartListening(result: Result) {
    if (!hasMicrophonePermission()) {
      result.error("PERMISSION_DENIED", "Microphone permission is required", null)
      return
    }
    
    if (isRecording) {
      result.error("ALREADY_LISTENING", "Already listening", null)
      return
    }
    
    try {
      startAudioRecording()
      result.success(true)
    } catch (e: Exception) {
      result.error("START_ERROR", "Failed to start listening: ${e.message}", null)
    }
  }

  private fun handleStopListening(result: Result) {
    try {
      stopAudioRecording()
      result.success(true)
    } catch (e: Exception) {
      result.error("STOP_ERROR", "Failed to stop listening: ${e.message}", null)
    }
  }

  private fun startAudioRecording() {
    try {
      audioRecord = AudioRecord(
        MediaRecorder.AudioSource.MIC,
        sampleRateHertz,
        channelConfig,
        audioFormat,
        bufferSize * 2
      )
      
      if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
        throw Exception("AudioRecord initialization failed")
      }
      
      isRecording = true
      audioBuffer.reset()
      audioRecord?.startRecording()
      
      // Start recording in a coroutine
      recordingJob = CoroutineScope(Dispatchers.IO).launch {
        recordAudio()
      }
    } catch (e: Exception) {
      throw e
    }
  }

  private suspend fun recordAudio() {
    val buffer = ByteArray(bufferSize)
    var totalBytesRecorded = 0
    val maxRecordingBytes = sampleRateHertz * 2 * 10 // 10 seconds max
    
    try {
      while (isRecording && audioRecord != null) {
        val bytesRead = audioRecord!!.read(buffer, 0, buffer.size)
        if (bytesRead > 0) {
          audioBuffer.write(buffer, 0, bytesRead)
          totalBytesRecorded += bytesRead
          
          // Send to speech recognition every 3 seconds or when we hit max recording
          if (totalBytesRecorded >= sampleRateHertz * 2 * 3 || totalBytesRecorded >= maxRecordingBytes) {
            recognizeSpeech()
            audioBuffer.reset()
            totalBytesRecorded = 0
            
            // If we hit max recording time, stop
            if (totalBytesRecorded >= maxRecordingBytes) {
              break
            }
          }
        }
        delay(10) // Small delay to prevent overwhelming
      }
      
      // Process any remaining audio
      if (audioBuffer.size() > 0) {
        recognizeSpeech()
      }
    } catch (e: Exception) {
      withContext(Dispatchers.Main) {
        channel.invokeMethod("onError", "Recording error: ${e.message}")
      }
    }
  }

  private suspend fun recognizeSpeech() {
    try {
      val audioData = audioBuffer.toByteArray()
      if (audioData.isEmpty()) return
      
      val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)
      
      // Create request JSON for Google Speech API
      val config = JsonObject().apply {
        addProperty("encoding", "LINEAR16")
        addProperty("sampleRateHertz", sampleRateHertz)
        addProperty("languageCode", languageCode)
        addProperty("enableAutomaticPunctuation", true)
      }
      
      val audio = JsonObject().apply {
        addProperty("content", base64Audio)
      }
      
      val requestJson = JsonObject().apply {
        add("config", config)
        add("audio", audio)
      }
      
      val requestBody = gson.toJson(requestJson).toRequestBody("application/json".toMediaType())
      
      val request = Request.Builder()
        .url(SPEECH_API_URL)
        .post(requestBody)
        .addHeader("Authorization", "Bearer $accessToken")
        .addHeader("Content-Type", "application/json")
        .build()
      
      httpClient.newCall(request).execute().use { response ->
        if (response.isSuccessful) {
          val responseBody = response.body?.string()
          
          if (responseBody != null) {
            parseAndSendResult(responseBody)
          }
        } else {
          val errorBody = response.body?.string()
          withContext(Dispatchers.Main) {
            channel.invokeMethod("onError", "Recognition failed: ${response.code}")
          }
        }
      }
    } catch (e: Exception) {
      withContext(Dispatchers.Main) {
        channel.invokeMethod("onError", "Recognition error: ${e.message}")
      }
    }
  }

  private suspend fun parseAndSendResult(responseJson: String) {
    try {
      val jsonResponse = gson.fromJson(responseJson, JsonObject::class.java)
      val results = jsonResponse.getAsJsonArray("results")
      
      if (results != null && results.size() > 0) {
        val result = results[0].asJsonObject
        val alternatives = result.getAsJsonArray("alternatives")
        
        if (alternatives != null && alternatives.size() > 0) {
          val alternative = alternatives[0].asJsonObject
          val transcript = alternative.get("transcript")?.asString ?: ""
          
          withContext(Dispatchers.Main) {
            channel.invokeMethod("onTranscript", mapOf(
              "transcript" to transcript,
              "isFinal" to true
            ))
          }
        }
      }
    } catch (e: Exception) {
      withContext(Dispatchers.Main) {
        channel.invokeMethod("onError", "Parsing error: ${e.message}")
      }
    }
  }

  private fun stopAudioRecording() {
    isRecording = false
    recordingJob?.cancel()
    recordingJob = null
    
    audioRecord?.stop()
    audioRecord?.release()
    audioRecord = null
    
    audioBuffer.reset()
  }

  private fun hasMicrophonePermission(): Boolean {
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.RECORD_AUDIO
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun handleRequestMicrophonePermission(result: Result) {
    if (hasMicrophonePermission()) {
      result.success(true)
      return
    }
    
    if (activity == null) {
      result.error("NO_ACTIVITY", "Activity is required to request permissions", null)
      return
    }
    
    pendingResult = result
    ActivityCompat.requestPermissions(
      activity!!,
      arrayOf(Manifest.permission.RECORD_AUDIO),
      MICROPHONE_PERMISSION_REQUEST_CODE
    )
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == MICROPHONE_PERMISSION_REQUEST_CODE) {
      val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
      pendingResult?.success(granted)
      pendingResult = null
      return true
    }
    return false
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    stopAudioRecording()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}
