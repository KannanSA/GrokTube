//
//  ContentView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//
import SwiftUI
import AVFoundation
import MapKit
import CoreLocation
import Combine

/// Main content view for Grok Pause London
struct ContentView: View {
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var locationManager = LocationManager()
    
    @State private var transcript = "Tap the mic and tell me how you're feeling..."
    @State private var selectedTab: AppTab = .home
    @State private var selectedSpot: CalmSpot?
    @State private var showSpotDetail = false
    @State private var showBreathingExercise = false
    @State private var weather: ParsedWeather?
    @State private var isLoadingWeather = true
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            distance: 50000,
            heading: 0,
            pitch: 45
        )
    )
    
    enum AppTab: String, CaseIterable {
        case home = "Home"
        case map = "Explore"
        case breathe = "Breathe"
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                // Home Tab
                HomeView(
                    voiceManager: voiceManager,
                    transcript: $transcript,
                    weather: $weather,
                    isLoadingWeather: $isLoadingWeather,
                    selectedSpot: $selectedSpot,
                    showSpotDetail: $showSpotDetail,
                    showBreathingExercise: $showBreathingExercise
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)
                
                // Map Tab
                MapExploreView(
                    selectedSpot: $selectedSpot,
                    showSpotDetail: $showSpotDetail,
                    cameraPosition: $cameraPosition,
                    weather: weather
                )
                .tabItem {
                    Label("Explore", systemImage: "map.fill")
                }
                .tag(AppTab.map)
                
                // Breathing Tab
                BreathingExerciseView(cycles: 4) {
                    selectedTab = .home
                }
                .tabItem {
                    Label("Breathe", systemImage: "wind")
                }
                .tag(AppTab.breathe)
            }
            .tint(.green)
        }
        .onAppear {
            fetchWeather()
            setupVoiceManagerCallbacks()
        }
        .sheet(isPresented: $showSpotDetail) {
            if let spot = selectedSpot {
                SpotDetailSheet(spot: spot, weather: weather)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showBreathingExercise) {
            BreathingExerciseFullScreen {
                showBreathingExercise = false
            }
        }
    }
    
    private func fetchWeather() {
        Task {
            isLoadingWeather = true
            do {
                weather = try await WeatherService.shared.fetchLondonWeather()
            } catch {
                print("Weather fetch failed: \(error)")
            }
            isLoadingWeather = false
        }
    }
    
    private func setupVoiceManagerCallbacks() {
        voiceManager.onToolCallCallback = { toolName, args in
            if toolName == "breathing" {
                showBreathingExercise = true
            }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @ObservedObject var voiceManager: VoiceManager
    @Binding var transcript: String
    @Binding var weather: ParsedWeather?
    @Binding var isLoadingWeather: Bool
    @Binding var selectedSpot: CalmSpot?
    @Binding var showSpotDetail: Bool
    @Binding var showBreathingExercise: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HeaderView()
                    
                    // Weather Card
                    WeatherCardView(weather: weather, isLoading: isLoadingWeather)
                        .padding(.horizontal)
                    
                    // Voice Interface
                    VoiceInterfaceCard(
                        voiceManager: voiceManager,
                        transcript: $transcript
                    )
                    .padding(.horizontal)
                    
                    // Suggested Spot (if any from Grok)
                    if let spot = voiceManager.suggestedSpot {
                        SuggestedSpotCard(spot: spot) {
                            selectedSpot = spot
                            showSpotDetail = true
                        }
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    // Quick Actions
                    QuickActionsView(
                        onBreatheTap: { showBreathingExercise = true },
                        onSpotTap: {
                            if let randomSpot = CalmSpot.allSpots.randomElement() {
                                selectedSpot = randomSpot
                                showSpotDetail = true
                            }
                        }
                    )
                    .padding(.horizontal)
                    
                    // Featured Spots Carousel
                    FeaturedSpotsCarousel(spots: CalmSpot.allSpots) { spot in
                        selectedSpot = spot
                        showSpotDetail = true
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Grok Pause")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                
                Text("London")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Voice Interface Card

struct VoiceInterfaceCard: View {
    @ObservedObject var voiceManager: VoiceManager
    @Binding var transcript: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Response text
            VStack(alignment: .leading, spacing: 8) {
                if !voiceManager.grokResponse.isEmpty {
                    Text("Grok says:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(voiceManager.grokResponse)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                
                if !voiceManager.transcript.isEmpty {
                    Text("You said:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    Text(voiceManager.transcript)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                if voiceManager.grokResponse.isEmpty && voiceManager.transcript.isEmpty {
                    Text(transcript)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Audio visualizer when speaking
            if voiceManager.isSpeaking {
                AudioVisualizerView(isPlaying: .constant(true))
                    .frame(height: 40)
                    .padding(.horizontal)
            }
            
            // Mic button
            VStack(spacing: 8) {
                ZStack {
                    // Pulsing background
                    if voiceManager.isListening {
                        PulsingRingView(color: .red, isActive: true)
                            .frame(width: 100, height: 100)
                    }
                    
                    // Waveform
                    if voiceManager.isListening {
                        CircularWaveformView(isRecording: .constant(true))
                            .frame(width: 90, height: 90)
                    }
                    
                    Button(action: toggleListening) {
                        ZStack {
                            Circle()
                                .fill(voiceManager.isListening ? Color.red : Color.green)
                                .frame(width: 80, height: 80)
                                .shadow(color: (voiceManager.isListening ? Color.red : Color.green).opacity(0.4), radius: 15)
                            
                            Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Text(voiceManager.isListening ? "Listening..." : "Tap to talk")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error message
            if let error = voiceManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 15)
        )
    }
    
    private func toggleListening() {
        if voiceManager.isListening {
            voiceManager.stopSession()
        } else {
            voiceManager.startSession { response in
                transcript = response
            }
        }
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    let onBreatheTap: () -> Void
    let onSpotTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                title: "Breathe",
                subtitle: "4-4-4-2",
                icon: "wind",
                color: .cyan
            ) {
                onBreatheTap()
            }
            
            QuickActionButton(
                title: "Random Spot",
                subtitle: "Surprise me",
                icon: "dice.fill",
                color: .orange
            ) {
                onSpotTap()
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
            )
        }
    }
}

// MARK: - Suggested Spot Card

struct SuggestedSpotCard: View {
    let spot: CalmSpot
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: spot.systemImage)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grok suggests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(spot.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label("\(spot.nearestTube.walkingMinutes) min", systemImage: "figure.walk")
                        Label(spot.crowdLevel.rawValue, systemImage: spot.crowdLevel.icon)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Featured Spots Carousel

struct FeaturedSpotsCarousel: View {
    let spots: [CalmSpot]
    let onSpotTap: (CalmSpot) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calm Spots")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(spots) { spot in
                        SpotCard(spot: spot)
                            .onTapGesture {
                                onSpotTap(spot)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct SpotCard: View {
    let spot: CalmSpot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.6), .mint.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Image(systemName: spot.systemImage)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 160, height: 100)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    Text(spot.nearestTube.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(crowdColor)
                        .frame(width: 8, height: 8)
                    
                    Text(spot.crowdLevel.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 160)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var crowdColor: Color {
        switch spot.crowdLevel {
        case .quiet: return .green
        case .moderate: return .orange
        case .busy: return .red
        }
    }
}

// MARK: - Map Explore View

struct MapExploreView: View {
    @Binding var selectedSpot: CalmSpot?
    @Binding var showSpotDetail: Bool
    @Binding var cameraPosition: MapCameraPosition
    let weather: ParsedWeather?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map3DView(
                selectedSpot: $selectedSpot,
                cameraPosition: $cameraPosition,
                spots: CalmSpot.allSpots
            ) { spot in
                showSpotDetail = true
            }
            .ignoresSafeArea()
            
            // Bottom card
            if let spot = selectedSpot {
                SpotDetailCard(spot: spot, weather: weather) {
                    selectedSpot = nil
                } onGetDirections: {
                    openDirections(to: spot)
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedSpot?.id)
    }
    
    private func openDirections(to spot: CalmSpot) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

// MARK: - Spot Detail Sheet

struct SpotDetailSheet: View {
    let spot: CalmSpot
    let weather: ParsedWeather?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero image placeholder
                    ZStack {
                        LinearGradient(
                            colors: [.green.opacity(0.7), .mint.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        Image(systemName: spot.systemImage)
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        Text(spot.name)
                            .font(.title.bold())
                        
                        // Description
                        Text(spot.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Weather
                        if let weather = weather {
                            WeatherMiniCard(weather: weather)
                        }
                        
                        // Tags
                        FlowLayout(spacing: 8) {
                            ForEach(spot.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Divider()
                        
                        // Transport
                        TransportInfoView(station: spot.nearestTube)
                        
                        // Opening hours
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text(spot.openingHours)
                                .font(.subheadline)
                        }
                        
                        // Crowd level
                        HStack {
                            Image(systemName: spot.crowdLevel.icon)
                                .foregroundColor(crowdColor)
                            Text("Currently \(spot.crowdLevel.rawValue.lowercased())")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Directions button
                    Button(action: openDirections) {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var crowdColor: Color {
        switch spot.crowdLevel {
        case .quiet: return .green
        case .moderate: return .orange
        case .busy: return .red
        }
    }
    
    private func openDirections() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

// MARK: - Transport Info View

struct TransportInfoView: View {
    let station: TubeStation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(.red)
                
                Text("Nearest Tube")
                    .font(.headline)
            }
            
            HStack {
                Text(station.name)
                    .font(.subheadline.bold())
                
                Spacer()
                
                Label("\(station.walkingMinutes) min walk", systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Tube lines
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(station.lines, id: \.self) { line in
                        Text(line.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: line.color))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if rowWidth + size.width > containerWidth {
                height += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        
        height += rowHeight
        return CGSize(width: containerWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Breathing Exercise Full Screen

struct BreathingExerciseFullScreen: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            BreathingExerciseView(cycles: 4) {
                onDismiss()
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

#Preview {
    ContentView()
}
