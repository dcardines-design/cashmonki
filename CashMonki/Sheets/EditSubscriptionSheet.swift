//
//  EditSubscriptionSheet.swift
//  CashMonki
//
//  Sheet for editing existing recurring transactions/subscriptions
//

import SwiftUI

struct EditSubscriptionSheet: View {
    let subscription: Subscription
    @Binding var isPresented: Bool
    let onSave: ((Subscription) -> Void)?
    let onDelete: ((Subscription) -> Void)?

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var userManager = UserManager.shared

    // Form State
    @State private var merchantName: String
    @State private var amountText: String
    @State private var selectedCurrency: Currency
    @State private var selectedCategoryId: UUID?
    @State private var selectedCategoryName: String
    @State private var frequency: RecurringFrequency
    @State private var isActive: Bool
    @State private var autoAddTransaction: Bool
    @State private var reminderEnabled: Bool
    @State private var reminderDays: ReminderDays
    @State private var note: String

    // UI State
    @State private var showingCurrencyPicker = false
    @State private var showingNotificationAlert = false
    @State private var showingDeleteConfirmation = false

    @FocusState private var isMerchantFocused: Bool
    @FocusState private var isAmountFocused: Bool

    init(subscription: Subscription, isPresented: Binding<Bool>, onSave: ((Subscription) -> Void)? = nil, onDelete: ((Subscription) -> Void)? = nil) {
        self.subscription = subscription
        self._isPresented = isPresented
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state from subscription
        self._merchantName = State(initialValue: subscription.name)
        self._amountText = State(initialValue: String(format: "%.0f", subscription.amount))
        self._selectedCurrency = State(initialValue: subscription.currency)
        self._selectedCategoryId = State(initialValue: subscription.categoryId)
        self._selectedCategoryName = State(initialValue: subscription.category)
        self._frequency = State(initialValue: subscription.frequency)
        self._isActive = State(initialValue: subscription.isActive)
        self._autoAddTransaction = State(initialValue: subscription.autoAddTransaction)
        self._reminderEnabled = State(initialValue: subscription.reminderEnabled)
        self._reminderDays = State(initialValue: ReminderDays(rawValue: subscription.reminderDaysBefore) ?? .one)
        self._note = State(initialValue: subscription.note ?? "")
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !merchantName.isEmpty && parsedAmount > 0 && selectedCategoryId != nil
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    /// Get all transactions generated from this subscription
    private var generatedTransactions: [Txn] {
        userManager.currentUser.transactions
            .filter { $0.subscriptionId == subscription.id }
    }

    /// Calculate next due date based on current frequency (from now)
    private var calculatedNextDueDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: now) ?? now
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: now) ?? now
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with delete button
            SheetHeader.withCustomAction(
                title: "Edit Recurring Transaction",
                onBackTap: {
                    isPresented = false
                },
                rightIcon: "trash-04",
                rightSystemIcon: "trash",
                onRightTap: {
                    showingDeleteConfirmation = true
                }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Merchant Input
                    AppInputField.text(
                        title: "Merchant",
                        text: $merchantName,
                        placeholder: "Netflix, Spotify, Grab, etc.",
                        size: .md,
                        focusBinding: $isMerchantFocused
                    )

                    // Amount Input
                    AppInputField.amount(
                        text: $amountText,
                        selectedCurrency: Binding(
                            get: { selectedCurrency.rawValue },
                            set: { _ in }
                        ),
                        onCurrencyTap: {
                            showingCurrencyPicker = true
                        },
                        size: .md,
                        focusBinding: $isAmountFocused
                    )

                    // Category Picker (shows both expense AND income categories)
                    AppInputField.recurringCategory(
                        selectedCategoryId: $selectedCategoryId,
                        selectedCategoryName: $selectedCategoryName,
                        size: .md
                    )

                    // Optional Note
                    AppInputField.text(
                        title: "Note (optional)",
                        text: $note,
                        placeholder: "Add context or description",
                        size: .md
                    )

                    // MARK: - Is Active Section (Hidden for future use)
                    // isActiveSection

                    // Frequency Selection
                    frequencySection

                    // MARK: - Auto Add Section (Hidden for future use)
                    // autoAddSection

                    // Reminder Section
                    reminderSection

                    // Reminder Days Section (separate container, hidden when reminder is off)
                    if reminderEnabled {
                        reminderDaysSection
                            .transition(.opacity)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .animation(.easeInOut(duration: 0.2), value: reminderEnabled)
            }

            // Fixed bottom button
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.linePrimary)

                AppButton(
                    title: "Save Changes",
                    action: saveSubscription,
                    hierarchy: .primary,
                    size: .extraSmall,
                    isEnabled: isFormValid
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerSheet(
                primaryCurrency: $selectedCurrency,
                isPresented: $showingCurrencyPicker
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
        .alert("Notifications Disabled", isPresented: $showingNotificationAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive reminders before charges, please enable notifications in Settings.")
        }
        .alert("Delete Subscription", isPresented: $showingDeleteConfirmation) {
            Button("Delete Future", role: .destructive) {
                // Delete subscription only, keep existing transactions
                onDelete?(subscription)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }
            Button("Delete All", role: .destructive) {
                // Delete subscription AND all generated transactions
                deleteSubscriptionWithTransactions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(generatedTransactions.count) past transaction\(generatedTransactions.count == 1 ? "" : "s") from this subscription. Keep them in your history or delete everything?")
        }
    }

    // MARK: - Delete with Transactions

    private func deleteSubscriptionWithTransactions() {
        // First delete all generated transactions
        for txn in generatedTransactions {
            userManager.removeTransaction(withId: txn.id)
        }
        print("🗑️ EditSubscriptionSheet: Deleted \(generatedTransactions.count) generated transactions")

        // Then delete the subscription
        onDelete?(subscription)
    }

    // MARK: - Is Active Section (Hidden for future use)
    // Uncomment when ready to enable pause/resume functionality
    /*
    private var isActiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Is this active?")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            HStack(spacing: 8) {
                selectionChip(label: "Yes", isSelected: isActive) {
                    isActive = true
                }
                selectionChip(label: "No", isSelected: !isActive) {
                    isActive = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    */

    // MARK: - Frequency Section

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How often does this repeat?")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            FlowLayout(spacing: 8) {
                selectionChip(label: "Daily", isSelected: frequency == .daily) {
                    frequency = .daily
                }
                selectionChip(label: "Weekly", isSelected: frequency == .weekly) {
                    frequency = .weekly
                }
                selectionChip(label: "Monthly", isSelected: frequency == .monthly) {
                    frequency = .monthly
                }
                selectionChip(label: "Quarterly", isSelected: frequency == .quarterly) {
                    frequency = .quarterly
                }
                selectionChip(label: "Yearly", isSelected: frequency == .yearly) {
                    frequency = .yearly
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Auto-add Section (Hidden for future use)
    // Uncomment when ready to enable auto-add toggle
    /*
    private var autoAddSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add this as a transaction when due?")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            HStack(spacing: 8) {
                selectionChip(label: "Yes", isSelected: autoAddTransaction) {
                    autoAddTransaction = true
                }
                selectionChip(label: "No", isSelected: !autoAddTransaction) {
                    autoAddTransaction = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    */

    // MARK: - Reminder Section

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Remind before charge?")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)

                if !notificationManager.isAuthorized {
                    Text("(Your notifications are off)")
                        .font(AppFonts.overusedGroteskMedium(size: 12))
                        .foregroundColor(AppColors.foregroundTertiary)
                }
            }

            HStack(spacing: 8) {
                selectionChip(label: "Yes", isSelected: reminderEnabled) {
                    // Check notification permission when enabling
                    notificationManager.checkAndRequestPermission { status in
                        switch status {
                        case .granted:
                            reminderEnabled = true
                        case .denied:
                            showingNotificationAlert = true
                        case .notDetermined:
                            break
                        }
                    }
                }
                .opacity(notificationManager.isAuthorized ? 1.0 : 0.5)

                selectionChip(label: "No", isSelected: !reminderEnabled) {
                    reminderEnabled = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            notificationManager.refreshPermissionStatus()
        }
    }

    // MARK: - Reminder Days Section

    private var reminderDaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No. of days before reminder")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            FlowLayout(spacing: 8) {
                selectionChip(label: "12 hrs", isSelected: reminderDays == .twelveHours) {
                    reminderDays = .twelveHours
                }
                selectionChip(label: "1 day", isSelected: reminderDays == .one) {
                    reminderDays = .one
                }
                selectionChip(label: "3 days", isSelected: reminderDays == .three) {
                    reminderDays = .three
                }
                selectionChip(label: "5 days", isSelected: reminderDays == .five) {
                    reminderDays = .five
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Selection Chip Helper

    private func selectionChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                action()
            }
        }) {
            Text(label)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(isSelected ? AppColors.primary : AppColors.foregroundSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color(red: 0.33, green: 0.18, blue: 1).opacity(0.1) : Color.clear)
                .background(isSelected ? .white : AppColors.surfacePrimary)
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func saveSubscription() {
        // Determine next due date
        // If frequency changed, use calculated date; otherwise keep existing
        let nextDue = (frequency != subscription.frequency) ? calculatedNextDueDate : subscription.nextDueDate

        // Create updated subscription preserving the original ID and createdAt
        let updatedSubscription = Subscription(
            id: subscription.id,
            name: merchantName,
            amount: parsedAmount,
            currency: selectedCurrency,
            categoryId: selectedCategoryId,
            category: selectedCategoryName.isEmpty ? "Subscriptions" : selectedCategoryName,
            frequency: frequency,
            nextDueDate: nextDue,
            reminderEnabled: reminderEnabled,
            reminderDaysBefore: reminderDays.rawValue,
            autoAddTransaction: autoAddTransaction,
            isActive: isActive,
            walletId: subscription.walletId,
            note: note.isEmpty ? nil : note,
            createdAt: subscription.createdAt,
            lastGeneratedDate: subscription.lastGeneratedDate
        )

        // Note: SubscriptionManager.updateSubscription is called by the parent view's onEdit callback
        // This allows the parent to show confirmation dialogs before actually saving

        // Track analytics
        AnalyticsManager.shared.track(.subscriptionEdited, properties: [
            "name": merchantName,
            "amount": parsedAmount,
            "currency": selectedCurrency.rawValue,
            "frequency": frequency.rawValue,
            "is_active": isActive
        ])

        onSave?(updatedSubscription)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    EditSubscriptionSheet(
        subscription: Subscription(
            name: "Netflix",
            amount: 549,
            currency: .php,
            category: "Entertainment",
            frequency: .monthly,
            nextDueDate: Date(),
            reminderEnabled: true,
            reminderDaysBefore: 3
        ),
        isPresented: .constant(true),
        onSave: { subscription in
            print("Updated subscription: \(subscription.name)")
        }
    )
}
