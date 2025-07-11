import Flutter
import UIKit
import AVFoundation
import Foundation

public class FlutterGoogleSttPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var isListening = false
    
    // Google Speech variables
    private var accessToken: String?
    private var languageCode: String = "en-US"
    private var sampleRateHertz: Int = 16000
    
    // Audio buffer for streaming
    private var audioQueue: DispatchQueue?
    private var streamingTimer: Timer?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_google_stt", binaryMessenger: registrar.messenger())
        let instance = FlutterGoogleSttPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "startListening":
            handleStartListening(result: result)
        case "stopListening":
            handleStopListening(result: result)
        case "isListening":
            result(isListening)
        case "hasMicrophonePermission":
            result(hasMicrophonePermission())
        case "requestMicrophonePermission":
            handleRequestMicrophonePermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let token = args["accessToken"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Access token is required", details: nil))
            return
        }
        
        accessToken = token
        languageCode = args["languageCode"] as? String ?? "en-US"
        sampleRateHertz = args["sampleRateHertz"] as? Int ?? 16000
        
        audioQueue = DispatchQueue(label: "com.flutter_google_stt.audio", qos: .userInitiated)
        result(true)
    }
    
    private func handleStartListening(result: @escaping FlutterResult) {
        guard hasMicrophonePermission() else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission is required", details: nil))
            return
        }
        
        if isListening {
            result(true)
            return
        }
        
        do {
            try startAudioRecording()
            result(true)
        } catch {
            result(FlutterError(code: "START_LISTENING_ERROR", message: "Failed to start listening: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func handleStopListening(result: @escaping FlutterResult) {
        stopAudioRecording()
        result(true)
    }
    
    private func startAudioRecording() throws {
        if isListening { return }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Initialize audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        // Get the input node's native format
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            throw NSError(domain: "AudioSetupError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to set up audio engine"])
        }
        
        // Use the input node's native format for recording
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        audioFormat = nativeFormat
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer: buffer)
        }
        
        // Start audio engine
        try audioEngine.start()
        isListening = true
        
        // Start a timer for periodic non-streaming recognition (as a fallback)
        startPeriodicRecognition()
    }
    
    private func stopAudioRecording() {
        isListening = false
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        streamingTimer?.invalidate()
        streamingTimer = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
    }
    
    private var audioBuffer = Data()
    private let maxBufferSize = 32000 // Maximum buffer size in bytes (~1 second of 16kHz mono 16-bit audio)
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        // Convert the buffer to the required format for Google Speech API
        guard let audioFormat = audioFormat else { 
            print("Audio format not available")
            return 
        }
        
        // Create target format (16kHz, mono, 16-bit PCM)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, 
                                               sampleRate: Double(sampleRateHertz), 
                                               channels: 1, 
                                               interleaved: false) else { 
            print("Failed to create target format")
            return 
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: audioFormat, to: targetFormat) else { 
            print("Failed to create audio converter")
            return 
        }
        
        // Calculate output buffer size
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * (targetFormat.sampleRate / audioFormat.sampleRate))
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else { 
            print("Failed to create converted buffer")
            return 
        }
        
        // Convert the audio
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Audio conversion error: \(error)")
            return
        }
        
        if status != .haveData {
            print("Audio conversion status: \(status.rawValue)")
            return
        }
        
        // Extract converted audio data
        guard let channelData = convertedBuffer.int16ChannelData?[0] else { 
            print("Failed to get channel data")
            return 
        }
        
        let bufferSize = Int(convertedBuffer.frameLength)
        let audioData = Data(bytes: channelData, count: bufferSize * 2) // 2 bytes per sample for Int16
        
        audioQueue?.async { [weak self] in
            guard let self = self else { return }
            self.audioBuffer.append(audioData)
            
            // If buffer is getting too large, send it for recognition immediately
            if self.audioBuffer.count > self.maxBufferSize {
                self.sendAudioForRecognition()
            }
        }
    }
    
    private func startPeriodicRecognition() {
        streamingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendAudioForRecognition()
        }
    }
    
    private func sendAudioForRecognition() {
        guard !audioBuffer.isEmpty,
              let accessToken = accessToken else { 
            return 
        }
        
        let currentBuffer = audioBuffer
        audioBuffer = Data()
        
        // Skip if buffer is too small (less than 0.1 seconds of audio)
        let minBufferSize = 3200 // ~0.1 seconds of 16kHz mono 16-bit audio
        if currentBuffer.count < minBufferSize {
            return
        }
        
        print("Sending audio buffer of size: \(currentBuffer.count) bytes")
        
        // Create recognition request
        let recognitionConfig: [String: Any] = [
            "encoding": "LINEAR16",
            "sampleRateHertz": sampleRateHertz,
            "languageCode": languageCode
        ]
        
        let audio: [String: Any] = [
            "content": currentBuffer.base64EncodedString()
        ]
        
        let requestBody: [String: Any] = [
            "config": recognitionConfig,
            "audio": audio
        ]
        
        // Send request to Google Speech API
        sendSpeechRequest(requestBody: requestBody, accessToken: accessToken)
    }
    
    private func sendSpeechRequest(requestBody: [String: Any], accessToken: String) {
        guard let url = URL(string: "https://speech.googleapis.com/v1/speech:recognize") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error serializing request: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.channel?.invokeMethod("onTranscript", arguments: [
                        "transcript": "Network Error: \(error.localizedDescription)",
                        "isFinal": true
                    ])
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                return
            }
            
            print("HTTP Status Code: \(httpResponse.statusCode)")
            
            guard let data = data else { 
                print("No response data")
                return 
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response JSON: \(json)")
                    
                    // Check for API errors
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        DispatchQueue.main.async {
                            self?.channel?.invokeMethod("onTranscript", arguments: [
                                "transcript": "API Error: \(message)",
                                "isFinal": true
                            ])
                        }
                        return
                    }
                    
                    // Extract transcription results
                    if let results = json["results"] as? [[String: Any]],
                       let firstResult = results.first,
                       let alternatives = firstResult["alternatives"] as? [[String: Any]],
                       let firstAlternative = alternatives.first,
                       let transcript = firstAlternative["transcript"] as? String {
                        
                        DispatchQueue.main.async {
                            self?.channel?.invokeMethod("onTranscript", arguments: [
                                "transcript": transcript,
                                "isFinal": true
                            ])
                        }
                    } else {
                        print("No transcription results found in response")
                    }
                } else {
                    print("Failed to parse JSON response")
                }
            } catch {
                print("Error parsing response: \(error)")
                DispatchQueue.main.async {
                    self?.channel?.invokeMethod("onTranscript", arguments: [
                        "transcript": "Parse Error: \(error.localizedDescription)",
                        "isFinal": true
                    ])
                }
            }
        }.resume()
    }
    
    private func hasMicrophonePermission() -> Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    private func handleRequestMicrophonePermission(result: @escaping FlutterResult) {
        if hasMicrophonePermission() {
            result(true)
            return
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }
    
    deinit {
        stopAudioRecording()
    }
}
