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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    Text("Choose the data on this phone to attach to your account. It’s uploaded and backed up — nothing on your account is removed.")
                        .font(Font.custom("Overused Grotesk", size: 15).weight(.medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if boxes.isEmpty {
                        Text("No other data found on this device.")
                            .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                            .foregroundColor(AppColors.foregroundSecondary)
                            .padding(.top, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(boxes) { box in
                                boxRow(box)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .background(AppColors.backgroundWhite)
        .presentationDetents([.fraction(0.7)])
        .onAppear { boxes = userManager.availableLocalDataBoxes() }
    }

    private var header: some View {
        ZStack {
            Text("Connect device data")
                .font(Font.custom("Overused Grotesk", size: 20).weight(.semibold))
                .foregroundColor(AppColors.foregroundPrimary)
            HStack {
                Button(action: { isPresented = false }) {
                    Image("chevron-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundPrimary)
                }
                Spacer()
            }
        }
        .padding(20)
    }

    private func boxRow(_ box: LocalDataBox) -> some View {
        Button(action: { connect(box) }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(box.name.isEmpty ? (box.email.isEmpty ? "Untitled data" : box.email) : box.name)
                        .font(Font.custom("Overused Grotesk", size: 17).weight(.semibold))
                        .foregroundColor(AppColors.foregroundPrimary)
                    Text("\(box.transactionCount) transaction\(box.transactionCount == 1 ? "" : "s") · \(box.walletCount) wallet\(box.walletCount == 1 ? "" : "s") · \(Self.dateFormatter.string(from: box.updatedAt))")
                        .font(Font.custom("Overused Grotesk", size: 13).weight(.medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                Spacer()
                if connectingUID == box.uid {
                    ProgressView()
                } else {
                    Image("chevron-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
            .padding(16)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.linePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(connectingUID != nil)
    }

    private func connect(_ box: LocalDataBox) {
        connectingUID = box.uid
        userManager.connectLocalBox(sourceUID: box.uid) { success in
            DispatchQueue.main.async {
                connectingUID = nil
                if success {
                    toastManager.showSuccess("Connected \(box.transactionCount) transaction\(box.transactionCount == 1 ? "" : "s") to your account")
                    isPresented = false
                } else {
                    toastManager.showError("Couldn’t connect that data. Try again.")
                }
            }
        }
    }
}
