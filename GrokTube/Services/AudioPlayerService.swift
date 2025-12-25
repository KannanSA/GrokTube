//
//  AudioPlayerService.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Foundation
import AVFoundation
import Combine

/// Real audio player service for playing Grok's voice responses
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    
    private var audioEngine: AVAudioEngine!
    private var playerNode: AVAudioPlayerNode!
    private var audioPlayer: AVAudioPlayer?
    private var audioBuffer: AVAudioPCMBuffer?
    private var displayLink: CADisplayLink?
    
    // Audio queue for streaming playback
    private var audioQueue = DispatchQueue(label: "com.groktube.audioqueue", qos: .userInteractive)
    private var pcmBufferQueue: [AVAudioPCMBuffer] = []
    private var isStreaming = false
    
    // Text-to-Speech fallback
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        audioEngine.attach(playerNode)
        
        // Connect player to main mixer
        let mainMixer = audioEngine.mainMixerNode
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        
        audioEngine.connect(playerNode, to: mainMixer, format: format)
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    // MARK: - Configure Audio Session
    
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Play PCM Audio Data (from Grok API)
    
    /// Play raw PCM audio data received from WebSocket
    func playPCMData(_ data: Data, sampleRate: Double = 24000) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let frameCount = UInt32(data.count) / UInt32(MemoryLayout<Float>.size)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("Failed to create audio buffer")
                return
            }
            
            buffer.frameLength = frameCount
            
            // Copy data to buffer
            data.withUnsafeBytes { rawBuffer in
                if let floatData = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) {
                    buffer.floatChannelData?[0].update(from: floatData, count: Int(frameCount))
                }
            }
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            
            self.playerNode.scheduleBuffer(buffer, completionHandler: {
                DispatchQueue.main.async {
                    self.isPlaying = false
                }
            })
            
            if !self.playerNode.isPlaying {
                self.playerNode.play()
            }
        }
    }
    
    /// Play base64 encoded audio (common API response format)
    func playBase64Audio(_ base64String: String, sampleRate: Double = 24000) {
        guard let data = Data(base64Encoded: base64String) else {
            print("Invalid base64 audio data")
            return
        }
        playPCMData(data, sampleRate: sampleRate)
    }
    
    // MARK: - Play Audio File
    
    /// Play audio from a local file URL
    func playAudioFile(url: URL) {
        do {
            configureAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            
            audioPlayer?.play()
            isPlaying = true
            
            startProgressTracking()
        } catch {
            print("Failed to play audio file: \(error)")
        }
    }
    
    /// Play audio from remote URL
    func playRemoteAudio(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Save to temp file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("grok_audio.mp3")
            try data.write(to: tempURL)
            
            await MainActor.run {
                playAudioFile(url: tempURL)
            }
        } catch {
            print("Failed to download and play remote audio: \(error)")
        }
    }
    
    // MARK: - Text-to-Speech Fallback
    
    /// Speak text using system TTS (fallback when audio not available)
    func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") // British accent for London vibe
        
        DispatchQueue.main.async {
            self.isPlaying = true
        }
        
        synthesizer.speak(utterance)
    }
    
    /// Stop TTS
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }
    
    // MARK: - Playback Control
    
    func pause() {
        audioPlayer?.pause()
        playerNode.pause()
        isPlaying = false
    }
    
    func resume() {
        audioPlayer?.play()
        playerNode.play()
        isPlaying = true
    }
    
    func stop() {
        audioPlayer?.stop()
        playerNode.stop()
        stopSpeaking()
        isPlaying = false
        currentTime = 0
        playbackProgress = 0
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
        currentTime = player.currentTime
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }
    
    private func stopProgressTracking() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Audio Level Visualization
    
    /// Get current audio level for visualization
    func getAudioLevel() -> Float {
        audioPlayer?.updateMeters()
        return audioPlayer?.averagePower(forChannel: 0) ?? -160
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.playbackProgress = 0
        }
        stopProgressTracking()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioPlayerService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
