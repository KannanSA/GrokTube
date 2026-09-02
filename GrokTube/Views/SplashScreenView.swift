//
//  SplashScreenView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI

/// Animated splash with Underground roundel branding.
struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            TubeTheme.nightGradient.ignoresSafeArea()

            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(TubeTheme.undergroundRed.opacity(0.18 - Double(index) * 0.05), lineWidth: 1.5)
                        .frame(width: 200 + CGFloat(index * 80), height: 200 + CGFloat(index * 80))
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                }
            }

            VStack(spacing: 28) {
                UndergroundRoundel(size: 148)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("Find your calm")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted)
                }
                .opacity(textOpacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
