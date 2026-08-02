//
//  DataBoxPickerSheet.swift
//  CashMonki
//
//  Lets a signed-in user pick which local data box on this device to attach to their
//  account. The chosen box's transactions/wallets/subscriptions are re-keyed to the
//  login's Firebase UID and uploaded to the cloud (non-destructive union).
//

import SwiftUI

struct DataBoxPickerSheet: View {
    @Binding var isPresented: Bool

    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject var toastManager: ToastManager

    @State private var boxes: [LocalDataBox] = []
    @State private var connectingUID: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: "Upload local data") {
                isPresented = false
            }

            if boxes.isEmpty {
                // Sits in the middle of whatever the header leaves behind, not pinned under it.
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    // Figma 1711-7253 "options": 20pt sides + bottom (no top padding — the
                    // header supplies that), 24pt gap, centered intro, 16pt tile stack.
                    VStack(spacing: 24) {
                        Text(Self.introCopy)
                            .font(AppFonts.overusedGroteskMedium(size: 18))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            ForEach(boxes) { box in
                                boxRow(box)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(AppColors.backgroundWhite)
        .presentationDetents([.fraction(0.7)])
        .onAppear { boxes = userManager.availableLocalDataBoxes() }
    }

    private static let introCopy = "Choose data on this phone to attach to your account. It’s uploaded and backed up."

    /// Figma 1713-7674: grey disk, 22pt heading, the same intro copy underneath. 20pt stack gap,
    /// 6pt between the two lines, 20pt sides / 24pt vertical padding.
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image("data-box-empty")
                .resizable()
                .frame(width: 67, height: 70)

            VStack(spacing: 6) {
                Text("No local data yet")
                    .font(AppFonts.overusedGroteskSemiBold(size: 22))
                    .foregroundColor(AppColors.foregroundPrimary)
                Text(Self.introCopy)
                    .font(AppFonts.overusedGroteskMedium(size: 18))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    /// Figma tile (1711-7570): white card, 1pt #dce2f4 border, radius 12, hard 0/4 shadow in the
    /// same line colour. Row is 20pt gap, 28pt horizontal / 20pt vertical padding.
    private func boxRow(_ box: LocalDataBox) -> some View {
        Button(action: { if !box.isLinked { connect(box) } }) {
            HStack(spacing: 20) {
                // Exported from Figma (node 1711-7573). 56 × 58 keeps the disk's designed
                // drop-shadow bleed instead of squaring it off at the 54.36 leaf size.
                Image("data-box-disk")
                    .resizable()
                    .frame(width: 56, height: 58)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(box.name.isEmpty ? (box.email.isEmpty ? "Untitled data" : box.email) : box.name)
                            .font(AppFonts.overusedGroteskSemiBold(size: 20))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .lineLimit(1)

                        if box.isLinked { linkedBadge }
                    }

                    HStack(spacing: 6) {
                        Text("\(box.transactionCount) transaction\(box.transactionCount == 1 ? "" : "s")")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                        Circle()
                            .fill(AppColors.foregroundSecondary)
                            .frame(width: 3, height: 3)
                        Text("\(box.walletCount) wallet\(box.walletCount == 1 ? "" : "s")")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }

                    // Figma 1711-7638: 9pt Medium, 0.9 tracking, uppercase, #72788a.
                    Text(box.isLinked
                         ? "Updates automatically · \(LocalDataBox.relativeAge(box.updatedAt))"
                         : "Last update \(LocalDataBox.relativeAge(box.updatedAt))")
                        .font(AppFonts.overusedGroteskMedium(size: 9))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if connectingUID == box.uid {
                    ProgressView()
                        .frame(width: 24, height: 24)
                } else if box.isLinked {
                    // Nothing to do: it's already attached and mirrors the account automatically.
                    EmptyView()
                } else {
                    Image("chevron-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            // Figma's `drop-shadow 0 4 0 #dce2f4` drawn as an explicit offset slab. Using
            // .shadow(radius: 0) instead renders a halo above the card, because SwiftUI
            // shadows the composited layer (fill + 1pt stroke) rather than the fill alone.
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.linePrimary)
                        .offset(y: 4)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.backgroundWhite)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppColors.linePrimary, lineWidth: 1)
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(connectingUID != nil)
    }

    /// Compact age for the tile's "LAST UPDATE …" line — 45m / 3h / 2d / 1w, matching Figma's copy.
    /// Status pill on a box that is already attached to this account.
    private var linkedBadge: some View {
        Text("LINKED")
            .font(AppFonts.overusedGroteskMedium(size: 9))
            .tracking(0.9)
            .foregroundColor(AppColors.foregroundPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.surfacePrimary)
            .clipShape(Capsule())
    }

    private func connect(_ box: LocalDataBox) {
        connectingUID = box.uid
        userManager.connectLocalBox(sourceUID: box.uid) { success in
            DispatchQueue.main.async {
                connectingUID = nil
                if success {
                    toastManager.showSuccess("Uploaded \(box.transactionCount) transaction\(box.transactionCount == 1 ? "" : "s") to your account")
                    isPresented = false
                } else {
                    toastManager.showError("Couldn’t upload that data. Try again.")
                }
            }
        }
    }
}
