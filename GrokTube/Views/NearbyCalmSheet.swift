//
//  NearbyCalmSheet.swift
//  GrokTube
//
//  Citymapper-style bottom sheet listing nearby calm spots with walk-time chips.
//

import SwiftUI

struct NearbyCalmSheet: View {
    let spots: [CalmSpot]
    @Binding var selectedSpot: CalmSpot?
    var onSelect: (CalmSpot) -> Void
    var onShowDetail: (CalmSpot) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isExpanded = false

    private let collapsedHeight: CGFloat = 220
    private let expandedHeight: CGFloat = 460

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(TubeTheme.cream.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            HStack(alignment: .firstTextBaseline) {
                Text("Nearby calm")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .fontWidth(.condensed)
                    .foregroundStyle(TubeTheme.cream)
                Spacer()
                Text("\(spots.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(TubeTheme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(TubeTheme.cream))
            }
            .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(spots) { spot in
                        nearbyRow(spot)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: (isExpanded ? expandedHeight : collapsedHeight) - dragOffset)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24,
                style: .continuous
            )
            .fill(TubeTheme.charcoal.opacity(0.97))
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24,
                    style: .continuous
                )
                .stroke(TubeTheme.cream.opacity(0.10), lineWidth: 0.6)
            }
            .shadow(color: .black.opacity(0.45), radius: 24, y: -8)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = min(80, max(-80, value.translation.height))
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        if value.translation.height < -40 {
                            isExpanded = true
                        } else if value.translation.height > 40 {
                            isExpanded = false
                        }
                        dragOffset = 0
                    }
                }
        )
    }

    private func nearbyRow(_ spot: CalmSpot) -> some View {
        let selected = selectedSpot?.name == spot.name
        return Button {
            onSelect(spot)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(TubeTheme.undergroundRed)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(spot.name)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .fontWidth(.condensed)
                        .foregroundStyle(TubeTheme.cream)
                    Text(spot.nearestTube.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted)
                }

                Spacer()

                WalkTimeChip(minutes: spot.nearestTube.walkingMinutes)

                Button {
                    onShowDetail(spot)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TubeTheme.creamMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? TubeTheme.ticket : TubeTheme.night.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}
