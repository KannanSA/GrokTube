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

/// Main content view for Grok Tube
struct ContentView: View {
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var locationManager = LocationManager()

    @State private var transcript = "Tap the mic and tell me how you're feeling..."
    @State private var selectedTab: AppTab = .home
    @State private var previousTab: AppTab = .home
    @State private var selectedSpot: CalmSpot?
    @State private var showSpotDetail = false
    @State private var showBreathingExercise = false
    @State private var showWeatherDetail = false
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

    var body: some View {
        ZStack {
            TubeTheme.night.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        voiceManager: voiceManager,
                        transcript: $transcript,
                        weather: $weather,
                        isLoadingWeather: $isLoadingWeather,
                        selectedSpot: $selectedSpot,
                        showSpotDetail: $showSpotDetail,
                        onShowWeatherDetail: { showWeatherDetail = true }
                    )
                case .map:
                    MapExploreView(
                        selectedSpot: $selectedSpot,
                        showSpotDetail: $showSpotDetail,
                        cameraPosition: $cameraPosition,
                        weather: weather
                    )
                case .breathe:
                    Color.clear
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if selectedTab != .breathe {
                VStack {
                    Spacer()
                    UndergroundTabBar(selectedTab: tabBarBinding)
                }
            }

            if selectedTab == .breathe {
                BreathingExerciseView(cycles: 8) {
                    selectedTab = previousTab
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(TubeTheme.undergroundRed)
        .onAppear {
            fetchWeather()
            setupVoiceManagerCallbacks()
        }
        .sheet(isPresented: $showSpotDetail) {
            if let spot = selectedSpot {
                SpotDetailSheet(spot: spot, weather: weather)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(TubeTheme.charcoal)
            }
        }
        .sheet(isPresented: $showWeatherDetail) {
            WeatherDetailSheet(weather: weather, isLoading: isLoadingWeather)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(TubeTheme.charcoal)
        }
        .fullScreenCover(isPresented: $showBreathingExercise) {
            BreathingExerciseFullScreen {
                showBreathingExercise = false
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .breathe && oldValue != .breathe {
                previousTab = oldValue
            }
        }
    }

    private var tabBarBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .breathe && selectedTab != .breathe {
                    previousTab = selectedTab
                }
                selectedTab = newValue
            }
        )
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
            print("🔧 Tool callback: \(toolName)")
            if toolName == "breathing" || toolName == "start_breathing_exercise" {
                DispatchQueue.main.async {
                    showBreathingExercise = true
                }
            }
        }

        voiceManager.onSpotSuggested = { spot in
            print("📍 Spot suggested callback: \(spot.name)")
            DispatchQueue.main.async {
                selectedSpot = spot
                showSpotDetail = true
                selectedTab = .map
            }
        }
    }
}

// MARK: - Weather Detail Sheet

struct WeatherDetailSheet: View {
    let weather: ParsedWeather?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                WeatherCardView(weather: weather, isLoading: isLoading)
                    .padding()
                Spacer()
            }
            .background(TubeTheme.night.ignoresSafeArea())
            .navigationTitle("London weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TubeTheme.undergroundRed)
                }
            }
        }
        .preferredColorScheme(.dark)
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
                    SpotLiveFeedView(spotName: spot.name)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(spot.name)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .fontWidth(.condensed)
                            .foregroundStyle(TubeTheme.cream)

                        Text(spot.description)
                            .font(.body)
                            .foregroundStyle(TubeTheme.creamMuted)

                        if let weather {
                            WeatherMiniCard(weather: weather)
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(spot.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(TubeTheme.sage.opacity(0.18))
                                    .foregroundStyle(TubeTheme.sage)
                                    .clipShape(Capsule())
                            }
                        }

                        Divider().overlay(TubeTheme.cream.opacity(0.12))

                        TransportInfoView(station: spot.nearestTube)

                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text(spot.openingHours)
                                .font(.subheadline)
                                .foregroundStyle(TubeTheme.creamMuted)
                        }

                        HStack {
                            Image(systemName: spot.crowdLevel.icon)
                                .foregroundStyle(crowdColor)
                            Text("Currently \(spot.crowdLevel.rawValue.lowercased())")
                                .font(.subheadline)
                                .foregroundStyle(TubeTheme.creamMuted)
                        }
                    }
                    .padding(.horizontal)

                    Button(action: openDirections) {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TubeTheme.undergroundRed)
                            .foregroundStyle(TubeTheme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(TubeTheme.night.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TubeTheme.undergroundRed)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var crowdColor: Color {
        switch spot.crowdLevel {
        case .quiet: return TubeTheme.sage
        case .moderate: return .orange
        case .busy: return TubeTheme.undergroundRed
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
                    .foregroundStyle(TubeTheme.undergroundRed)
                Text("Nearest Tube")
                    .font(.headline)
                    .foregroundStyle(TubeTheme.cream)
            }

            HStack {
                Text(station.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(TubeTheme.cream)
                Spacer()
                Label("\(station.walkingMinutes) min walk", systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundStyle(TubeTheme.creamMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(station.lines, id: \.self) { line in
                        Text(line.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: line.color))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(TubeTheme.ticket)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        BreathingExerciseView(cycles: 8) {
            onDismiss()
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
