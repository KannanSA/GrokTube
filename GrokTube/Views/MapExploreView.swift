//
//  MapExploreView.swift
//  GrokTube
//
//  Full-bleed dark MapKit of London with a search pill and Nearby calm sheet.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapExploreView: View {
    @Binding var selectedSpot: CalmSpot?
    @Binding var showSpotDetail: Bool
    @Binding var cameraPosition: MapCameraPosition
    let weather: ParsedWeather?

    @State private var searchQuery = ""
    @FocusState private var searchFocused: Bool

    private var filteredSpots: [CalmSpot] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let spots = CalmSpot.featuredTicketSpots
        guard !query.isEmpty else { return spots }
        return spots.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.nearestTube.name.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map3DView(
                selectedSpot: $selectedSpot,
                cameraPosition: $cameraPosition,
                spots: CalmSpot.allSpots
            ) { _ in }
            .colorScheme(.dark)
            .ignoresSafeArea()

            LinearGradient(
                colors: [TubeTheme.night.opacity(0.72), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                searchPill
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer()

                NearbyCalmSheet(
                    spots: filteredSpots,
                    selectedSpot: $selectedSpot,
                    onSelect: { spot in
                        selectedSpot = spot
                    },
                    onShowDetail: { spot in
                        selectedSpot = spot
                        showSpotDetail = true
                    }
                )
                .padding(.bottom, 78)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TubeTheme.creamMuted)

            TextField("Search calm spots", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(TubeTheme.cream)
                .focused($searchFocused)
                .submitLabel(.search)

            if let weather {
                Text(weather.temperatureShort)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TubeTheme.sage)
            }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TubeTheme.creamMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            Capsule(style: .continuous)
                .fill(TubeTheme.charcoal.opacity(0.94))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(TubeTheme.cream.opacity(0.12), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        )
        .accessibilityLabel("Search calm spots")
    }
}
