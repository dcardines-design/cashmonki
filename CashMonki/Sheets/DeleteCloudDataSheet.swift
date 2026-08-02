//
//  DeleteCloudDataSheet.swift
//  CashMonki
//
//  Confirmation for "Delete cloud data" in Settings → Data. This wipes the account's copy in
//  Firebase and leaves this phone's data alone, which makes it the repair tool for a cloud copy
//  that has gone wrong: wipe it, then let this device push its data back up as the new truth.
//
//  Copy matches what the code actually does — FirestoreService.deleteAllUserData removes the
//  transactions subcollection, receipt images, legacy top-level docs, the user document, and the
//  categories / subscriptions / ask_chat / meta leaf documents. The account itself is NOT deleted
//  (that lives in Delete Account), and nothing local is touched.
//

import SwiftUI

struct DeleteCloudDataSheet: View {
    @Binding var isPresented: Bool

    /// Called only on confirm. Any other dismissal leaves the cloud copy alone.
    let onConfirm: () -> Void

    /// Emoji per bullet so each consequence reads at a glance, matching TurnOffBackupSheet.
    private static let bullets = [
        ("🗑️", "Your backup is erased from our servers"),
        ("📱", "Data on this phone is untouched"),
        ("👤", "You stay signed in, your account isn’t deleted"),
        ("⬆️", "With backup on, this phone re-uploads its data")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: "Delete cloud data?") {
                isPresented = false
            }

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

    private var emojiBadge: some View {
        Text("🗑️")
            .font(AppFonts.overusedGroteskMedium(size: 60))
            .frame(width: 100, height: 100)
            .background(AppColors.surfacePrimary)
            .clipShape(Circle())
    }

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

            Text("This can’t be undone. Anything only in the cloud, added on your other devices, is gone.")
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

    /// Destructive above the safe action, matching TurnOffBackupSheet — "Keep my backup" sits
    /// under the thumb.
    private var actions: some View {
        FixedBottomGroup.destructiveThenPrimary(
            destructiveTitle: "Delete cloud data",
            destructiveAction: {
                isPresented = false
                onConfirm()
            },
            primaryTitle: "Keep my backup",
            primaryAction: { isPresented = false }
        )
    }
}
