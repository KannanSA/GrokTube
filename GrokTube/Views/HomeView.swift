//
//  HomeView.swift
//  GrokTube
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var voiceManager: VoiceManager
    @Binding var transcript: String
    @Binding var weather: ParsedWeather?
    @Binding var isLoadingWeather: Bool
    @Binding var selectedSpot: CalmSpot?
    @Binding var showSpotDetail: Bool
    var onShowWeatherDetail: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                header

                VoiceOrbView(voiceManager: voiceManager, transcript: $transcript)

                if let spot = voiceManager.suggestedSpot {
                    TicketRowView(spot: spot, badge: "Ani suggests", isHighlighted: true) {
                        selectedSpot = spot
                        showSpotDetail = true
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                ticketsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(TubeTheme.nightGradient.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            UndergroundRoundel(size: 64)
            Spacer(minLength: 8)
            WeatherPillView(
                weather: weather,
                isLoading: isLoadingWeather,
                onTap: onShowWeatherDetail
            )
        }
    }

    private var ticketsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calm spots")
                    .tubeJohnstonCaption()
                    .foregroundStyle(TubeTheme.creamMuted)
                Spacer()
                Button {
                    if let randomSpot = CalmSpot.allSpots.randomElement() {
                        selectedSpot = randomSpot
                        showSpotDetail = true
                    }
                } label: {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TubeTheme.creamMuted)
                        .padding(8)
                        .background(Circle().fill(TubeTheme.mist))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Random calm spot")
            }

            ForEach(CalmSpot.featuredTicketSpots) { spot in
                TicketRowView(spot: spot) {
                    selectedSpot = spot
                    showSpotDetail = true
                }
            }
        }
    }
}
