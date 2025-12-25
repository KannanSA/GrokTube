//
//  SplashScreenView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI

/// Animated splash screen with app logo
struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var leafRotation: Double = -30
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.15),
                    Color(red: 0.05, green: 0.1, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated background circles
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.3 - Double(index) * 0.1),
                                    Color.mint.opacity(0.2 - Double(index) * 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 200 + CGFloat(index * 80), height: 200 + CGFloat(index * 80))
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                }
            }
            
            VStack(spacing: 30) {
                // Logo
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.4),
                                    Color.green.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                    
                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green,
                                    Color(red: 0.2, green: 0.6, blue: 0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.5), radius: 30)
                    
                    // Leaf icon
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(leafRotation))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // App name
                VStack(spacing: 8) {
                    Text("Grok Tube")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("London")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Find your calm")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            // Animate logo
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            // Animate leaf rotation
            withAnimation(.easeOut(duration: 1.0)) {
                leafRotation = 0
            }
            
            // Animate rings
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }
            
            // Animate text
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
