//
//  GrokTubeTests.swift
//  GrokTubeTests
//
//  Created by Kannan Sekar Annu Radha on 25/12/2025.
//

import Testing
import SwiftUI
@testable import GrokTube

struct GrokTubeTests {

    @Test func featuredTicketSpotsLeadWithIconicParks() {
        let names = CalmSpot.featuredTicketSpots.prefix(3).map(\.name)
        #expect(Array(names) == ["Hampstead Heath", "Kew Gardens", "Greenwich Park"])
    }

    @Test func allSpotsIncludeIconicParksAndOriginalCatalogue() {
        let names = Set(CalmSpot.allSpots.map(\.name))
        #expect(names.contains("Hampstead Heath"))
        #expect(names.contains("Kew Gardens"))
        #expect(names.contains("Greenwich Park"))
        #expect(names.contains("Kyoto Garden"))
        #expect(CalmSpot.allSpots.count >= 13)
    }

    @Test func weatherTemperatureShortOmitsCelsius() {
        let weather = ParsedWeather(
            temperature: 12,
            feelsLike: 9,
            humidity: 75,
            condition: .partlyCloudy,
            isDay: false,
            windSpeed: 15,
            precipitation: 0
        )
        #expect(weather.temperatureShort == "12°")
        #expect(weather.temperatureString.contains("C"))
    }

    @Test func floatingTabBarCasesMatchSpec() {
        #expect(AppTab.allCases.map(\.rawValue) == ["Home", "Explore", "Breathe", "About"])
        #expect(AppTab.home.icon == "house.fill")
        #expect(AppTab.map.icon == "map.fill")
        #expect(AppTab.breathe.icon == "wind")
        #expect(AppTab.about.icon == "info.circle.fill")
    }

    @Test func weatherPillPlaceIsHampsteadHeath() {
        #expect(TubeTheme.weatherPillPlace == "Hampstead Heath")
    }
}
