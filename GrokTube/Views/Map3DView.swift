//
//  Map3DView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI
import MapKit
import CoreLocation

/// Immersive 3D Map View with realistic rendering and custom annotations
struct Map3DView: View {
    @Binding var selectedSpot: CalmSpot?
    @Binding var cameraPosition: MapCameraPosition
    @State private var showRoute = false
    @State private var route: MKRoute?
    @State private var mapStyle: MapStyleOption = .realistic3D
    @State private var showStylePicker = false
    @State private var isAnimatingCamera = false
    
    let spots: [CalmSpot]
    let onSpotSelected: (CalmSpot) -> Void
    
    enum MapStyleOption: String, CaseIterable {
        case realistic3D = "3D Realistic"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
        case standard = "Standard"
        
        var style: MapStyle {
            switch self {
            case .realistic3D:
                return .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .including([.park, .museum, .nationalPark, .publicTransport]))
            case .satellite:
                return .imagery(elevation: .realistic)
            case .hybrid:
                return .hybrid(elevation: .realistic, pointsOfInterest: .including([.park, .publicTransport]))
            case .standard:
                return .standard(elevation: .flat, pointsOfInterest: .including([.park, .publicTransport]))
            }
        }
        
        var icon: String {
            switch self {
            case .realistic3D: return "view.3d"
            case .satellite: return "globe.europe.africa.fill"
            case .hybrid: return "map.fill"
            case .standard: return "map"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Main 3D Map
            Map(position: $cameraPosition, interactionModes: [.all]) {
                // User location with custom style
                UserAnnotation()
                
                // Park markers with 3D-aware styling
                ForEach(spots) { spot in
                    Annotation(spot.name, coordinate: spot.coordinate, anchor: .bottom) {
                        Spot3DMarkerView(
                            spot: spot,
                            isSelected: selectedSpot?.id == spot.id
                        )
                        .onTapGesture {
                            selectSpot(spot)
                        }
                    }
                }
                
                // Tube station markers
                ForEach(spots) { spot in
                    Annotation("", coordinate: spot.nearestTube.coordinate, anchor: .center) {
                        TubeStation3DMarkerView(
                            station: spot.nearestTube,
                            isNearSelected: selectedSpot?.nearestTube.name == spot.nearestTube.name
                        )
                    }
                }
                
                // Walking route if available
                if route != nil {
                    MapPolyline(route!.polyline)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .mapStyle(mapStyle.style)
            .mapControls {
                MapCompass()
                    .mapControlVisibility(.visible)
                MapScaleView()
                MapUserLocationButton()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                // Track camera changes for smooth animations
            }
            
            // Floating controls
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Map style picker
                        Button(action: { showStylePicker.toggle() }) {
                            Image(systemName: mapStyle.icon)
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8)
                        }
                        
                        // 3D toggle
                        Button(action: toggle3DView) {
                            Image(systemName: "cube.fill")
                                .font(.title3)
                                .foregroundColor(mapStyle == .realistic3D ? .blue : .primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8)
                        }
                        
                        // Fly to London overview
                        Button(action: flyToLondonOverview) {
                            Image(systemName: "building.2.crop.circle")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                
                Spacer()
            }
            
            // Style picker overlay
            if showStylePicker {
                VStack {
                    Spacer()
                    
                    MapStylePickerView(
                        selectedStyle: $mapStyle,
                        isPresented: $showStylePicker
                    )
                    .padding(.bottom, selectedSpot != nil ? 220 : 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showStylePicker)
    }
    
    // MARK: - Camera Control
    
    private func selectSpot(_ spot: CalmSpot) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            selectedSpot = spot
            
            // Cinematic camera animation to selected spot
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: spot.coordinate,
                    distance: 800,
                    heading: Double.random(in: 0...360), // Random angle for variety
                    pitch: 70 // High pitch for immersive 3D view
                )
            )
        }
        
        onSpotSelected(spot)
        
        // Calculate route from nearest tube
        calculateWalkingRoute(from: spot.nearestTube.coordinate, to: spot.coordinate)
    }
    
    private func toggle3DView() {
        // Get current camera position for reference
        let londonCenter = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let defaultDistance: Double = 15000
        
        if mapStyle == .realistic3D {
            mapStyle = .standard
            // Flatten the view - set pitch to 0
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: londonCenter,
                        distance: defaultDistance,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
        } else {
            mapStyle = .realistic3D
            // Add 3D perspective - set pitch to 60
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: londonCenter,
                        distance: defaultDistance,
                        heading: 0,
                        pitch: 60
                    )
                )
            }
        }
    }
    
    private func flyToLondonOverview() {
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                    distance: 25000,
                    heading: 0,
                    pitch: 45
                )
            )
            selectedSpot = nil
            route = nil
        }
    }
    
    // MARK: - Route Calculation
    
    private func calculateWalkingRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.route = route
                }
            }
        }
    }
}

// MARK: - 3D Spot Marker

struct Spot3DMarkerView: View {
    let spot: CalmSpot
    let isSelected: Bool
    
