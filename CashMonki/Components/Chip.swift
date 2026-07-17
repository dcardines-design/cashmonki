//
//  Chip.swift
//  CashMonki
//
//  Small reusable label chip (optional leading icon + text) matching the Figma
//  spec: 4pt spacing, 8×6 padding, 4pt corner radius. Colors are supplied by
//  the caller so it can back status chips, tags, and similar labels.
//

import SwiftUI

struct Chip: View {
    let title: String
    /// untitledui asset name (rendered via AppIcon, recolored by `foreground`).
    var iconAsset: String? = nil
    /// SF Symbol fallback used when the asset isn't present.
    var iconFallback: String = "circle"
    let foreground: Color
    let background: Color
    var fontSize: CGFloat = 13
    var iconSize: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if let iconAsset {
                AppIcon(assetName: iconAsset, fallbackSystemName: iconFallback, size: iconSize)
            }
            Text(title)
                .font(AppFonts.overusedGroteskMedium(size: fontSize))
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background)
        .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 12) {
        Chip(title: "Pending", iconAsset: "clock", iconFallback: "clock",
             foreground: AppColors.foregroundSecondary, background: AppColors.statusPendingBackground)
        Chip(title: "In progress", iconAsset: "tool-01", iconFallback: "wrench.fill",
             foreground: AppColors.statusInProgressForeground, background: AppColors.statusInProgressBackground)
        Chip(title: "Done", iconAsset: "check", iconFallback: "checkmark",
             foreground: AppColors.statusDoneForeground, background: AppColors.statusDoneBackground)
    }
    .padding()
    .background(AppColors.surfacePrimary)
}
