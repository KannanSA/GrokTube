//
//  AudioVisualizerView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI

/// Animated audio visualizer for voice responses
struct AudioVisualizerView: View {
    @Binding var isPlaying: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.2, count: 30)
    @State private var timer: Timer?
    
    let barCount = 30
    let barSpacing: CGFloat = 3
    let minHeight: CGFloat = 4
    let maxHeight: CGFloat = 50
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: minHeight + (maxHeight - minHeight) * amplitudes[index])
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5)
                        .delay(Double(index) * 0.02),
                        value: amplitudes[index]
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
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                for i in 0..<barCount {
                    amplitudes[i] = CGFloat.random(in: 0.1...1.0)
                }
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            amplitudes = Array(repeating: 0.2, count: barCount)
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
                            .blue.opacity(1.0 - Double(ring) * 0.3),
                            .purple.opacity(0.8 - Double(ring) * 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3 - CGFloat(ring) * 0.5
                )
                .frame(width: 100 - CGFloat(ring * 15), height: 100 - CGFloat(ring * 15))
            }
            
            // Center mic icon
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 30))
                .foregroundColor(isRecording ? .red : .blue)
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
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
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                wavePhase += 0.15
                amplitude = Double.random(in: 0.2...0.5)
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            amplitude = 0.1
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
