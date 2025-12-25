//
//  VoiceManager.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//
import Foundation
import Starscream
import AVFoundation
import Combine

/// Enhanced Voice Manager with real audio playback and tool handling
class VoiceManager: ObservableObject {
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var isSpeaking = false
    @Published var isConnected = false
    @Published var transcript = ""
    @Published var grokResponse = ""
    @Published var suggestedSpot: CalmSpot?
    @Published var currentWeather: ParsedWeather?
    @Published var error: String?
    @Published var connectionStatus = "Disconnected"
    
    private var socket: Starscream.WebSocket?
    private var audioEngine: AVAudioEngine?
    private var cancellables = Set<AnyCancellable>()
    private var onResponseCallback: ((String) -> Void)?
    var onToolCallCallback: ((String, [String: Any]) -> Void)?
    var onSpotSuggested: ((CalmSpot) -> Void)?
    
    // Audio player service for voice responses
    private let audioPlayer = AudioPlayerService.shared
    
    // Accumulated audio buffer for streaming response
    private var audioBuffer = Data()
    private var isReceivingAudio = false
    private var hasReceivedAudioForCurrentResponse = false
    
    private let apiKey = "xai-I1UBCLc2IYDCMaJSY8V7MJ8nKsjx9gXNQj1ajO3yPGwvyQpPNMPxjPOjGeJCYVNMUJNiLIkzjhslHPgJ"
    
    // Available Grok voices (lowercase): "alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer", "verse"
    // For Ani voice, we'll use "sage" which is calm and soothing
    private let selectedVoice = "sage"
    
    // System prompt for Grok
    private var systemPrompt: String {
        """
        You are Grok Tube, a calm, witty AI companion helping stressed Londoners find peace and tranquility.
        
        PERSONALITY:
        - Warm, empathetic, and genuinely caring about mental wellbeing
        - British wit and subtle humor (think Stephen Fry meets a zen garden)
        - Knowledgeable about London's hidden peaceful spots
        - Encouraging but never preachy
        
        CAPABILITIES:
        1. Suggest calm spots from London's best hidden gardens and parks
        2. Check real-time weather to recommend the perfect time to visit
        3. Guide users through breathing exercises (4-4-4-2 box breathing)
        4. Offer calming affirmations and gentle encouragement
        5. Tell soothing facts about nature and London history
        
        AVAILABLE CALM SPOTS:
        \(CalmSpot.allSpots.map { "- \($0.name): \($0.description)" }.joined(separator: "\n"))
        
        RESPONSE STYLE:
        - Keep responses concise (2-3 sentences for voice)
        - Use calming language and pacing
        - Always offer a next step (visit a park, try breathing, or just chat)
        - End with a gentle question to keep the conversation flowing
        
        When suggesting a park, mention:
        - The name and what makes it special
        - Current crowd level if known
        - Nearest tube station and walking time
        - Best time to visit based on weather
        """
    }
    
