//
//  Map3DView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI
import MapKit

/// Beautiful 3D Map View with custom annotations
struct Map3DView: View {
    @Binding var selectedSpot: CalmSpot?
    @Binding var cameraPosition: MapCameraPosition
    @State private var showRoute = false
    @State private var route: MKRoute?
    
    let spots: [CalmSpot]
    let onSpotSelected: (CalmSpot) -> Void
    
    var body: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // User location
            UserAnnotation()
            
            // Park markers
            ForEach(spots) { spot in
                Annotation(spot.name, coordinate: spot.coordinate) {
                    SpotMarkerView(spot: spot, isSelected: selectedSpot?.id == spot.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedSpot = spot
                                onSpotSelected(spot)
                                
                                // Animate camera to spot
                                cameraPosition = .camera(
                                    MapCamera(
                                        centerCoordinate: spot.coordinate,
                                        distance: 1000,
                                        heading: 45,
                                        pitch: 60
                                    )
                                )
                            }
                        }
                }
            }
            
            // Tube station markers
            ForEach(spots) { spot in
                Annotation("🚇 \(spot.nearestTube.name)", coordinate: spot.nearestTube.coordinate) {
                    TubeStationMarkerView(station: spot.nearestTube)
                }
            }
            
            // Route polyline if available
            if let route = route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .including([.park, .museum, .nationalPark])))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
            MapPitchToggle()
        }
    }
}

/// Custom marker for calm spots
struct SpotMarkerView: View {
    let spot: CalmSpot
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                    .shadow(color: .green.opacity(0.4), radius: isSelected ? 10 : 5)
                
                Image(systemName: spot.systemImage)
                    .font(.system(size: isSelected ? 24 : 18))
                    .foregroundColor(.white)
            }
            
            // Pin tail
            Image(systemName: "triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
                .rotationEffect(.degrees(180))
                .offset(y: -4)
            
            if isSelected {
                Text(spot.name)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .offset(y: 4)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

/// Custom marker for tube stations
struct TubeStationMarkerView: View {
    let station: TubeStation
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 24, height: 24)
            
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
            
            Text("🚇")
                .font(.system(size: 12))
        }
    }
}

/// Detailed spot card overlay
struct SpotDetailCard: View {
    let spot: CalmSpot
    let weather: ParsedWeather?
    let onDismiss: () -> Void
    let onGetDirections: () -> Void
    
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