    @State private var isHovered = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main marker
            ZStack {
                // Glow effect for selected
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.green.opacity(0.6), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                pulseScale = 1.3
                            }
                        }
                }
                
                // Shadow circle
                Ellipse()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: isSelected ? 40 : 30, height: isSelected ? 12 : 8)
                    .offset(y: isSelected ? 32 : 24)
                    .blur(radius: 3)
                
                // 3D-style marker body
                ZStack {
                    // Outer ring
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    crowdColor.opacity(0.9),
                                    crowdColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isSelected ? 56 : 44, height: isSelected ? 56 : 44)
                        .shadow(color: crowdColor.opacity(0.5), radius: isSelected ? 12 : 6, y: 4)
                    
                    // Inner circle with icon
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    
                    // Icon
                    Image(systemName: spot.systemImage)
                        .font(.system(size: isSelected ? 22 : 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [crowdColor, crowdColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .offset(y: isSelected ? -8 : -4)
            }
            
            // Pin point
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [crowdColor.opacity(0.8), crowdColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 16, height: 12)
                .offset(y: isSelected ? -12 : -6)
            
            // Label (only when selected)
            if isSelected {
                VStack(spacing: 4) {
                    Text(spot.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        // Crowd indicator
                        HStack(spacing: 3) {
                            Circle()
                                .fill(crowdColor)
                                .frame(width: 6, height: 6)
                            Text(spot.crowdLevel.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        
                        Text("•")
                            .font(.system(size: 8))
                        
                        // Walking time
                        HStack(spacing: 2) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 9))
                            Text("\(spot.nearestTube.walkingMinutes)m")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                )
                .offset(y: 8)
            }
        }
        .scaleEffect(isSelected ? 1.0 : 0.85)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
    
    private var crowdColor: Color {
        switch spot.crowdLevel {
        case .quiet: return .green
        case .moderate: return .orange
        case .busy: return .red
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tube Station 3D Marker

struct TubeStation3DMarkerView: View {
    let station: TubeStation
    let isNearSelected: Bool
    
    var body: some View {
        ZStack {
            // London Underground roundel
            Circle()
                .fill(Color.red)
                .frame(width: isNearSelected ? 32 : 24, height: isNearSelected ? 32 : 24)
                .shadow(color: .red.opacity(0.4), radius: isNearSelected ? 8 : 4)
            
            // White bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: isNearSelected ? 28 : 20, height: isNearSelected ? 10 : 7)
            
            // Station initial or icon
            if isNearSelected {
                Text(String(station.name.prefix(1)))
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.blue)
            }
        }
        .overlay(
            // Tube lines indicator
            HStack(spacing: 2) {
                ForEach(station.lines.prefix(3), id: \.self) { line in
                    Circle()
                        .fill(Color(hex: line.color))
                        .frame(width: 6, height: 6)
                }
            }
            .offset(y: isNearSelected ? 22 : 16)
            , alignment: .bottom
        )
        .scaleEffect(isNearSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isNearSelected)
    }
}

// MARK: - Map Style Picker

struct MapStylePickerView: View {
    @Binding var selectedStyle: Map3DView.MapStyleOption
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Map3DView.MapStyleOption.allCases, id: \.self) { style in
                Button(action: {
                    selectedStyle = style
                    isPresented = false
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(selectedStyle == style ? Color.blue : Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: style.icon)
                                .font(.title3)
                                .foregroundColor(selectedStyle == style ? .white : .primary)
                        }
                        
                        Text(style.rawValue)
                            .font(.caption2)
                            .foregroundColor(selectedStyle == style ? .blue : .secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20)
        )
        .padding(.horizontal)
    }
}

/// Detailed spot card overlay
struct SpotDetailCard: View {
    let spot: CalmSpot
    let weather: ParsedWeather?
    let onDismiss: () -> Void
    let onGetDirections: () -> Void
    var onShowFullDetail: (() -> Void)? = nil
    
    @State private var showingFullDescription = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with image
            ZStack(alignment: .topTrailing) {
                // Gradient background with icon
                LinearGradient(
                    colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)
                .overlay {
                    Image(systemName: spot.systemImage)
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                }
                .onTapGesture {
                    onShowFullDetail?()
                }
                
                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Title and crowd level
                HStack {
                    Text(spot.name)
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: spot.crowdLevel.icon)
                        Text(spot.crowdLevel.rawValue)
                    }
                    .font(.caption.bold())
                    .foregroundColor(crowdColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(crowdColor.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // Description
                Text(spot.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(showingFullDescription ? nil : 2)
                    .onTapGesture {
                        withAnimation { showingFullDescription.toggle() }
                    }
                
                // Weather card
                if let weather = weather {
                    WeatherMiniCard(weather: weather)
                }
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(spot.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Divider()
                
                // Tube info
                HStack(spacing: 12) {
                    Image(systemName: "tram.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.nearestTube.name)
                            .font(.subheadline.bold())
                        
                        HStack(spacing: 4) {
                            Text("\(spot.nearestTube.walkingMinutes) min walk")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            // Tube lines
                            ForEach(spot.nearestTube.lines.prefix(3), id: \.self) { line in
                                Text(line.rawValue)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: line.color))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Opening hours
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text(spot.openingHours)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onGetDirections) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    if let onShowFullDetail = onShowFullDetail {
                        Button(action: onShowFullDetail) {
                            Label("More Info", systemImage: "info.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
    
    private var crowdColor: Color {
        switch spot.crowdLevel {
        case .quiet: return .green
        case .moderate: return .orange
        case .busy: return .red
        }
    }
}

/// Mini weather card
struct WeatherMiniCard: View {
    let weather: ParsedWeather
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: weather.condition.icon)
                .font(.title)
                .foregroundColor(weatherColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(weather.temperatureString)
                    .font(.headline)
                Text(weather.condition.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(weather.recommendation)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var weatherColor: Color {
        switch weather.condition.iconColor {
        case "yellow": return .yellow
        case "orange": return .orange
        case "gray": return .gray
        case "blue": return .blue
        case "cyan": return .cyan
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