    init() {
        // Audio engine initialized on demand
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Session Management
    
    func startSession(onResponse: @escaping (String) -> Void, onToolCall: ((String, [String: Any]) -> Void)? = nil) {
        self.onResponseCallback = onResponse
        self.onToolCallCallback = onToolCall
        
        DispatchQueue.main.async {
            self.connectionStatus = "Connecting..."
            self.error = nil
        }
        
        // xAI Grok Realtime API endpoint
        guard let url = URL(string: "wss://api.x.ai/v1/realtime?model=grok-2-public") else {
            DispatchQueue.main.async {
                self.error = "Invalid API URL"
                self.connectionStatus = "Error"
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.timeoutInterval = 30
        
        socket = Starscream.WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    func stopSession() {
        stopAudioCapture()
        socket?.disconnect()
        socket = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isProcessing = false
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
    }
    
    // MARK: - Audio Configuration
    
    private func configureAudioSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP
            ])
            try session.setPreferredSampleRate(24000)
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured")
            return true
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            return false
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            DispatchQueue.main.async {
                self.error = "Microphone access denied. Please enable in Settings."
            }
            completion(false)
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.error = "Microphone access is required for voice chat."
                    }
                }
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func startAudioCapture() {
        // First request microphone permission
        requestMicrophonePermission { [weak self] granted in
            guard let self = self, granted else {
                DispatchQueue.main.async {
                    self?.error = "Microphone permission required for voice input. Use text input instead."
                }
                return
            }
            
            // Configure audio session
            guard self.configureAudioSession() else {
                DispatchQueue.main.async {
                    self.error = "Audio setup failed. Try using text input instead."
                }
                return
            }
            
            self.audioEngine = AVAudioEngine()
            guard let audioEngine = self.audioEngine else { return }
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            print("📍 Input format: \(inputFormat)")
            
            // Validate format before using
            guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
                print("❌ Invalid input format: sample rate or channel count is 0")
                DispatchQueue.main.async {
                    self.error = "Microphone not available. Use text input instead."
                }
                return
            }
            
            // Install tap to capture audio
            inputNode.installTap(onBus: 0, bufferSize: 2400, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, self.isListening else { return }
                
                // Convert to 24kHz mono PCM16
                if let pcmData = self.convertBufferToPCM16(buffer, sourceFormat: inputFormat) {
                    self.sendAudioData(pcmData)
                }
            }
            
            do {
                audioEngine.prepare()
                try audioEngine.start()
                print("✅ Audio capture started")
                
                DispatchQueue.main.async {
                    self.isListening = true
                }
            } catch {
                print("❌ Audio engine failed to start: \(error)")
                DispatchQueue.main.async {
                    self.error = "Microphone failed. Use text input instead."
                }
            }
        }
    }
    
    private func stopAudioCapture() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    // MARK: - Audio Conversion
    
    private func convertBufferToPCM16(_ buffer: AVAudioPCMBuffer, sourceFormat: AVAudioFormat) -> Data? {
        guard let floatData = buffer.floatChannelData else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(sourceFormat.channelCount)
        let sourceSampleRate = sourceFormat.sampleRate
        let targetSampleRate = 24000.0
        
        // Downsample ratio
        let ratio = sourceSampleRate / targetSampleRate
        let outputFrameCount = Int(Double(frameCount) / ratio)
        
        var pcmData = Data(capacity: outputFrameCount * 2)
        
        for i in 0..<outputFrameCount {
            let sourceIndex = Int(Double(i) * ratio)
            guard sourceIndex < frameCount else { break }
            
            // Mix channels to mono
            var sample: Float = 0
            for ch in 0..<channelCount {
                sample += floatData[ch][sourceIndex]
            }
            sample /= Float(channelCount)
            
            // Clamp and convert to Int16
            let clamped = max(-1.0, min(1.0, sample))
            var int16Sample = Int16(clamped * 32767.0)
            withUnsafeBytes(of: &int16Sample) { pcmData.append(contentsOf: $0) }
        }
        
        return pcmData
    }
    
    // MARK: - Send Audio Data
    
    private func sendAudioData(_ data: Data) {
        let base64Audio = data.base64EncodedString()
        
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
        }
    }
    
    // MARK: - Send Text Message
    
    func sendTextMessage(_ text: String) {
        guard isConnected else {
            DispatchQueue.main.async {
                self.error = "Not connected. Please try again."
            }
            return
        }
        
        DispatchQueue.main.async {
            self.transcript = text
            self.grokResponse = ""
            self.isProcessing = true
            self.hasReceivedAudioForCurrentResponse = false
        }
        
        // Create conversation item with user message
        let userMessage: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": text
                    ]
                ]
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: userMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
            print("📤 Sent user message: \(text)")
        }
        
        // Request response with audio modality
        let responseRequest: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text", "audio"]
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: responseRequest),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
            print("📤 Requested response with audio")
        }
    }
    
    // MARK: - Send Session Configuration
    
    private func sendSessionConfig() {
        let tools: [[String: Any]] = [
            [
                "type": "function",
                "name": "get_weather",
                "description": "Get current weather conditions in London to recommend best time for outdoor activities",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ]
            ],
            [
                "type": "function",
                "name": "suggest_calm_spot",
                "description": "Suggest a calm spot in London based on user preferences. Call this when user asks about parks, green spaces, peaceful places, or wants somewhere quiet to go.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "preference": [
                            "type": "string",
                            "enum": ["nature", "historic", "indoor", "family", "quiet", "any"],
                            "description": "User's preference for type of calm spot"
                        ]
                    ],
                    "required": [] as [String]
                ]
            ],
            [
                "type": "function",
                "name": "start_breathing_exercise",
                "description": "Start a guided breathing exercise for stress relief. Call this when user mentions stress, anxiety, needing to calm down, or wants a breathing exercise.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "duration": [
                            "type": "integer",
                            "description": "Number of breathing cycles (1-10)"
                        ]
                    ],
                    "required": [] as [String]
                ]
            ]
        ]
        
        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": systemPrompt,
                "voice": selectedVoice,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ],
                "tools": tools,
                "tool_choice": "auto"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: config),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending session config with voice: \(selectedVoice)")
            print("📤 Config: \(jsonString.prefix(500))...")
            socket?.write(string: jsonString)
        }
    }
    
    // MARK: - Tool Handling
    
    func handleToolCall(name: String, arguments: [String: Any], callId: String) {
        print("🔧 Handling tool call: \(name) with args: \(arguments)")
        
        Task {
            var result: String = ""
            
            switch name {
            case "get_weather":
                result = await handleWeatherTool()
                
            case "suggest_calm_spot":
                let preference = arguments["preference"] as? String ?? "any"
                result = handleSuggestSpot(preference: preference)
                
            case "start_breathing_exercise":
                let cycles = arguments["duration"] as? Int ?? 4
                result = "Starting \(cycles)-cycle breathing exercise. Take a deep breath and follow along. Inhale through your nose for 4 seconds, hold for 4 seconds, then exhale slowly for 6 seconds."
                DispatchQueue.main.async {
                    self.onToolCallCallback?("start_breathing_exercise", ["cycles": cycles])
                }
                
            default:
                print("⚠️ Unknown tool: \(name)")
                result = "Tool not recognized"
            }
            
            sendToolResult(callId: callId, result: result)
        }
    }
    
    private func handleWeatherTool() async -> String {
        do {
            let weather = try await WeatherService.shared.fetchLondonWeather()
            DispatchQueue.main.async {
                self.currentWeather = weather
            }
            return """
            Current London weather: \(weather.condition.description), \(weather.temperatureString).
            Feels like \(weather.feelsLikeString). Humidity: \(weather.humidity)%.
            \(weather.recommendation)
            """
        } catch {
            return "Weather data temporarily unavailable. Assume typical London weather."
        }
    }
    
    private func handleSuggestSpot(preference: String) -> String {
        let spots = CalmSpot.allSpots
        
        let filtered: [CalmSpot]
        switch preference.lowercased() {
        case "nature", "wildlife":
            filtered = spots.filter { $0.tags.contains("Nature") || $0.tags.contains("Wildlife") }
        case "historic", "history":
            filtered = spots.filter { $0.tags.contains("Historic") }
        case "indoor":
            filtered = spots.filter { $0.tags.contains("Indoor") }
        case "family":
            filtered = spots.filter { $0.tags.contains("Family") }
        case "quiet":
            filtered = spots.filter { $0.crowdLevel == .quiet }
        default:
            filtered = spots
        }
        
        guard let spot = filtered.randomElement() ?? spots.randomElement() else {
            return "I recommend Kyoto Garden in Holland Park - it's always peaceful."
        }
        
        DispatchQueue.main.async {
            self.suggestedSpot = spot
            // Call the callback to notify ContentView
            self.onSpotSuggested?(spot)
            print("✅ Spot suggested: \(spot.name)")
        }
        
        return """
        I suggest \(spot.name) - \(spot.description)
        It's currently \(spot.crowdLevel.rawValue.lowercased()).
        Nearest tube: \(spot.nearestTube.name) (\(spot.nearestTube.walkingMinutes) min walk).
        Open: \(spot.openingHours)
        """
    }
    
    private func sendToolResult(callId: String, result: String) {
        let response: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callId,
                "output": result
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: response),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
            print("📤 Sent tool result for call: \(callId)")
        }
        
        // Trigger response generation with audio modality
        let generate: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text", "audio"]
            ]
        ]
        if let genData = try? JSONSerialization.data(withJSONObject: generate),
           let genString = String(data: genData, encoding: .utf8) {
            socket?.write(string: genString)
            print("📤 Requested response with audio after tool result")
        }
    }
    
    // MARK: - Play Audio Response
    
    func playAudioResponse(_ base64Audio: String) {
        guard let audioData = Data(base64Encoded: base64Audio) else {
            print("❌ Failed to decode base64 audio data (length: \(base64Audio.count))")
            return
        }
        
        print("🔊 Playing audio chunk: \(audioData.count) bytes")
        
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        
        // Configure audio session for playback
        audioPlayer.configureAudioSession(forPlayback: true)
        
        // Stream audio through AudioPlayerService
        audioPlayer.playPCMInt16Data(audioData, sampleRate: 24000)
    }
    
    func finishAudioPlayback() {
        // Estimate playback completion based on buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.isReceivingAudio {
                self.isSpeaking = false
            }
        }
    }
    
    // MARK: - Text-to-Speech Fallback
    
    func speakText(_ text: String) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.grokResponse = text
        }
        
        audioPlayer.speak(text, rate: 0.48, pitch: 1.0)
        
        // Estimate speech duration
        let wordCount = text.split(separator: " ").count
        let estimatedDuration = Double(wordCount) / 2.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
            self.isSpeaking = false
        }
    }
    
    func stopSpeaking() {
        audioPlayer.stop()
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    // MARK: - Toggle Listening
    
    func toggleListening() {
        if isListening {
            // Commit the audio buffer to trigger processing
            let commitMessage: [String: Any] = ["type": "input_audio_buffer.commit"]
            if let jsonData = try? JSONSerialization.data(withJSONObject: commitMessage),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                socket?.write(string: jsonString)
            }
            stopAudioCapture()
        } else {
            startAudioCapture()
        }
    }
}

