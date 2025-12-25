//
//  AudioPlayerService.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation
import AVFoundation
import Combine
import Accelerate

/// Enhanced audio player service with streaming, queue management, and real-time visualization
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var isSpeaking = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var audioLevel: Float = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 30) // For visualizer
    
    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine!
    private var playerNode: AVAudioPlayerNode!
    private var mixerNode: AVAudioMixerNode!
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    
    // MARK: - Streaming Audio Queue
    private let audioQueue = DispatchQueue(label: "com.groktube.audioqueue", qos: .userInteractive)
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private var isStreamingActive = false
    private var totalScheduledFrames: AVAudioFramePosition = 0
    
    // MARK: - Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    // MARK: - Audio Format
    private let outputSampleRate: Double = 24000
    private let outputChannels: AVAudioChannelCount = 1
    private lazy var outputFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: outputSampleRate, channels: outputChannels)!
    }()
    
    // MARK: - Callbacks
    var onPlaybackComplete: (() -> Void)?
    var onAudioLevelUpdate: ((Float) -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioEngine()
        setupAudioLevelMonitoring()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixerNode = AVAudioMixerNode()
        
        // Attach nodes
        audioEngine.attach(playerNode)
        audioEngine.attach(mixerNode)
        
        // Connect: playerNode -> mixerNode -> mainMixerNode -> output
        audioEngine.connect(playerNode, to: mixerNode, format: outputFormat)
        audioEngine.connect(mixerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        
        // Set volume to maximum for louder playback
        playerNode.volume = 1.0
        mixerNode.outputVolume = 1.0
        audioEngine.mainMixerNode.outputVolume = 1.0
        
        // Install tap on mixer for level metering
        mixerNode.installTap(onBus: 0, bufferSize: 1024, format: outputFormat) { [weak self] buffer, _ in
            self?.processAudioLevels(buffer: buffer)
        }
        
        prepareAndStartEngine()
    }
    
    private func prepareAndStartEngine() {
        do {
            // Configure audio session first
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            
            audioEngine.prepare()
            try audioEngine.start()
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }
    
    private func restartEngineIfNeeded() {
        if !audioEngine.isRunning {
            print("🔄 Restarting audio engine...")
            prepareAndStartEngine()
        }
    }
    
    // MARK: - Audio Session Configuration
    
    func configureAudioSession(forPlayback: Bool = true) {
        do {
            let session = AVAudioSession.sharedInstance()
            
            if forPlayback {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
            } else {
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP
                ])
            }
            
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Handle interruptions
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Audio Level Processing
    
    private func setupAudioLevelMonitoring() {
        // Use a timer to update published audio levels smoothly
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying || self.isSpeaking {
                self.updateVisualizerLevels()
            }
        }
    }
    
    private func processAudioLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS level
        var rms: Float = 0
        vDSP_measqv(channelData, 1, &rms, vDSP_Length(frameLength))
        rms = sqrt(rms)
        
        // Convert to dB and normalize
        let db = 20 * log10(max(rms, 0.0001))
        let normalizedLevel = max(0, min(1, (db + 60) / 60)) // Normalize -60dB to 0dB
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
            self.onAudioLevelUpdate?(normalizedLevel)
        }
    }
    
    private func updateVisualizerLevels() {
        // Shift levels and add new one with smoothing
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            var newLevels = self.audioLevels
            newLevels.removeFirst()
            
            // Add variation for visual interest
            let variation = Float.random(in: -0.1...0.1)
            let newLevel = max(0, min(1, self.audioLevel + variation))
            newLevels.append(newLevel)
            
            DispatchQueue.main.async {
                self.audioLevels = newLevels
            }
        }
    }
    
    // MARK: - Play PCM Audio Data (Streaming from API)
    
    /// Play raw PCM audio data received from WebSocket (Int16 format)
    func playPCMInt16Data(_ data: Data, sampleRate: Double = 24000) {
        audioQueue.async { [weak self] in
            guard let self = self, data.count > 0 else { 
                print("⚠️ Empty audio data received")
                return 
            }
            
            // Configure audio session for playback
            DispatchQueue.main.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                    try session.setActive(true)
                } catch {
                    print("❌ Audio session config failed: \(error)")
                }
            }
            
            self.restartEngineIfNeeded()
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false) else {
                print("❌ Failed to create Int16 audio format")
                return
            }
            
            let frameCount = UInt32(data.count / MemoryLayout<Int16>.size)
            print("🎵 Processing \(frameCount) audio frames")
            
            guard frameCount > 0 else {
                print("⚠️ Frame count is 0")
                return
            }
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("❌ Failed to create Int16 buffer")
                return
            }
            
            buffer.frameLength = frameCount
            
            // Copy Int16 data directly
            data.withUnsafeBytes { rawBuffer in
                if let int16Data = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                    buffer.int16ChannelData?[0].update(from: int16Data, count: Int(frameCount))
                }
            }
            
            // Convert to float format for playback
            guard let floatBuffer = self.convertInt16ToFloat(buffer) else {
                print("❌ Failed to convert buffer to float, trying direct")
                // Try direct Int16 playback as fallback
                self.scheduleInt16Buffer(buffer)
                return
            }
            
            print("🔊 Scheduling audio buffer for playback")
            self.scheduleBuffer(floatBuffer)
        }
    }
    
    /// Play raw PCM audio data (Float32 format)
    func playPCMData(_ data: Data, sampleRate: Double = 24000) {
        audioQueue.async { [weak self] in
            guard let self = self, data.count > 0 else { return }
            
            self.restartEngineIfNeeded()
            
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let frameCount = UInt32(data.count / MemoryLayout<Float>.size)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("❌ Failed to create Float buffer")
                return
            }
            
            buffer.frameLength = frameCount
            
            data.withUnsafeBytes { rawBuffer in
                if let floatData = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) {
                    buffer.floatChannelData?[0].update(from: floatData, count: Int(frameCount))
                }
            }
            
            self.scheduleBuffer(buffer)
        }
    }
    
    private func convertInt16ToFloat(_ int16Buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let floatFormat = AVAudioFormat(standardFormatWithSampleRate: int16Buffer.format.sampleRate, channels: 1)!
        let frameCount = int16Buffer.frameLength
        
        guard let floatBuffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: int16Buffer.frameCapacity) else {
            return nil
        }
        
        floatBuffer.frameLength = frameCount
        
        // Manual conversion with volume amplification (2.5x boost)
        let volumeBoost: Float = 2.5
        if let int16Data = int16Buffer.int16ChannelData?[0],
           let floatData = floatBuffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let sample = Float(int16Data[i]) / 32768.0 * volumeBoost
                // Clamp to prevent distortion
                floatData[i] = max(-1.0, min(1.0, sample))
            }
        }
        
        return floatBuffer
    }
    
    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        // Ensure engine is running
        if !audioEngine.isRunning {
            print("🔄 Audio engine not running, restarting...")
            prepareAndStartEngine()
        }
        
        // Ensure maximum volume
        playerNode.volume = 1.0
        mixerNode.outputVolume = 1.0
        audioEngine.mainMixerNode.outputVolume = 1.0
        
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isSpeaking = true
        }
        
        // Start player node first if not playing
        if !playerNode.isPlaying {
            playerNode.play()
            print("▶️ Player node started")
        }
        
        playerNode.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else { return }
            
            self.audioQueue.async {
                self.totalScheduledFrames += AVAudioFramePosition(buffer.frameLength)
                
                // Check if this was the last buffer
                if self.pendingBuffers.isEmpty && !self.isStreamingActive {
                    DispatchQueue.main.async {
                        self.isPlaying = false
                        self.isSpeaking = false
                        self.onPlaybackComplete?()
                    }
                }
            }
        }
    }
    
    private func scheduleInt16Buffer(_ buffer: AVAudioPCMBuffer) {
        // Fallback for direct Int16 playback - convert manually
        let frameCount = buffer.frameLength
        guard let floatFormat = AVAudioFormat(standardFormatWithSampleRate: buffer.format.sampleRate, channels: 1),
              let floatBuffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: frameCount) else {
            print("❌ Could not create float buffer for fallback")
            return
        }
        
        floatBuffer.frameLength = frameCount
        
        // Manual conversion Int16 -> Float with volume boost (2.5x amplification)
        let volumeBoost: Float = 2.5
        if let int16Data = buffer.int16ChannelData?[0],
           let floatData = floatBuffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let sample = Float(int16Data[i]) / 32768.0 * volumeBoost
                // Clamp to prevent clipping
                floatData[i] = max(-1.0, min(1.0, sample))
            }
        }
        
        scheduleBuffer(floatBuffer)
    }
    
    /// Play base64 encoded audio
    func playBase64Audio(_ base64String: String, sampleRate: Double = 24000, isInt16: Bool = true) {
        guard let data = Data(base64Encoded: base64String) else {
            print("❌ Invalid base64 audio data")
            return
        }
        
        if isInt16 {
            playPCMInt16Data(data, sampleRate: sampleRate)
        } else {
            playPCMData(data, sampleRate: sampleRate)
        }
    }
    
    // MARK: - Streaming Control
    
    func startStreaming() {
        audioQueue.async {
            self.isStreamingActive = true
            self.totalScheduledFrames = 0
            self.pendingBuffers.removeAll()
        }
        
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }
    
    func endStreaming() {
        audioQueue.async {
            self.isStreamingActive = false
        }
    }
    
    // MARK: - Play Audio File
    
    func playAudioFile(url: URL) {
        do {
            configureAudioSession(forPlayback: true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            
            startProgressTracking()
        } catch {
            print("❌ Failed to play audio file: \(error)")
        }
    }
    
    func playRemoteAudio(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("grok_audio_\(UUID().uuidString).mp3")
            try data.write(to: tempURL)
            
            await MainActor.run {
                playAudioFile(url: tempURL)
            }
        } catch {
            print("❌ Failed to download audio: \(error)")
        }
    }
    
    // MARK: - Text-to-Speech (Enhanced)
    
    func speak(_ text: String, rate: Float = 0.48, pitch: Float = 1.05, volume: Float = 1.0) {
        print("🗣️ TTS speaking: \(text.prefix(50))...")
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Configure audio session on main thread
        DispatchQueue.main.async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                print("✅ Audio session configured for TTS")
            } catch {
                print("❌ Failed to configure audio session: \(error)")
            }
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        utterance.preUtteranceDelay = 0.2
        utterance.postUtteranceDelay = 0.1
        
        // Try to find a good quality voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Priority: Enhanced British female > Enhanced British > Premium British > Standard British
        if let enhancedFemaleVoice = voices.first(where: {
            $0.language == "en-GB" && $0.quality == .enhanced && $0.name.lowercased().contains("samantha")
        }) {
            utterance.voice = enhancedFemaleVoice
            print("🎤 Using voice: \(enhancedFemaleVoice.name)")
        } else if let enhancedVoice = voices.first(where: {
            $0.language == "en-GB" && $0.quality == .enhanced
        }) {
            utterance.voice = enhancedVoice
            print("🎤 Using voice: \(enhancedVoice.name)")
        } else if let premiumVoice = voices.first(where: {
            $0.language == "en-GB" && $0.quality == .premium
        }) {
            utterance.voice = premiumVoice
            print("🎤 Using voice: \(premiumVoice.name)")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            print("🎤 Using default en-GB voice")
        }
        
        currentUtterance = utterance
        
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPlaying = true
        }
        
        // Small delay to ensure audio session is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.synthesizer.speak(utterance)
            print("✅ TTS started speaking")
        }
        
        // Simulate audio levels during TTS
        startTTSLevelSimulation()
    }
    
    private func startTTSLevelSimulation() {
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] timer in
            guard let self = self, self.isSpeaking else {
                timer.invalidate()
                return
            }
            
            // Generate realistic speech-like audio levels
            let baseLevel: Float = 0.4
            let variation = Float.random(in: 0...0.4)
            self.audioLevel = baseLevel + variation
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPlaying = false
            self.audioLevel = 0
        }
    }
    
    // MARK: - Playback Control
    
    func pause() {
        audioPlayer?.pause()
        playerNode.pause()
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func resume() {
        restartEngineIfNeeded()
        audioPlayer?.play()
        playerNode.play()
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        playerNode.stop()
        stopSpeaking()
        stopProgressTracking()
        
        audioQueue.async {
            self.pendingBuffers.removeAll()
            self.isStreamingActive = false
        }
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isSpeaking = false
            self.currentTime = 0
            self.playbackProgress = 0
            self.audioLevel = 0
            self.audioLevels = Array(repeating: 0, count: 30)
        }
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateProgress()
    }
    
    // MARK: - Progress Tracking
    
    private func startProgressTracking() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgress))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        player.updateMeters()
        currentTime = player.currentTime
        playbackProgress = duration > 0 ? currentTime / duration : 0
        
        // Get actual audio level
        let level = player.averagePower(forChannel: 0)
        let normalizedLevel = max(0, min(1, (level + 60) / 60))
        audioLevel = normalizedLevel
    }
    
    private func stopProgressTracking() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        mixerNode.removeTap(onBus: 0)
        stop()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopProgressTracking()
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.playbackProgress = 0
            self.audioLevel = 0
            self.onPlaybackComplete?()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioPlayerService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPlaying = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPlaying = false
            self.audioLevel = 0
            self.onPlaybackComplete?()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPlaying = false
            self.audioLevel = 0
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Can be used to highlight text being spoken
    }
}
