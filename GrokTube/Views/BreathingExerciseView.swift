//
//  BreathingExerciseView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI

/// Beautiful animated breathing exercise view
struct BreathingExerciseView: View {
    @State private var isAnimating = false
    @State private var breathPhase: BreathPhase = .inhale
    @State private var scale: CGFloat = 0.5
    @State private var circleOpacity: Double = 0.3
    @State private var timer: Timer?
    @State private var cycleCount = 0
    @State private var isActive = false
    
    let totalCycles: Int
    let onComplete: () -> Void
    
    init(cycles: Int = 4, onComplete: @escaping () -> Void = {}) {
        self.totalCycles = cycles
        self.onComplete = onComplete
    }
    
    enum BreathPhase: String {
        case inhale = "Breathe In"
        case hold = "Hold"
        case exhale = "Breathe Out"
        case rest = "Rest"
        
        var duration: Double {
            switch self {
            case .inhale: return 4.0
            case .hold: return 4.0
            case .exhale: return 4.0
            case .rest: return 2.0
            }
        }
        
        var next: BreathPhase {
            switch self {
            case .inhale: return .hold
            case .hold: return .exhale
            case .exhale: return .rest
            case .rest: return .inhale
            }
        }
        
        var color: Color {
            switch self {
            case .inhale: return .cyan
            case .hold: return .purple
            case .exhale: return .green
            case .rest: return .orange
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    breathPhase.color.opacity(0.3),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1), value: breathPhase)
            
            VStack(spacing: 40) {
                // Title
                Text("4-4-4-2 Box Breathing")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                // Cycle counter
                Text("Cycle \(cycleCount + 1) of \(totalCycles)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Breathing circle animation
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(breathPhase.color.opacity(0.2 - Double(i) * 0.05), lineWidth: 2)
                            .frame(width: 200 + CGFloat(i * 40), height: 200 + CGFloat(i * 40))
                            .scaleEffect(scale * (1 + CGFloat(i) * 0.1))
                            .animation(
                                .easeInOut(duration: breathPhase.duration)
                                .delay(Double(i) * 0.1),
                                value: scale
                            )
                    }
                    
                    // Main breathing circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    breathPhase.color.opacity(0.8),
                                    breathPhase.color.opacity(0.4),
                                    breathPhase.color.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(scale)
                        .opacity(circleOpacity)
                        .shadow(color: breathPhase.color.opacity(0.5), radius: 30)
                    
                    // Inner circle with instruction
                    Circle()
                        .fill(Color(.systemBackground).opacity(0.9))
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale * 0.9)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    // Instruction text
                    VStack(spacing: 4) {
                        Text(breathPhase.rawValue)
                            .font(.headline)
                            .foregroundColor(breathPhase.color)
                        
                        Text(String(format: "%.0fs", breathPhase.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .scaleEffect(scale * 0.9 + 0.1)
                }
                .frame(height: 300)
                
                Spacer()
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(BreathPhase.allCases, id: \.self) { phase in
                        Circle()
                            .fill(breathPhase == phase ? phase.color : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .scaleEffect(breathPhase == phase ? 1.2 : 1.0)
                            .animation(.spring(), value: breathPhase)
                    }
                }
                
                // Control button
                Button(action: {
                    if isActive {
                        stopBreathing()
                    } else {
                        startBreathing()
                    }
                }) {
                    HStack {
                        Image(systemName: isActive ? "stop.fill" : "play.fill")
                        Text(isActive ? "Stop" : "Start")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 150, height: 50)
                    .background(isActive ? Color.red : breathPhase.color)
                    .clipShape(Capsule())
                    .shadow(color: (isActive ? Color.red : breathPhase.color).opacity(0.4), radius: 10)
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
    
    private func startBreathing() {
        isActive = true
        cycleCount = 0
        breathPhase = .inhale
        animatePhase()
    }
    
    private func stopBreathing() {
        isActive = false
        timer?.invalidate()
        timer = nil
        
        withAnimation(.easeOut(duration: 0.5)) {
            scale = 0.5
            circleOpacity = 0.3
        }
    }
    
    private func animatePhase() {
        guard isActive else { return }
        
        // Animate scale based on phase
        withAnimation(.easeInOut(duration: breathPhase.duration)) {
            switch breathPhase {
            case .inhale:
                scale = 1.0
                circleOpacity = 0.8
            case .hold:
                scale = 1.0
                circleOpacity = 0.9
            case .exhale:
                scale = 0.5
                circleOpacity = 0.4
            case .rest:
                scale = 0.5
                circleOpacity = 0.3
            }
        }
        
        // Schedule next phase
        timer = Timer.scheduledTimer(withTimeInterval: breathPhase.duration, repeats: false) { _ in
            let nextPhase = breathPhase.next
            
            // Check if completing a cycle
            if nextPhase == .inhale {
                cycleCount += 1
                if cycleCount >= totalCycles {
                    stopBreathing()
                    onComplete()
                    return
                }
            }
            
            breathPhase = nextPhase
            animatePhase()
        }
    }
}

extension BreathingExerciseView.BreathPhase: CaseIterable {
    static var allCases: [BreathingExerciseView.BreathPhase] {
        [.inhale, .hold, .exhale, .rest]
    }
}

#Preview {
    BreathingExerciseView(cycles: 4) {
        print("Breathing complete!")
    }
}
