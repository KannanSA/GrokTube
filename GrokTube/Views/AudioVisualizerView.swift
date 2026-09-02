//
//  AudioVisualizerView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI
import Combine

/// Enhanced animated audio visualizer that responds to real audio levels
struct AudioVisualizerView: View {
    @Binding var isPlaying: Bool
    var audioLevels: [Float]? = nil // Real audio levels from AudioPlayerService
    
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.15, count: 30)
    @State private var timer: Timer?
    @StateObject private var audioService = AudioPlayerService.shared
    
    let barCount = 30
    let barSpacing: CGFloat = 2
    let minHeight: CGFloat = 3
    let maxHeight: CGFloat = 50
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioBar(
                    amplitude: amplitudes[index],
                    index: index,
                    isPlaying: isPlaying,
                    minHeight: minHeight,
                    maxHeight: maxHeight
                )
            }
        }
        .frame(height: maxHeight)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onReceive(audioService.$audioLevels) { levels in
            if isPlaying && !levels.isEmpty {
                updateFromRealLevels(levels)
            }
        }
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func updateFromRealLevels(_ levels: [Float]) {
        withAnimation(.linear(duration: 0.05)) {
            for i in 0..<min(barCount, levels.count) {
                amplitudes[i] = CGFloat(levels[i])
            }
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                // Generate smooth wave-like pattern
                let basePhase = Date().timeIntervalSince1970 * 8
                for i in 0..<barCount {
                    let wave1 = sin(basePhase + Double(i) * 0.3) * 0.3
                    let wave2 = sin(basePhase * 1.5 + Double(i) * 0.5) * 0.2
                    let random = Double.random(in: -0.1...0.1)
                    amplitudes[i] = CGFloat(max(0.1, min(1.0, 0.4 + wave1 + wave2 + random)))
                }
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.4)) {
            amplitudes = Array(repeating: 0.15, count: barCount)
        }
    }
}

/// Individual audio bar with gradient and glow
struct AudioBar: View {
    let amplitude: CGFloat
    let index: Int
    let isPlaying: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: barColors,
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: minHeight + (maxHeight - minHeight) * amplitude)
            .shadow(color: shadowColor, radius: amplitude > 0.6 ? 4 : 0)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.55)
                .delay(Double(index) * 0.01),
                value: amplitude
            )
    }
    
    private var barColors: [Color] {
        if amplitude > 0.7 {
            return [TubeTheme.undergroundRed, TubeTheme.cream]
        } else if amplitude > 0.4 {
            return [TubeTheme.sage, TubeTheme.cream]
        } else {
            return [TubeTheme.sage.opacity(0.7), TubeTheme.sageDeep.opacity(0.5)]
        }
    }
    
    private var shadowColor: Color {
        if amplitude > 0.7 {
            return TubeTheme.undergroundRed.opacity(0.6)
        } else {
            return TubeTheme.sage.opacity(0.4)
        }
    }
}

/// Compact audio level indicator
struct AudioLevelIndicator: View {
    @ObservedObject var audioService = AudioPlayerService.shared
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: 4 + CGFloat(index) * 4)
                    .opacity(shouldShow(index) ? 1.0 : 0.3)
            }
        }
        .animation(.easeOut(duration: 0.1), value: audioService.audioLevel)
    }
    
    private func shouldShow(_ index: Int) -> Bool {
        guard isActive else { return false }
        let threshold = Float(index) / 5.0
        return audioService.audioLevel >= threshold
    }
    
    private func barColor(for index: Int) -> Color {
        switch index {
        case 0, 1: return TubeTheme.sage
        case 2, 3: return TubeTheme.cream
        default: return TubeTheme.undergroundRed
        }
    }
}

/// Circular audio waveform for mic visualization
struct CircularWaveformView: View {
    @Binding var isRecording: Bool
    @State private var wavePhase: Double = 0
    @State private var amplitude: Double = 0.3
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Outer glow when recording
            if isRecording {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.red.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)
            }
            
            // Multiple wave circles
            ForEach(0..<3) { ring in
                WaveCircle(
                    frequency: Double(ring + 3),
                    phase: wavePhase + Double(ring) * 0.5,
                    amplitude: isRecording ? amplitude : 0.1
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            ringColor(ring).opacity(1.0 - Double(ring) * 0.3),
                            ringColor(ring).opacity(0.6 - Double(ring) * 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isRecording ? 3 - CGFloat(ring) * 0.5 : 2
                )
                .frame(width: 100 - CGFloat(ring * 15), height: 100 - CGFloat(ring * 15))
            }
            
            // Center mic icon
            ZStack {
                Circle()
                    .fill(isRecording ? TubeTheme.undergroundRed.opacity(0.15) : TubeTheme.sage.opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isRecording ? TubeTheme.undergroundRed : TubeTheme.sage)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
            }
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func ringColor(_ ring: Int) -> Color {
        if isRecording {
            return ring == 0 ? .red : .orange
        }
        return TubeTheme.sage
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
            withAnimation(.linear(duration: 0.04)) {
                wavePhase += 0.12
                // Simulate voice amplitude variation
                let baseAmplitude = 0.3
                let variation = sin(wavePhase * 2) * 0.15 + Double.random(in: -0.05...0.05)
                amplitude = max(0.2, min(0.6, baseAmplitude + variation))
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.4)) {
            amplitude = 0.1
            wavePhase = 0
        }
    }
}

/// Shape for circular waveform
struct WaveCircle: Shape {
    var frequency: Double
    var phase: Double
    var amplitude: Double
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        
        var path = Path()
        
        for angle in stride(from: 0.0, through: 360.0, by: 2.0) {
            let radians = angle * .pi / 180
            let waveOffset = sin(radians * frequency + phase) * baseRadius * amplitude * 0.2
            let radius = baseRadius + waveOffset
            
            let x = center.x + CGFloat(radius * cos(radians))
            let y = center.y + CGFloat(radius * sin(radians))
            
            if angle == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

/// Pulsing ring effect for active state
struct PulsingRingView: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    
    let color: Color
    let isActive: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(color.opacity(opacity - Double(i) * 0.2), lineWidth: 2)
                    .scaleEffect(scale + CGFloat(i) * 0.1)
            }
        }
        .onAppear {
            if isActive {
                startPulsing()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                startPulsing()
            } else {
                stopPulsing()
            }
        }
    }
    
    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            scale = 1.3
            opacity = 0.3
        }
    }
    
    private func stopPulsing() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.0
            opacity = 0.8
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        AudioVisualizerView(isPlaying: .constant(true))
        
        CircularWaveformView(isRecording: .constant(true))
            .frame(width: 120, height: 120)
        
        PulsingRingView(color: .blue, isActive: true)
            .frame(width: 100, height: 100)
    }
    .padding()
}
