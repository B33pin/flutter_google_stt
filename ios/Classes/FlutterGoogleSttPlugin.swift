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
    
    // Audio configuration
    private var languageCode: String = "en-US"
    private var sampleRateHertz: Int = 16000
    
    // Audio processing
    private var audioQueue: DispatchQueue?
    
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
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments are required", details: nil))
            return
        }
        
        languageCode = args["languageCode"] as? String ?? "en-US"
        sampleRateHertz = args["sampleRateHertz"] as? Int ?? 16000
        
        audioQueue = DispatchQueue(label: "com.flutter_google_stt.audio", qos: .userInitiated)
        result(true)
    }
    
    private func handleStartListening(result: @escaping FlutterResult) {
        print("FlutterGoogleSttPlugin: handleStartListening called")
        guard hasMicrophonePermission() else {
            print("FlutterGoogleSttPlugin: Microphone permission denied")
            result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission is required", details: nil))
            return
        }
        
        if isListening {
            print("FlutterGoogleSttPlugin: Already listening")
            result(true)
            return
        }
        
        do {
            print("FlutterGoogleSttPlugin: Starting audio recording")
            try startAudioRecording()
            print("FlutterGoogleSttPlugin: Audio recording started successfully")
            result(true)
        } catch {
            print("FlutterGoogleSttPlugin: Failed to start listening: \(error.localizedDescription)")
            result(FlutterError(code: "START_LISTENING_ERROR", message: "Failed to start listening: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func handleStopListening(result: @escaping FlutterResult) {
        stopAudioRecording()
        result(true)
    }
    
    private func startAudioRecording() throws {
        print("FlutterGoogleSttPlugin: startAudioRecording called")
        if isListening { 
            print("FlutterGoogleSttPlugin: Already listening, returning")
            return 
        }
        
        print("FlutterGoogleSttPlugin: Configuring audio session")
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("FlutterGoogleSttPlugin: Initializing audio engine")
        // Initialize audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        // Get the input node's native format
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            print("FlutterGoogleSttPlugin: Failed to set up audio engine")
            throw NSError(domain: "AudioSetupError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to set up audio engine"])
        }
        
        // Use the input node's native format for recording
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        audioFormat = nativeFormat
        print("FlutterGoogleSttPlugin: Audio format - sampleRate: \(nativeFormat.sampleRate), channels: \(nativeFormat.channelCount)")
        
        // Install tap on input node to capture audio for streaming
        print("FlutterGoogleSttPlugin: Installing audio tap")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer: buffer)
        }
        
        // Start audio engine
        print("FlutterGoogleSttPlugin: Starting audio engine")
        try audioEngine.start()
        isListening = true
        print("FlutterGoogleSttPlugin: Audio recording started successfully")
    }
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { 
            print("FlutterGoogleSttPlugin: No channel data in buffer")
            return 
        }
        
        let frameCount = Int(buffer.frameLength)
        print("FlutterGoogleSttPlugin: Processing audio buffer with \(frameCount) frames")
        
        // Convert to 16-bit PCM
        var audioData = Data()
        for i in 0..<frameCount {
            var sample = Int16(channelData[i] * 32767.0)
            audioData.append(Data(bytes: &sample, count: 2))
        }
        
        print("FlutterGoogleSttPlugin: Converted to \(audioData.count) bytes of PCM data")
        
        // Send audio data to Dart side for streaming
        audioQueue?.async { [weak self] in
            DispatchQueue.main.async {
                print("FlutterGoogleSttPlugin: Sending audio data to Dart via method channel")
                self?.channel?.invokeMethod("onAudioData", arguments: [UInt8](audioData))
            }
        }
    }

    private func stopAudioRecording() {
        isListening = false
        
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
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