// MARK: - WebSocket Delegate

extension VoiceManager: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("✅ WebSocket connected: \(headers)")
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionStatus = "Connected"
            }
            sendSessionConfig()
            
        case .text(let text):
            handleTextMessage(text)
            
        case .binary(let data):
            // Raw binary audio (less common with Grok API)
            print("📦 Received binary data: \(data.count) bytes")
            
        case .error(let error):
            print("❌ WebSocket error: \(String(describing: error))")
            DispatchQueue.main.async {
                self.error = "Connection error: \(error?.localizedDescription ?? "Unknown")"
                self.isConnected = false
                self.isListening = false
                self.connectionStatus = "Error"
            }
            
        case .disconnected(let reason, let code):
            print("⚠️ WebSocket disconnected: \(reason) (code: \(code))")
            DispatchQueue.main.async {
                self.isConnected = false
                self.isListening = false
                self.connectionStatus = "Disconnected"
            }
            
        case .cancelled:
            print("⚠️ WebSocket cancelled")
            DispatchQueue.main.async {
                self.isConnected = false
                self.isListening = false
                self.connectionStatus = "Cancelled"
            }
            
        case .viabilityChanged(let viable):
            print("📡 Connection viability: \(viable)")
            
        case .reconnectSuggested(let suggested):
            print("🔄 Reconnect suggested: \(suggested)")
            if suggested {
                // Auto-reconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.socket?.connect()
                }
            }
            
        case .peerClosed:
            print("⚠️ Peer closed connection")
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionStatus = "Peer Closed"
            }
            
        case .pong(_):
            break
        case .ping(_):
            break
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { 
            print("⚠️ Failed to parse WebSocket message")
            return 
        }
        
        // Debug log for all events except frequent audio deltas
        if type == "response.audio.delta" {
            // Log periodically to avoid spam
            if Int.random(in: 0...50) == 0 {
                print("🔊 Audio delta received (sampling)")
            }
        } else {
            print("📨 Received event: \(type)")
        }
        
        switch type {
        case "session.created":
            print("✅ Session created successfully")
            DispatchQueue.main.async {
                self.connectionStatus = "Session Ready"
            }
            
        case "session.updated":
            print("✅ Session updated - voice: \(selectedVoice)")
            DispatchQueue.main.async {
                self.connectionStatus = "Ready (\(self.selectedVoice))"
            }
            
        case "response.audio.delta":
            // Streaming audio chunk
            if let delta = json["delta"] as? String {
                isReceivingAudio = true
                hasReceivedAudioForCurrentResponse = true
                playAudioResponse(delta)
            } else {
                print("⚠️ Audio delta missing 'delta' field")
            }
            
        case "response.audio.done":
            print("✅ Audio response complete")
            isReceivingAudio = false
            finishAudioPlayback()
            
        case "response.audio_transcript.delta":
            // Live transcript of Grok's response
            if let delta = json["delta"] as? String {
                DispatchQueue.main.async {
                    self.grokResponse += delta
                    self.onResponseCallback?(self.grokResponse)
                }
            }
            
        case "response.audio_transcript.done":
            // Full transcript complete
            if let transcript = json["transcript"] as? String {
                DispatchQueue.main.async {
                    self.grokResponse = transcript
                    self.onResponseCallback?(transcript)
                }
            }
            
        case "response.text.delta":
            // Text-only response delta
            if let delta = json["delta"] as? String {
                DispatchQueue.main.async {
                    self.grokResponse += delta
                    self.onResponseCallback?(self.grokResponse)
                }
            }
            
        case "response.text.done":
            if let text = json["text"] as? String {
                DispatchQueue.main.async {
                    self.grokResponse = text
                    self.onResponseCallback?(text)
                }
            }
            
        case "response.done":
            print("✅ Response complete")
            DispatchQueue.main.async {
                self.isProcessing = false
                
                // If we got text but no audio, use text-to-speech as fallback
                if !self.hasReceivedAudioForCurrentResponse && !self.grokResponse.isEmpty {
                    print("🔊 No audio received, falling back to TTS for: \(self.grokResponse.prefix(50))...")
                    self.speakText(self.grokResponse)
                }
                
                // Reset for next response
                self.hasReceivedAudioForCurrentResponse = false
            }
            
        case "input_audio_buffer.speech_started":
            print("🎤 Speech detected")
            DispatchQueue.main.async {
                self.isProcessing = true
                self.grokResponse = ""
                self.hasReceivedAudioForCurrentResponse = false
            }
            
        case "input_audio_buffer.speech_stopped":
            print("🎤 Speech ended")
            
        case "input_audio_buffer.committed":
            print("✅ Audio buffer committed")
            
        case "conversation.item.input_audio_transcription.completed":
            // User's speech transcribed
            if let transcript = json["transcript"] as? String {
                print("📝 User said: \(transcript)")
                DispatchQueue.main.async {
                    self.transcript = transcript
                }
            }
            
        case "response.function_call_arguments.done":
            // Tool call from Grok
            if let name = json["name"] as? String,
               let callId = json["call_id"] as? String {
                let argsString = json["arguments"] as? String ?? "{}"
                let args: [String: Any]
                if let argsData = argsString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                    args = parsed
                } else {
                    args = [:]
                }
                print("🔧 Tool call: \(name)")
                handleToolCall(name: name, arguments: args, callId: callId)
            }
            
        case "error":
            if let errorInfo = json["error"] as? [String: Any],
               let message = errorInfo["message"] as? String {
                print("❌ API Error: \(message)")
                DispatchQueue.main.async {
                    self.error = message
                    self.isProcessing = false
                }
            }
            
        case "rate_limits.updated":
            // Rate limit info - can be logged if needed
            break
            
        default:
            print("📨 Unhandled event: \(type)")
        }
    }
}

