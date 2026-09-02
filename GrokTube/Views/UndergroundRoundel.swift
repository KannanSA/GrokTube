//
//  UndergroundRoundel.swift
//  GrokTube
//
//  Black-ring Underground roundel with a red GROK bar and TUBE · LONDON caption.
//

import SwiftUI

struct UndergroundRoundel: View {
    var size: CGFloat = 72
    var wordmark: String = "GROK"
    var caption: String = "TUBE · LONDON"
    var showsCaption: Bool = true

    var body: some View {
        VStack(spacing: size * 0.10) {
            ZStack {
                Circle()
                    .fill(TubeTheme.cream)
                    .frame(width: size, height: size)

                Circle()
                    .strokeBorder(TubeTheme.ink, lineWidth: size * 0.13)
                    .frame(width: size, height: size)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(TubeTheme.undergroundRed)
                    .frame(width: size * 1.24, height: size * 0.24)
                    .shadow(color: TubeTheme.undergroundRed.opacity(0.4), radius: 3, y: 1)

                Text(wordmark)
                    .font(.system(size: max(9, size * 0.17), weight: .heavy, design: .default))
                    .fontWidth(.condensed)
                    .tracking(size * 0.04)
                    .foregroundStyle(TubeTheme.cream)
            }
            .frame(width: size * 1.24, height: size)

            if showsCaption {
                Text(caption)
                    .tubeJohnstonCaption()
                    .foregroundStyle(TubeTheme.creamMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grok Tube London")
    }
}

#Preview {
    ZStack {
        TubeTheme.night.ignoresSafeArea()
        HStack(spacing: 32) {
            UndergroundRoundel(size: 56)
            UndergroundRoundel(size: 96)
        }
    }
}
