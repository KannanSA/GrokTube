//
//  BreathingExerciseView.swift
//  GrokTube
//
//  Immersive full-screen sage breathing — INHALE, 4 of 8 breaths, cream/red bar, close X.
//

import SwiftUI

/// Immersive animated breathing exercise. No tab bar; dismiss with the close control.
struct BreathingExerciseView: View {
    @State private var breathPhase: BreathPhase = .inhale
    @State private var scale: CGFloat = 0.55
    @State private var circleOpacity: Double = 0.4
    @State private var timer: Timer?
    @State private var breathCount = 0
    @State private var isActive = false
    @State private var phaseProgress: CGFloat = 0

    let totalBreaths: Int
    let onComplete: () -> Void

    init(cycles: Int = 8, onComplete: @escaping () -> Void = {}) {
        self.totalBreaths = max(cycles, 1)
        self.onComplete = onComplete
    }

    enum BreathPhase: String {
        case inhale = "INHALE"
        case hold = "HOLD"
        case exhale = "EXHALE"
        case rest = "REST"

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
    }

    var body: some View {
        ZStack {
            TubeTheme.night.ignoresSafeArea()

            RadialGradient(
                colors: [
                    TubeTheme.sage.opacity(0.22),
                    TubeTheme.night
                ],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.1), value: breathPhase)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(TubeTheme.cream)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(TubeTheme.charcoal))
                            .overlay(Circle().stroke(TubeTheme.cream.opacity(0.12), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                creamRedProgress
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                Spacer()

                sageCircle

                Spacer()

                Text("\(displayBreath) of \(totalBreaths) breaths")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(TubeTheme.creamMuted)
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear { startBreathing() }
        .onDisappear { stopBreathing() }
    }

    private var displayBreath: Int {
        min(max(breathCount, 0) + 1, totalBreaths)
    }

    private var overallProgress: CGFloat {
        let completed = CGFloat(breathCount) / CGFloat(totalBreaths)
        let current = phaseProgress / CGFloat(totalBreaths)
        return min(1, completed + current)
    }

    private var creamRedProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(TubeTheme.cream.opacity(0.22))
                Capsule(style: .continuous)
                    .fill(TubeTheme.undergroundRed)
                    .frame(width: max(8, geo.size.width * overallProgress))
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.2), value: overallProgress)
    }

    private var sageCircle: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(TubeTheme.sage.opacity(0.18 - Double(i) * 0.04), lineWidth: 1.5)
                    .frame(width: 220 + CGFloat(i * 48), height: 220 + CGFloat(i * 48))
                    .scaleEffect(scale * (1 + CGFloat(i) * 0.06))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            TubeTheme.sage.opacity(0.95),
                            TubeTheme.sageDeep.opacity(0.7),
                            TubeTheme.sage.opacity(0.15)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 130
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(scale)
                .opacity(circleOpacity)
                .shadow(color: TubeTheme.sage.opacity(0.55), radius: 40)

            Text(breathPhase.rawValue)
                .font(.system(size: 28, weight: .heavy, design: .default))
                .fontWidth(.condensed)
                .tracking(4)
                .foregroundStyle(TubeTheme.cream)
                .shadow(color: .black.opacity(0.35), radius: 8)
        }
        .frame(height: 340)
        .contentShape(Circle())
        .onTapGesture {
            if isActive {
                stopBreathing()
            } else {
                startBreathing()
            }
        }
    }

    private func dismiss() {
        stopBreathing()
        onComplete()
    }

    private func startBreathing() {
        isActive = true
        breathCount = 0
        breathPhase = .inhale
        phaseProgress = 0
        animatePhase()
    }

    private func stopBreathing() {
        isActive = false
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.45)) {
            scale = 0.55
            circleOpacity = 0.4
            phaseProgress = 0
        }
    }

    private func animatePhase() {
        guard isActive else { return }

        phaseProgress = 0
        withAnimation(.linear(duration: breathPhase.duration)) {
            phaseProgress = 1
        }

        withAnimation(.easeInOut(duration: breathPhase.duration)) {
            switch breathPhase {
            case .inhale:
                scale = 1.08
                circleOpacity = 0.95
            case .hold:
                scale = 1.08
                circleOpacity = 1.0
            case .exhale:
                scale = 0.55
                circleOpacity = 0.45
            case .rest:
                scale = 0.55
                circleOpacity = 0.35
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: breathPhase.duration, repeats: false) { _ in
            let nextPhase = breathPhase.next

            if nextPhase == .inhale {
                breathCount += 1
                if breathCount >= totalBreaths {
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

#Preview {
    BreathingExerciseView(cycles: 8) {
        print("Breathing complete!")
    }
}
