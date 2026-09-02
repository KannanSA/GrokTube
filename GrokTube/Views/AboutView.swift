//
//  AboutView.swift
//  GrokTube
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                UndergroundRoundel(size: 110)
                    .padding(.top, 36)

                VStack(spacing: 8) {
                    Text("Your calm companion")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted)
                    Text("Night London · hidden gardens · Ani")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted.opacity(0.8))
                }

                VStack(spacing: 6) {
                    Text("Built with care by")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(TubeTheme.creamMuted)
                    Text("Kannan Sekar Annu Radha")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(TubeTheme.cream)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(TubeTheme.charcoal)
                )
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Text("Connect")
                        .tubeJohnstonCaption()
                        .foregroundStyle(TubeTheme.creamMuted)

                    aboutLink(
                        icon: "globe",
                        title: "Website",
                        subtitle: "www.sakannan.com",
                        url: "https://www.sakannan.com"
                    )
                    aboutLink(
                        icon: "at",
                        title: "Twitter / X",
                        subtitle: "@SAKannanAI",
                        url: "https://twitter.com/SAKannanAI"
                    )
                }
                .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(TubeTheme.creamMuted)
                    Text("Powered by Ani")
                        .font(.caption)
                        .foregroundStyle(TubeTheme.creamMuted)
                }
                .padding(.top, 8)

                Spacer(minLength: 120)
            }
        }
        .background(TubeTheme.nightGradient.ignoresSafeArea())
    }

    private func aboutLink(icon: String, title: String, subtitle: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(TubeTheme.undergroundRed)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(TubeTheme.cream)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(TubeTheme.creamMuted)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(TubeTheme.creamMuted)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TubeTheme.charcoal)
            )
        }
    }
}

#Preview {
    AboutView()
        .preferredColorScheme(.dark)
}
