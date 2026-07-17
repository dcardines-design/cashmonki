//
//  ChangeStatusSheet.swift
//  CashMonki
//
//  Admin bottom sheet for changing a feedback item's status.
//  Presented via .sheet with a half-height detent, matching AddWalletSheet.
//

import SwiftUI

struct ChangeStatusSheet: View {
    @Binding var isPresented: Bool
    let currentStatus: FeedbackStatus
    let onSave: (FeedbackStatus) -> Void

    @State private var selection: FeedbackStatus

    init(isPresented: Binding<Bool>, currentStatus: FeedbackStatus, onSave: @escaping (FeedbackStatus) -> Void) {
        self._isPresented = isPresented
        self.currentStatus = currentStatus
        self.onSave = onSave
        self._selection = State(initialValue: currentStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader.basic(title: "Change Status") {
                isPresented = false
            }

            // Hugs content — no scroll region, the detent matches this stack's height.
            VStack(spacing: 12) {
                ForEach(FeedbackStatus.allCases, id: \.self) { status in
                    statusRow(status)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)

            FixedBottomGroup.primary(
                title: "Save",
                action: {
                    onSave(selection)
                    isPresented = false
                }
            )
        }
        .background(AppColors.backgroundWhite)
    }

    private func statusRow(_ status: FeedbackStatus) -> some View {
        let isSelected = selection == status
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) { selection = status }
        } label: {
            HStack {
                Text(status.displayName)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accentBackground : AppColors.linePrimary, lineWidth: isSelected ? 0 : 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppColors.accentBackground)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accentBackground.opacity(0.08) : AppColors.backgroundWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accentBackground : AppColors.linePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChangeStatusSheet(isPresented: .constant(true), currentStatus: .pending) { _ in }
}
