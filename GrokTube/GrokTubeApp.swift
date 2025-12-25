//
//  GrokTubeApp.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI
import SwiftData
import AVFoundation

@main
struct GrokTubeApp: App {
    @State private var showSplash = true
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Configure audio session on app launch
        configureAudioSession()
        
        // Customize appearance
        customizeAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(.none)
                
                // Splash screen overlay
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss splash after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func configureAudioSession() {
        // Configure audio session for playback only on launch
        // Recording session is configured when mic is actually needed
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [
                .mixWithOthers,
                .duckOthers
            ])
            // Don't activate here - let it activate on demand
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func customizeAppearance() {
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        
        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().standardAppearance = navBarAppearance
    }
}
