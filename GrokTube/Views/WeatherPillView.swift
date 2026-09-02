//
//  WeatherPillView.swift
//  GrokTube
//
//  Compact night-London weather pill, e.g. "12° Hampstead Heath".
//

import SwiftUI

struct WeatherPillView: View {
    let weather: ParsedWeather?
    let isLoading: Bool
    var place: String = TubeTheme.weatherPillPlace
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(TubeTheme.cream)
                        .scaleEffect(0.7)
                    Text("London")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted)
                } else if let weather {
                    Image(systemName: weather.condition.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TubeTheme.sage)
                    Text("\(weather.temperatureShort) \(place)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(TubeTheme.cream)
                        .lineLimit(1)
                } else {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TubeTheme.creamMuted)
                    Text(place)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(TubeTheme.charcoal.opacity(0.92))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(TubeTheme.cream.opacity(0.10), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let weather {
            return "\(weather.temperatureShort) at \(place), \(weather.condition.description)"
        }
        return place
    }
}

#Preview {
    ZStack {
        TubeTheme.night.ignoresSafeArea()
        WeatherPillView(
            weather: ParsedWeather(
                temperature: 12,
                feelsLike: 9,
                humidity: 75,
                condition: .partlyCloudy,
                isDay: false,
                windSpeed: 15,
                precipitation: 0
            ),
            isLoading: false
        )
    }
}
