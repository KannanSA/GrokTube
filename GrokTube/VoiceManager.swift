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
    @Published var transcript = ""
    @Published var grokResponse = ""
    @Published var suggestedSpot: CalmSpot?
    @Published var currentWeather: ParsedWeather?
    @Published var error: String?
    
    private var socket: Starscream.WebSocket?
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var cancellables = Set<AnyCancellable>()
    private var onResponseCallback: ((String) -> Void)?
    var onToolCallCallback: ((String, [String: Any]) -> Void)?
    
    // Audio player service for voice responses
    private let audioPlayer = AudioPlayerService.shared
    
    private let apiKey = "xai-I1UBCLc2IYDCMaJSY8V7MJ8nKsjx9gXNQj1ajO3yPGwvyQpPNMPxjPOjGeJCYVNMUJNiLIkzjhslHPgJ"
    
    // System prompt for Grok
    private var systemPrompt: String {
        """
        You are Grok Pause London, a calm, witty AI companion helping stressed Londoners find peace and tranquility.
        
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
        setupAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
    }
    
    // MARK: - Session Management
    
    func startSession(onResponse: @escaping (String) -> Void, onToolCall: ((String, [String: Any]) -> Void)? = nil) {
        self.onResponseCallback = onResponse
        self.onToolCallCallback = onToolCall
        
        guard let url = URL(string: "wss://api.x.ai/v1/realtime") else {
            self.error = "Invalid API URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("protocol=voice", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.timeoutInterval = 30
        
        socket = Starscream.WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
        
        configureAudioSession()
        startAudioCapture()
        
        DispatchQueue.main.async {
            self.isListening = true
            self.error = nil
        }
    }
    
    func stopSession() {
        stopAudioCapture()
        socket?.disconnect()
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isProcessing = false
        }
    }
    
    // MARK: - Audio Configuration
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers
            ])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
            self.error = "Audio setup failed"
        }
    }
    
    private func startAudioCapture() {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Convert to format expected by API (24kHz mono)
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, self.isListening else { return }
            
            // Convert buffer to API format
            if let convertedData = self.convertAndEncodeBuffer(buffer, from: recordingFormat, to: targetFormat) {
                self.socket?.write(data: convertedData)
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            self.error = "Microphone failed to start"
        }
    }
    
    private func stopAudioCapture() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: - Audio Conversion
    
    private func convertAndEncodeBuffer(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat, to targetFormat: AVAudioFormat) -> Data? {
        // Simple PCM extraction (for hackathon demo)
        guard let floatData = buffer.floatChannelData?[0] else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        var pcmData = Data(capacity: frameCount * MemoryLayout<Int16>.size)
        
        for i in 0..<frameCount {
            let sample = max(-1.0, min(1.0, floatData[i]))
            var int16Sample = Int16(sample * Float(Int16.max))
            pcmData.append(Data(bytes: &int16Sample, count: MemoryLayout<Int16>.size))
        }
        
        return pcmData
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
                    "properties": [:],
                    "required": []
                ]
            ],
            [
                "type": "function",
                "name": "suggest_calm_spot",
                "description": "Suggest a calm spot in London based on user preferences and current conditions",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "preference": [
                            "type": "string",
                            "description": "User's preference: nature, historic, indoor, family-friendly"
                        ]
                    ]
                ]
            ],
            [
                "type": "function",
                "name": "start_breathing_exercise",
                "description": "Start a guided breathing exercise for stress relief",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "duration": [
                            "type": "integer",
                            "description": "Number of breathing cycles (1-10)"
                        ]
                    ]
                ]
            ]
        ]
        
        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": systemPrompt,
                "voice": "sage", // Calm voice
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "tools": tools,
                "tool_choice": "auto"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: config),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket?.write(string: jsonString)
        }
    }
    
    // MARK: - Tool Handling
    
    func handleToolCall(name: String, arguments: [String: Any], callId: String) {
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
                result = "Starting \(cycles)-cycle breathing exercise. Follow along..."
                DispatchQueue.main.async {
                    self.onToolCallCallback?("breathing", ["cycles": cycles])
                }
                
            default:
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
        default:
            filtered = spots.filter { $0.crowdLevel == .quiet }
        }
        
        guard let spot = filtered.randomElement() ?? spots.randomElement() else {
            return "I recommend Kyoto Garden in Holland Park - it's always peaceful."
        }
        
        DispatchQueue.main.async {
            self.suggestedSpot = spot
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
        }
        
        // Trigger response generation
        let generate: [String: Any] = ["type": "response.create"]
        if let genData = try? JSONSerialization.data(withJSONObject: generate),
           let genString = String(data: genData, encoding: .utf8) {
            socket?.write(string: genString)
        }
    }
    
    // MARK: - Play Audio Response
    
    func playAudioResponse(_ audioData: Data) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        
        audioPlayer.playPCMData(audioData, sampleRate: 24000)
        
        // Monitor playback completion
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(audioData.count) / 48000.0) {
            self.isSpeaking = false
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
        let estimatedDuration = Double(wordCount) / 2.5 // ~2.5 words per second
        
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
}

// MARK: - WebSocket Delegate

extension VoiceManager: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(_):
            print("✅ WebSocket connected")
            sendSessionConfig()
            
        case .text(let text):
            handleTextMessage(text)
            
        case .binary(let data):
            // Audio response from Grok
            playAudioResponse(data)
            
        case .error(let error):
            print("❌ WebSocket error: \(String(describing: error))")
            DispatchQueue.main.async {
                self.error = "Connection error. Please try again."
                self.isListening = false
            }
            
        case .disconnected(let reason, let code):
            print("⚠️ WebSocket disconnected: \(reason) (code: \(code))")
            DispatchQueue.main.async {
                self.isListening = false
            }
            
        case .cancelled:
            DispatchQueue.main.async {
                self.isListening = false
            }
            
        default:
            break
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        switch type {
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
            
        case "input_audio_buffer.speech_started":
            DispatchQueue.main.async {
                self.isProcessing = true
            }
            
        case "input_audio_buffer.speech_stopped":
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            
        case "conversation.item.input_audio_transcription.completed":
            // User's speech transcribed
            if let transcript = json["transcript"] as? String {
                DispatchQueue.main.async {
                    self.transcript = transcript
                }
            }
            
        case "response.function_call_arguments.done":
            // Tool call from Grok
            if let name = json["name"] as? String,
               let callId = json["call_id"] as? String,
               let argsString = json["arguments"] as? String,
               let argsData = argsString.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                handleToolCall(name: name, arguments: args, callId: callId)
            }
            
        case "error":
            if let errorInfo = json["error"] as? [String: Any],
               let message = errorInfo["message"] as? String {
                print("❌ API Error: \(message)")
                DispatchQueue.main.async {
                    self.error = message
                }
            }
            
        default:
            break
        }
    }
}

