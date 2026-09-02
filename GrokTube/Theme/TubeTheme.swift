//
//  TubeTheme.swift
//  GrokTube
//
//  Night-London visual system: charcoal, Underground roundel red, sage glow.
//

import SwiftUI

/// London Underground–inspired palette and type for GrokTube.
enum TubeTheme {
    /// Deep charcoal night sky over London.
    static let night = Color(red: 0.07, green: 0.07, blue: 0.08)
    /// Raised charcoal for cards and the floating tab bar.
    static let charcoal = Color(red: 0.12, green: 0.12, blue: 0.13)
    /// Ticket / sheet surface, slightly lighter than charcoal.
    static let ticket = Color(red: 0.16, green: 0.16, blue: 0.17)
    /// Hairline and bar-ring black.
    static let ink = Color(red: 0.05, green: 0.05, blue: 0.05)
    /// TfL roundel / Central line red — the app accent (not system green).
    static let undergroundRed = Color(red: 0.890, green: 0.125, blue: 0.090)
    /// Sage glow for the voice orb and breathing circle.
    static let sage = Color(red: 0.62, green: 0.73, blue: 0.58)
    static let sageDeep = Color(red: 0.38, green: 0.50, blue: 0.40)
    /// Cream progress track, roundel disc, ticket type.
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let creamMuted = Color(red: 0.78, green: 0.74, blue: 0.68)
    static let mist = Color.white.opacity(0.08)

    static let weatherPillPlace = "Hampstead Heath"

    static var nightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.09, blue: 0.10),
                night,
                Color(red: 0.05, green: 0.05, blue: 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case map = "Explore"
    case breathe = "Breathe"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .map: return "map.fill"
        case .breathe: return "wind"
        case .about: return "info.circle.fill"
        }
    }
}

extension Font {
    /// Condensed Johnston-like display face using system type (no custom font file).
    static func tubeDisplay(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func tubeBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func tubeJohnstonCaption() -> some View {
        font(.system(size: 11, weight: .semibold, design: .default))
            .fontWidth(.condensed)
            .tracking(2.6)
            .textCase(.uppercase)
    }

    func tubeFloatingChrome() -> some View {
        background(
            Capsule(style: .continuous)
                .fill(TubeTheme.charcoal.opacity(0.92))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(TubeTheme.cream.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
    }
}

extension ParsedWeather {
    /// Compact temperature for the home weather pill, e.g. "12°".
    var temperatureShort: String {
        String(format: "%.0f°", temperature)
    }
}
