//
//  RecurringActionConfirmationSheet.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

// MARK: - Recurring Action Types

enum RecurringActionType {
    case editTemplate          // Editing a parent template
    case deleteTemplate        // Deleting a parent template
    case deleteGeneratedChild  // Deleting a generated child transaction
}

// MARK: - Action Options

enum RecurringEditOption {
    case thisOnly              // Apply changes to this template only
    case allFuture             // Apply to all future occurrences
    case allPastAndFuture      // Apply to all past and future occurrences
}

enum RecurringDeleteTemplateOption {
    case subscriptionOnly      // Delete template, children become standalone
    case allOccurrences        // Delete template and all generated children
}

enum RecurringDeleteChildOption {
    case thisOnly              // Delete just this occurrence
    case stopAllFuture         // Delete this + deactivate parent (stop future)
}

// MARK: - Confirmation Sheet

struct RecurringActionConfirmationSheet: View {
    @Binding var isPresented: Bool
    let actionType: RecurringActionType
    let transaction: Txn
    let onEditOptionSelected: ((RecurringEditOption) -> Void)?
    let onDeleteTemplateOptionSelected: ((RecurringDeleteTemplateOption) -> Void)?
    let onDeleteChildOptionSelected: ((RecurringDeleteChildOption) -> Void)?

    init(
        isPresented: Binding<Bool>,
        actionType: RecurringActionType,
        transaction: Txn,
        onEditOptionSelected: ((RecurringEditOption) -> Void)? = nil,
        onDeleteTemplateOptionSelected: ((RecurringDeleteTemplateOption) -> Void)? = nil,
        onDeleteChildOptionSelected: ((RecurringDeleteChildOption) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.actionType = actionType
        self.transaction = transaction
        self.onEditOptionSelected = onEditOptionSelected
        self.onDeleteTemplateOptionSelected = onDeleteTemplateOptionSelected
        self.onDeleteChildOptionSelected = onDeleteChildOptionSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(title: headerTitle) {
                isPresented = false
            }

            VStack(spacing: 16) {
                // Icon and description
                VStack(spacing: 12) {
                    iconView

                    Text(descriptionText)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                // Options list
                VStack(spacing: 12) {
                    switch actionType {
                    case .editTemplate:
                        editTemplateOptions
                    case .deleteTemplate:
                        deleteTemplateOptions
                    case .deleteGeneratedChild:
                        deleteChildOptions
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()
            }
        }
        .background(AppColors.backgroundWhite)
    }

    // MARK: - Header Title

    private var headerTitle: String {
        switch actionType {
        case .editTemplate:
            return "Edit Recurring Transaction"
        case .deleteTemplate:
            return "Delete Subscription"
        case .deleteGeneratedChild:
            return "Delete Occurrence"
        }
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        let isDestructive = actionType != .editTemplate

        ZStack {
            Circle()
                .fill(isDestructive ? AppColors.accentRed.opacity(0.1) : AppColors.accentBackground.opacity(0.1))
                .frame(width: 64, height: 64)

            Image(systemName: isDestructive ? "trash.circle.fill" : "pencil.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(isDestructive ? AppColors.accentRed : AppColors.accentBackground)
        }
    }

    // MARK: - Description Text

    private var descriptionText: String {
        switch actionType {
        case .editTemplate:
            return "This is a recurring transaction. How would you like to apply your changes?"
        case .deleteTemplate:
            return "This will affect the subscription and its generated transactions."
        case .deleteGeneratedChild:
            return "This transaction was generated from a recurring subscription."
        }
    }

    // MARK: - Edit Template Options

    @ViewBuilder
    private var editTemplateOptions: some View {
        OptionRow(
            title: "Apply to this only",
            subtitle: "Changes will only affect the subscription template",
            isDestructive: false
        ) {
            onEditOptionSelected?(.thisOnly)
            isPresented = false
        }

        OptionRow(
            title: "All future occurrences",
            subtitle: "Changes will apply to this and all future generated transactions",
            isDestructive: false
        ) {
            onEditOptionSelected?(.allFuture)
            isPresented = false
        }

        OptionRow(
            title: "All past & future",
            subtitle: "Changes will apply to all existing and future transactions",
            isDestructive: false
        ) {
            onEditOptionSelected?(.allPastAndFuture)
            isPresented = false
        }
    }

    // MARK: - Delete Template Options

    @ViewBuilder
    private var deleteTemplateOptions: some View {
        OptionRow(
            title: "Delete subscription only",
            subtitle: "Stop future generations. Existing transactions become standalone.",
            isDestructive: false
        ) {
            onDeleteTemplateOptionSelected?(.subscriptionOnly)
            isPresented = false
        }

        OptionRow(
            title: "Delete all occurrences",
            subtitle: "Remove this subscription and all generated transactions",
            isDestructive: true
        ) {
            onDeleteTemplateOptionSelected?(.allOccurrences)
            isPresented = false
        }
    }

    // MARK: - Delete Child Options

    @ViewBuilder
    private var deleteChildOptions: some View {
        OptionRow(
            title: "Delete this occurrence only",
            subtitle: "Remove only this transaction. Future generations continue.",
            isDestructive: false
        ) {
            onDeleteChildOptionSelected?(.thisOnly)
            isPresented = false
        }

        OptionRow(
            title: "Stop all future occurrences",
            subtitle: "Delete this and deactivate the recurring subscription",
            isDestructive: true
        ) {
            onDeleteChildOptionSelected?(.stopAllFuture)
            isPresented = false
        }
    }
}

// MARK: - Option Row Component

private struct OptionRow: View {
    let title: String
    let subtitle: String
    let isDestructive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(isDestructive ? AppColors.accentRed : AppColors.foregroundPrimary)

                Text(subtitle)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfacePrimary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDestructive ? AppColors.accentRed.opacity(0.3) : AppColors.linePrimary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    RecurringActionConfirmationSheet(
        isPresented: .constant(true),
        actionType: .editTemplate,
        transaction: Txn(
            txID: UUID(),
            accountID: UUID(),
            walletID: UUID(),
            category: "Subscriptions",
            categoryId: nil,
            amount: -9.99,
            date: Date(),
            createdAt: Date(),
            receiptImage: nil,
            hasReceiptImage: false,
            merchantName: "Netflix",
            paymentMethod: nil,
            receiptNumber: nil,
            invoiceNumber: nil,
            items: [],
            note: nil,
            originalAmount: nil,
            originalCurrency: nil,
            primaryCurrency: .usd,
            secondaryCurrency: nil,
            exchangeRate: nil,
            secondaryAmount: nil,
            secondaryExchangeRate: nil,
            isRecurring: true,
            recurringFrequency: .monthly,
            recurringTemplateId: nil,
            lastGeneratedDate: nil,
            isRecurringActive: true
        ),
        onEditOptionSelected: { option in
            print("Selected: \(option)")
        }
    )
}
