//
//  TicketRowView.swift
//  GrokTube
//
//  Oyster / paper-ticket rows with a red left stripe.
//

import SwiftUI

struct TicketRowView: View {
    let spot: CalmSpot
    var badge: String? = nil
    var isHighlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(TubeTheme.undergroundRed)
                    .frame(width: 5)

                VStack(alignment: .leading, spacing: 6) {
                    if let badge {
                        Text(badge)
                            .tubeJohnstonCaption()
                            .foregroundStyle(TubeTheme.undergroundRed)
                    }

                    Text(spot.name)
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .fontWidth(.condensed)
                        .foregroundStyle(TubeTheme.cream)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label(spot.nearestTube.name, systemImage: "tram.fill")
                        Label("\(spot.nearestTube.walkingMinutes) min", systemImage: "figure.walk")
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(TubeTheme.creamMuted)
                    .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                Spacer(minLength: 8)

                WalkTimeChip(minutes: spot.nearestTube.walkingMinutes)
                    .padding(.trailing, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHighlighted ? TubeTheme.ticket : TubeTheme.charcoal)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isHighlighted ? TubeTheme.undergroundRed.opacity(0.45) : TubeTheme.cream.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spot.name), \(spot.nearestTube.walkingMinutes) minute walk from \(spot.nearestTube.name)")
    }
}

struct WalkTimeChip: View {
    let minutes: Int

    var body: some View {
        Text("\(minutes) min")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(TubeTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(TubeTheme.cream))
    }
}

#Preview {
    ZStack {
        TubeTheme.night.ignoresSafeArea()
        VStack(spacing: 12) {
            ForEach(CalmSpot.featuredTicketSpots.prefix(3)) { spot in
                TicketRowView(spot: spot, onTap: {})
            }
        }
        .padding()
    }
}
