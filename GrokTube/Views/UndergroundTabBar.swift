//
//  UndergroundTabBar.swift
//  GrokTube
//
//  Custom floating tab bar — not the system green TabView.
//

import SwiftUI

struct UndergroundTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .symbolVariant(selectedTab == tab ? .fill : .none)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .fontWidth(.condensed)
                            .tracking(0.4)
                    }
                    .foregroundStyle(selectedTab == tab ? TubeTheme.undergroundRed : TubeTheme.creamMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(TubeTheme.charcoal.opacity(0.96))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(TubeTheme.cream.opacity(0.10), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.55), radius: 22, y: 10)
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }
}

#Preview {
    ZStack {
        TubeTheme.night.ignoresSafeArea()
        VStack {
            Spacer()
            UndergroundTabBar(selectedTab: .constant(.home))
        }
    }
}
