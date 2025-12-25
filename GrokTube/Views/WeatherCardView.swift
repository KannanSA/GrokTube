//
//  WeatherCardView.swift
//  GrokTube
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import SwiftUI

/// Beautiful weather card with animations
struct WeatherCardView: View {
    let weather: ParsedWeather?
    let isLoading: Bool
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                LoadingWeatherCard()
            } else if let weather = weather {
                WeatherContent(weather: weather, showingDetails: $showingDetails)
            } else {
                ErrorWeatherCard()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct WeatherContent: View {
    let weather: ParsedWeather
    @Binding var showingDetails: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("London Weather")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(weather.temperatureString)
                        .font(.system(size: 42, weight: .thin))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Animated weather icon
                WeatherIconView(condition: weather.condition, isDay: weather.isDay)
                    .frame(width: 60, height: 60)
            }
            
            // Condition
            Text(weather.condition.description)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(weather.feelsLikeString)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Stats row
            HStack(spacing: 20) {
                WeatherStat(icon: "humidity.fill", value: "\(weather.humidity)%", label: "Humidity")
                WeatherStat(icon: "wind", value: String(format: "%.0f km/h", weather.windSpeed), label: "Wind")
                if weather.precipitation > 0 {
                    WeatherStat(icon: "drop.fill", value: String(format: "%.1f mm", weather.precipitation), label: "Rain")
                }
            }
            
            // Recommendation
            Text(weather.recommendation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
    }
}

struct WeatherStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.caption.bold())
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

struct WeatherIconView: View {
    let condition: WeatherCondition
    let isDay: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(iconColor.opacity(0.2))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Icon
            Image(systemName: condition.icon)
                .font(.system(size: 36))
                .foregroundStyle(iconGradient)
                .symbolEffect(.pulse, options: .repeating, value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private var iconColor: Color {
        switch condition.iconColor {
        case "yellow": return .yellow
        case "orange": return .orange
        case "gray": return .gray
        case "blue": return .blue
        case "cyan": return .cyan
        case "purple": return .purple
        default: return .blue
        }
    }
    
    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [iconColor, iconColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct LoadingWeatherCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 12)
            }
            
            Spacer()
        }
        .padding()
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

struct ErrorWeatherCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather unavailable")
                    .font(.subheadline.bold())
                
                Text("Check your connection")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    VStack(spacing: 20) {
        WeatherCardView(
            weather: ParsedWeather(
                temperature: 12,
                feelsLike: 9,
                humidity: 75,
                condition: .partlyCloudy,
                isDay: true,
                windSpeed: 15,
                precipitation: 0
            ),
            isLoading: false
        )
        .frame(maxWidth: 350)
        
        WeatherCardView(weather: nil, isLoading: true)
            .frame(maxWidth: 350)
        
        WeatherCardView(weather: nil, isLoading: false)
            .frame(maxWidth: 350)
    }
    .padding()
}
