//
//  RecurringSubscriptionCard.swift
//  CashMonki
//
//  Card component for configuring recurring/subscription settings
//

import SwiftUI

// MARK: - Reminder Days Option

enum ReminderDays: Int, CaseIterable {
    case twelveHours = -1  // 12 hours before (using -1 to distinguish from days)
    case one = 1
    case three = 3
    case five = 5

    var displayName: String {
        switch self {
        case .twelveHours: return "12 hrs before"
        case .one: return "1 day before"
        case .three: return "3 days before"
        case .five: return "5 days before"
        }
    }

    /// Time interval in seconds for notification scheduling
    var timeIntervalBeforeDue: TimeInterval {
        switch self {
        case .twelveHours: return 12 * 60 * 60  // 12 hours
        case .one: return 1 * 24 * 60 * 60  // 1 day
        case .three: return 3 * 24 * 60 * 60  // 3 days
        case .five: return 5 * 24 * 60 * 60  // 5 days
        }
    }
}

// MARK: - Recurring Subscription Card

struct RecurringSubscriptionCard: View {
    @Binding var isEnabled: Bool
    @Binding var autoAddTransaction: Bool
    @Binding var frequency: RecurringFrequency
    @Binding var remindBeforeCharge: Bool
    @Binding var reminderDays: ReminderDays

    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var showNotificationAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle Header
            HStack {
                Text("Track as recurring or subscription")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accentBackground))
                    .labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Divider
            Rectangle()
                .fill(AppColors.linePrimary)
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Expandable content
            if isEnabled {
                VStack(alignment: .leading, spacing: 20) {
                    // Auto-add transaction toggle
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add this as a transaction when due")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)

                        HStack(spacing: 8) {
                            TabChip(title: "Yes", isSelected: autoAddTransaction) {
                                autoAddTransaction = true
                            }
                            TabChip(title: "No", isSelected: !autoAddTransaction) {
                                autoAddTransaction = false
                            }
                        }
                    }

                    // Frequency selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How often does this repeat?")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)

                        FlowLayout(spacing: 8) {
                            TabChip(title: "Daily", isSelected: frequency == .daily) {
                                frequency = .daily
                            }
                            TabChip(title: "Weekly", isSelected: frequency == .weekly) {
                                frequency = .weekly
                            }
                            TabChip(title: "Monthly", isSelected: frequency == .monthly) {
                                frequency = .monthly
                            }
                            TabChip(title: "Quarterly", isSelected: frequency == .quarterly) {
                                frequency = .quarterly
                            }
                            TabChip(title: "Yearly", isSelected: frequency == .yearly) {
                                frequency = .yearly
                            }
                        }
                    }

                    // Reminder toggle
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Remind before charge?")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)

                            if !notificationManager.isAuthorized {
                                Text("(Your notifications are off)")
                                    .font(AppFonts.overusedGroteskMedium(size: 12))
                                    .foregroundColor(AppColors.foregroundTertiary)
                            }
                        }

                        HStack(spacing: 8) {
                            TabChip(title: "Yes", isSelected: remindBeforeCharge) {
                                // Check notification permission when enabling
                                notificationManager.checkAndRequestPermission { status in
                                    switch status {
                                    case .granted:
                                        remindBeforeCharge = true
                                    case .denied:
                                        showNotificationAlert = true
                                    case .notDetermined:
                                        // Dialog shown, wait for result
                                        break
                                    }
                                }
                            }
                            .opacity(notificationManager.isAuthorized ? 1.0 : 0.5)

                            TabChip(title: "No", isSelected: !remindBeforeCharge) {
                                remindBeforeCharge = false
                            }
                        }
                    }
                    .onAppear {
                        // Refresh notification status when card appears
                        notificationManager.refreshPermissionStatus()
                    }

                    // Reminder days selection (only show if reminder is enabled)
                    if remindBeforeCharge {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No. of days before reminder")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)

                            FlowLayout(spacing: 8) {
                                ForEach(ReminderDays.allCases, id: \.rawValue) { option in
                                    TabChip(title: option.displayName, isSelected: reminderDays == option) {
                                        reminderDays = option
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .background(AppColors.backgroundWhite)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .animation(.easeInOut(duration: 0.2), value: remindBeforeCharge)
        .alert("Notifications Disabled", isPresented: $showNotificationAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive reminders before charges, please enable notifications in Settings.")
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.surfacePrimary.ignoresSafeArea()

        VStack(spacing: 20) {
            RecurringSubscriptionCard(
                isEnabled: .constant(true),
                autoAddTransaction: .constant(true),
                frequency: .constant(.weekly),
                remindBeforeCharge: .constant(true),
                reminderDays: .constant(.one)
            )

            RecurringSubscriptionCard(
                isEnabled: .constant(false),
                autoAddTransaction: .constant(false),
                frequency: .constant(.monthly),
                remindBeforeCharge: .constant(false),
                reminderDays: .constant(.three)
            )
        }
        .padding(20)
    }
}
