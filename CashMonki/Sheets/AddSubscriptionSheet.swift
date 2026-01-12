//
//  AddSubscriptionSheet.swift
//  CashMonki
//
//  Sheet for adding new recurring transactions/subscriptions
//

import SwiftUI

struct AddSubscriptionSheet: View {
    @Binding var isPresented: Bool
    let onSave: ((Subscription) -> Void)?

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    // Form State
    @State private var merchantName: String = ""
    @State private var amountText: String = ""
    @State private var selectedCurrency: Currency
    @State private var selectedCategoryId: UUID?
    @State private var selectedCategoryName: String = ""
    @State private var dateAdded: Date = Date()
    @State private var frequency: RecurringFrequency = .monthly
    // @State private var isActive: Bool = true  // Hidden for future use - always true for now
    private let isActive: Bool = true  // Subscriptions are always active when created
    // @State private var autoAddTransaction: Bool = true  // Hidden for future use - always true for now
    private let autoAddTransaction: Bool = true  // Always auto-add transactions when due
    @State private var reminderEnabled: Bool = true
    @State private var reminderDays: ReminderDays = .one
    @State private var note: String = ""

    // UI State
    @State private var showingCurrencyPicker = false
    @State private var showingNotificationAlert = false
    @State private var showingPaywall = false

    @FocusState private var isMerchantFocused: Bool
    @FocusState private var isAmountFocused: Bool

    init(isPresented: Binding<Bool>, onSave: ((Subscription) -> Void)? = nil) {
        self._isPresented = isPresented
        self.onSave = onSave
        self._selectedCurrency = State(initialValue: CurrencyPreferences.shared.primaryCurrency)
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !merchantName.isEmpty && parsedAmount > 0
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(title: "Add Recurring Transaction") {
                isPresented = false
            }

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

                    // Category Picker (shows both expense AND income categories for recurring transactions)
                    AppInputField.recurringCategory(
                        selectedCategoryId: $selectedCategoryId,
                        selectedCategoryName: $selectedCategoryName,
                        size: .md
                    )

                    // Start Date with Time (first billing date) - cannot be in future
                    AppInputField.date(
                        title: "Start Date",
                        dateValue: $dateAdded,
                        components: [.date, .hourAndMinute],
                        size: .md,
                        maxDate: Date()
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
                    title: "Save",
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isMerchantFocused = true
            }
        }
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
        .fullScreenCover(isPresented: $showingPaywall) {
            CustomPaywallSheet(isPresented: $showingPaywall)
        }
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

            // First row: Daily, Weekly, Monthly, Quarterly
            HStack(spacing: 8) {
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
            }

            // Second row: Yearly, 5 Minutes (for testing)
            HStack(spacing: 8) {
                selectionChip(label: "Yearly", isSelected: frequency == .yearly) {
                    frequency = .yearly
                }
                selectionChip(label: "5 Min", isSelected: frequency == .fiveMinutes) {
                    frequency = .fiveMinutes
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
            Text("Remind before charge?")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

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
                selectionChip(label: "No", isSelected: !reminderEnabled) {
                    reminderEnabled = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reminder Days Section

    private var reminderDaysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No. of days before reminder")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)

            HStack(spacing: 8) {
                selectionChip(label: "5 sec", isSelected: reminderDays == .testSeconds) {
                    reminderDays = .testSeconds
                }
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

    /// Calculate the next due date based on frequency from the start date
    private func calculateNextDueDate(from startDate: Date) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .fiveMinutes:
            return calendar.date(byAdding: .minute, value: 5, to: startDate) ?? startDate
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        }
    }

    private func saveSubscription() {
        // Check if user can add more subscriptions (Pro users unlimited, free users limited to 2)
        if !subscriptionManager.canAddMoreSubscriptions {
            showingPaywall = true
            return
        }

        // Calculate next due date based on frequency from the start date
        let nextDue = calculateNextDueDate(from: dateAdded)

        let subscription = Subscription(
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
            walletId: AccountManager.shared.currentSubAccount?.id,
            note: note.isEmpty ? nil : note,
            createdAt: dateAdded // Use dateAdded as the start/created date
        )

        // Add to SubscriptionManager
        SubscriptionManager.shared.addSubscription(subscription)

        // Track analytics
        AnalyticsManager.shared.track(.subscriptionCreated, properties: [
            "name": merchantName,
            "amount": parsedAmount,
            "currency": selectedCurrency.rawValue,
            "frequency": frequency.rawValue,
            "is_active": isActive,
            "auto_add": autoAddTransaction,
            "reminder_enabled": reminderEnabled
        ])

        onSave?(subscription)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    AddSubscriptionSheet(
        isPresented: .constant(true),
        onSave: { subscription in
            print("New subscription: \(subscription.name) - \(subscription.amount)")
        }
    )
}
