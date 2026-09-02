//
//  VoiceOrbView.swift
//  GrokTube
//
//  Large sage-glow voice orb with waveform — tap to talk to Ani.
//

import SwiftUI

struct VoiceOrbView: View {
    @ObservedObject var voiceManager: VoiceManager
    @Binding var transcript: String

    @State private var textInput = ""
    @State private var showTextInput = false
    @State private var glowPulse = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 22) {
            connectionRow

            sageOrb
                .onTapGesture { toggleListening() }

            VStack(spacing: 6) {
                Text(headlineCaption)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(TubeTheme.cream)
                    .multilineTextAlignment(.center)

                Text(buttonLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(TubeTheme.creamMuted)
            }

            dialogueCard

            if voiceManager.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(TubeTheme.sage)
                        .scaleEffect(0.8)
                    Text("Thinking...")
                        .font(.caption)
                        .foregroundStyle(TubeTheme.creamMuted)
                }
            }

            if showTextInput {
                textInputRow
            }

            if let error = voiceManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(TubeTheme.undergroundRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var connectionRow: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .shadow(color: statusColor.opacity(0.8), radius: 4)
            Text(voiceManager.connectionStatus)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(TubeTheme.creamMuted)
            Spacer()
            Button {
                withAnimation { showTextInput.toggle() }
            } label: {
                Image(systemName: showTextInput ? "mic.fill" : "keyboard")
                    .font(.caption)
                    .foregroundStyle(TubeTheme.creamMuted)
                    .padding(8)
                    .background(Circle().fill(TubeTheme.mist))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showTextInput ? "Switch to voice" : "Switch to keyboard")
        }
        .padding(.horizontal, 4)
    }

    private var sageOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            TubeTheme.sage.opacity(glowPulse ? 0.55 : 0.28),
                            TubeTheme.sage.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 18)

            if voiceManager.isListening {
                PulsingRingView(color: TubeTheme.undergroundRed, isActive: true)
                    .frame(width: 210, height: 210)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            TubeTheme.sage,
                            TubeTheme.sageDeep
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 196, height: 196)
                .overlay(
                    Circle()
                        .stroke(TubeTheme.cream.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: TubeTheme.sage.opacity(0.55), radius: glowPulse ? 36 : 22)

            SageOrbWaveform(
                isActive: voiceManager.isListening || voiceManager.isSpeaking
            )
            .frame(width: 140, height: 56)

            if !voiceManager.isListening && !voiceManager.isSpeaking {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TubeTheme.cream.opacity(0.85))
                    .offset(y: 48)
            }
        }
        .frame(height: 260)
        .accessibilityLabel(buttonLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var dialogueCard: some View {
        if !voiceManager.grokResponse.isEmpty || !voiceManager.transcript.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !voiceManager.grokResponse.isEmpty {
                    Text("Ani")
                        .tubeJohnstonCaption()
                        .foregroundStyle(TubeTheme.sage)
                    Text(voiceManager.grokResponse)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(TubeTheme.cream)
                }
                if !voiceManager.transcript.isEmpty {
                    Text("You")
                        .tubeJohnstonCaption()
                        .foregroundStyle(TubeTheme.creamMuted)
                        .padding(.top, 4)
                    Text(voiceManager.transcript)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(TubeTheme.creamMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TubeTheme.charcoal)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(TubeTheme.cream.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var textInputRow: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $textInput)
                .textFieldStyle(.plain)
                .foregroundStyle(TubeTheme.cream)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(TubeTheme.mist)
                )
                .focused($isTextFieldFocused)
                .onSubmit { sendTextMessage() }

            Button(action: sendTextMessage) {
                ZStack {
                    Circle()
                        .fill(textInput.isEmpty ? TubeTheme.charcoal : TubeTheme.undergroundRed)
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TubeTheme.cream)
                }
            }
            .disabled(textInput.isEmpty || !voiceManager.isConnected)
        }
        .onAppear {
            if !voiceManager.isConnected {
                connectToGrok()
            }
        }
    }

    private var headlineCaption: String {
        if voiceManager.isListening {
            return "Listening…"
        }
        if voiceManager.isSpeaking {
            return "Ani is speaking"
        }
        return "Ask Ani about a calm spot"
    }

    private var buttonLabel: String {
        if voiceManager.isListening {
            return "tap to stop"
        }
        if voiceManager.isConnected {
            return "tap to talk"
        }
        return "tap to talk"
    }

    private var statusColor: Color {
        switch voiceManager.connectionStatus {
        case "Connected", "Session Ready", _ where voiceManager.connectionStatus.contains("Ready"):
            return TubeTheme.sage
        case "Connecting...":
            return .orange
        case "Error", "Disconnected":
            return TubeTheme.undergroundRed
        default:
            return TubeTheme.creamMuted
        }
    }

    private func connectToGrok() {
        voiceManager.startSession { response in
            transcript = response
        }
    }

    private func toggleListening() {
        if voiceManager.isConnected {
            voiceManager.toggleListening()
        } else {
            voiceManager.startSession { response in
                transcript = response
            }
        }
    }

    private func sendTextMessage() {
        guard !textInput.isEmpty else { return }
        let message = textInput
        textInput = ""
        isTextFieldFocused = false
        voiceManager.sendTextMessage(message)
    }
}

/// Sage bars inside the voice orb.
struct SageOrbWaveform: View {
    let isActive: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.28, count: 18)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<18, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(TubeTheme.cream.opacity(isActive ? 0.95 : 0.55))
                    .frame(width: 4, height: 8 + 48 * amplitudes[index])
            }
        }
        .onChange(of: isActive) { _, active in
            active ? start() : stop()
        }
        .onAppear {
            if isActive { start() }
        }
        .onDisappear { stop() }
    }

    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                let phase = Date().timeIntervalSince1970 * 7
                for i in 0..<18 {
                    let wave = sin(phase + Double(i) * 0.38) * 0.35
                    amplitudes[i] = CGFloat(max(0.12, min(1.0, 0.45 + wave + Double.random(in: -0.08...0.08))))
                }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.35)) {
            amplitudes = Array(repeating: 0.28, count: 18)
        }
    }
}
