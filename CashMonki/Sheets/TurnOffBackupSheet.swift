//
//  TurnOffBackupSheet.swift
//  CashMonki
//
//  Confirmation shown before cloud backup is switched OFF (Figma 1714-8158). Turning backup
//  ON needs no confirmation, so this is only presented on the off path.
//
//  Every bullet here is checked against what the flag actually gates: transactions
//  (UserManager.pushTransactionToCloud), categories (CategoriesManager), and subscriptions
//  (SubscriptionManager) all stop uploading, local data is untouched, and the existing cloud
//  copy is kept rather than deleted. Receipt analysis is NOT gated — it still posts images to
//  OpenRouter — hence the last bullet.
//

import SwiftUI

struct TurnOffBackupSheet: View {
    @Binding var isPresented: Bool

    /// Called only when the user confirms. Dismissing any other way leaves backup ON.
    let onConfirm: () -> Void

    /// Emoji per bullet so each consequence reads at a glance instead of as four grey lines.
    private static let bullets = [
        ("📱", "Your data stays on this phone, but stops backing up"),
        ("☁️", "Your existing backup stays, but won’t update"),
        ("🙈", "Lose this phone and new data is gone"),
        ("🤖", "Receipt scans still go to our AI provider")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: "Turn off cloud backup?") {
                isPresented = false
            }

            // Figma 1714-8160 "options": 30pt padding, 20pt gap, centred.
            VStack(spacing: 20) {
                emojiBadge

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What will happen:")
                            .font(AppFonts.overusedGroteskSemiBold(size: 20))
                            .foregroundColor(AppColors.foregroundPrimary)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Self.bullets, id: \.1) { emoji, bullet in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(emoji)
                                        .font(AppFonts.overusedGroteskMedium(size: 20))

                                    Text(bullet)
                                        .font(AppFonts.overusedGroteskMedium(size: 20))
                                        .foregroundColor(AppColors.foregroundSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    warningCallout
                }
            }
            .padding(30)

            Spacer(minLength: 0)

            actions
        }
        .background(AppColors.backgroundWhite)
    }

    /// Figma 1714-8282: 100pt circle on #f3f5f8 with a 60pt emoji.
    private var emojiBadge: some View {
        Text("🤔")
            .font(AppFonts.overusedGroteskMedium(size: 60))
            .frame(width: 100, height: 100)
            .background(AppColors.surfacePrimary)
            .clipShape(Circle())
    }

    /// Figma 1714-8272: #ef4444 at 9%, radius 8, 18pt sides / 16pt vertical.
    private var warningCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image("alert-circle")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(AppColors.destructiveForeground)

                Text("Warning")
                    .font(AppFonts.overusedGroteskMedium(size: 12))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(AppColors.destructiveForeground)
            }

            Text("If you lose or reset this phone, new data can’t be recovered.")
                .font(AppFonts.overusedGroteskMedium(size: 18))
                .foregroundColor(AppColors.destructiveForeground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(AppColors.destructiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Figma 1714-8164: divider, then the destructive action above the safe one so "keep
    /// backing up" is the button under the thumb.
    private var actions: some View {
        FixedBottomGroup.destructiveThenPrimary(
            destructiveTitle: "Turn off backup",
            destructiveAction: {
                isPresented = false
                onConfirm()
            },
            primaryTitle: "Keep backing up",
            primaryAction: { isPresented = false }
        )
    }
}
