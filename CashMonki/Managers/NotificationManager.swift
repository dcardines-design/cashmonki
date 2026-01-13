//
//  NotificationManager.swift
//  CashMonki
//
//  Created by Claude on 1/8/26.
//

import Foundation
import UserNotifications
import UIKit

/// Permission status for cleaner handling
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

/// Manages local push notifications for expense tracking reminders
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifier = "cashmonki.daily.reminder"

    /// Published permission status for UI observation
    @Published var isAuthorized: Bool = false

    // DEBUG: Set to true to use 1-minute intervals instead of daily
    private let debugMode = false
    private let debugIntervalMinutes: TimeInterval = 1

    // 16 Friendly reminder messages (title, body)
    private let reminderMessages: [(title: String, body: String)] = [
        ("Hey, quick check-in", "Did you spend anything today? Let's log it."),
        ("Expense tracker time", "A minute now saves confusion later."),
        ("Time to track", "Don't let today's spending slip away."),
        ("Stay on top of it", "Log that purchase while it's fresh."),
        ("Small wins matter", "Even tiny expenses add up. Track 'em."),
        ("Log your spending", "Your wallet called. It wants accountability."),
        ("Your future self says thanks", "For tracking expenses today."),
        ("Quick reminder", "Got any receipts hiding in your pocket?"),
        ("Track your expenses", "30 seconds now = zero regrets later."),
        ("Money check-in time", "What left your wallet today?"),
        ("Don't forget to track", "That coffee counts too, you know."),
        ("Expense logging time", "Be the boss of your budget."),
        ("Track it before you forget", "Your memory isn't that good. Trust us."),
        ("Time to log expenses", "Future you will appreciate this."),
        ("Spending tracker alert", "Quick, log it while it's fresh."),
        ("Hey big spender", "Time to track today's expenses.")
    ]

    private override init() {
        super.init()
        // Set delegate to show notifications in foreground
        notificationCenter.delegate = self
        // Check permission status on init
        refreshPermissionStatus()
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 NotificationManager: Showing notification in foreground")
        // Show banner, sound, and badge even when app is active
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 NotificationManager: Notification tapped - \(userInfo)")
        // Handle notification tap here if needed (e.g., navigate to subscription)
        completionHandler()
    }

    /// Refresh the published permission status
    func refreshPermissionStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔔 NotificationManager: Permission error - \(error.localizedDescription)")
                    self?.isAuthorized = false
                    completion(false)
                    return
                }

                self?.isAuthorized = granted
                if granted {
                    print("🔔 NotificationManager: Permission granted")
                } else {
                    print("🔔 NotificationManager: Permission denied (user's choice)")
                }
                completion(granted)
            }
        }
    }

    /// Request permission or open Settings if previously denied
    /// Returns true if permission dialog was shown, false if needs Settings
    func requestPermissionOrOpenSettings(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // First time - show permission dialog
                    self?.requestPermission(completion: completion)

                case .denied:
                    // Previously denied - open Settings
                    print("🔔 NotificationManager: Permission denied, opening Settings")
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                    completion(false)

                case .authorized, .provisional, .ephemeral:
                    // Already authorized
                    self?.isAuthorized = true
                    completion(true)

                @unknown default:
                    completion(false)
                }
            }
        }
    }

    /// Check permission and request if needed, returns status for UI handling
    func checkAndRequestPermission(completion: @escaping (PermissionStatus) -> Void) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // First time - show permission dialog
                    self?.requestPermission { granted in
                        completion(granted ? .granted : .denied)
                    }

                case .denied:
                    // Previously denied - let caller show alert
                    completion(.denied)

                case .authorized, .provisional, .ephemeral:
                    // Already authorized
                    self?.isAuthorized = true
                    completion(.granted)

                @unknown default:
                    completion(.denied)
                }
            }
        }
    }

    /// Check current notification authorization status
    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                let isAuthorized = settings.authorizationStatus == .authorized
                print("🔔 NotificationManager: Authorization status - \(isAuthorized ? "authorized" : "not authorized")")
                completion(isAuthorized)
            }
        }
    }

    // MARK: - Transaction Tracking

    /// Check if user has added any transactions today
    private func hasTransactionsToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let transactions = UserManager.shared.currentUser.transactions
        let todayTransactions = transactions.filter { txn in
            calendar.isDate(txn.date, inSameDayAs: today)
        }

        let hasTransactions = !todayTransactions.isEmpty
        print("🔔 NotificationManager: Transactions today: \(todayTransactions.count) - \(hasTransactions ? "skipping reminder" : "will remind")")
        return hasTransactions
    }

    // MARK: - Scheduling

    /// Schedule the daily reminder notification (only if no transactions today)
    func scheduleDailyReminder() {
        // Skip if user already tracked today
        if hasTransactionsToday() {
            print("🔔 NotificationManager: User already tracked today - no reminder needed")
            cancelAllReminders()
            return
        }

        // First check/request permission
        requestPermission { [weak self] granted in
            guard granted, let self = self else {
                print("🔔 NotificationManager: Cannot schedule - no permission")
                return
            }

            // Cancel existing reminders before scheduling new one
            self.cancelAllReminders()

            // Pick a random message
            let message = self.reminderMessages.randomElement() ?? self.reminderMessages[0]

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.badge = 1

            // Create trigger based on mode
            let trigger: UNNotificationTrigger

            if self.debugMode {
                // DEBUG: Fire every 3 minutes
                trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: self.debugIntervalMinutes * 60,
                    repeats: true
                )
                print("🔔 NotificationManager: DEBUG MODE - Scheduling every \(Int(self.debugIntervalMinutes)) minutes")
            } else {
                // PRODUCTION: Random time between 12PM - 7PM (non-repeating, re-scheduled on app launch)
                let randomHour = Int.random(in: 12...18) // 12PM to 6PM (will fire before 7PM)
                let randomMinute = Int.random(in: 0...59)

                var dateComponents = DateComponents()
                dateComponents.hour = randomHour
                dateComponents.minute = randomMinute

                // Use repeats: false so each day gets a new random message when app re-schedules
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )
                print("🔔 NotificationManager: Scheduling for today at \(randomHour):\(String(format: "%02d", randomMinute))")
            }

            // Create request
            let request = UNNotificationRequest(
                identifier: self.reminderIdentifier,
                content: content,
                trigger: trigger
            )

            // Schedule
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("🔔 NotificationManager: Failed to schedule - \(error.localizedDescription)")
                } else {
                    print("🔔 NotificationManager: Reminder scheduled successfully!")
                    print("🔔 NotificationManager: Message - \"\(message.title): \(message.body)\"")
                }
            }
        }
    }

    /// Cancel all reminder notifications
    func cancelAllReminders() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [reminderIdentifier])
        print("🔔 NotificationManager: All reminders cancelled")
    }

    /// Call this when user adds a transaction - cancels today's reminder since they tracked
    func onTransactionAdded() {
        print("🔔 NotificationManager: Transaction added - cancelling today's reminder")
        cancelAllReminders()
    }

    /// Clear the badge count
    func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("🔔 NotificationManager: Failed to clear badge - \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Subscription Reminders

    /// Friendly subscription reminder messages (title uses {name} placeholder)
    private let subscriptionReminderMessages: [(title: String, body: String)] = [
        ("💸 {name} is coming up", "Your payment is due soon. Ready for it?"),
        ("📅 Heads up: {name}", "Subscription charge incoming soon."),
        ("🔔 {name} reminder", "Payment coming up. Make sure you're covered."),
        ("⚡ {name} due soon", "Your recurring charge is almost here."),
        ("💳 {name} alert", "Subscription renewing soon. Heads up!"),
        ("🎯 Don't forget: {name}", "This charge is sneaking up on you."),
        ("📢 {name} heads up", "Your wallet wants you to know: payment soon."),
        ("💰 {name} incoming", "Recurring payment approaching. Just a heads up!"),
        ("🚨 {name} reminder", "Time to prep for your upcoming subscription."),
        ("✨ {name} is almost due", "Just a friendly nudge about your payment.")
    ]

    /// Schedule a reminder notification for a subscription
    /// - Parameters:
    ///   - subscriptionId: Unique ID for this subscription
    ///   - subscriptionName: Name to show in notification (e.g., "Netflix")
    ///   - dueDate: When the subscription payment is due
    ///   - reminderInterval: How far before the due date to remind (in seconds)
    func scheduleSubscriptionReminder(
        subscriptionId: UUID,
        subscriptionName: String,
        dueDate: Date,
        reminderInterval: TimeInterval
    ) {
        // Check permission directly (not cached value) and schedule
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            guard settings.authorizationStatus == .authorized else {
                print("🔔 NotificationManager: Cannot schedule subscription reminder - not authorized (status: \(settings.authorizationStatus.rawValue))")
                return
            }

            // Calculate when to fire the notification
            let reminderDate = dueDate.addingTimeInterval(-reminderInterval)

            // Don't schedule if reminder time has already passed
            guard reminderDate > Date() else {
                print("🔔 NotificationManager: Reminder time already passed for '\(subscriptionName)' - skipping")
                return
            }

            // Pick a random message and replace placeholder
            var message = self.subscriptionReminderMessages.randomElement() ?? self.subscriptionReminderMessages[0]
            message.title = message.title.replacingOccurrences(of: "{name}", with: subscriptionName)

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.badge = 1
            content.userInfo = ["subscriptionId": subscriptionId.uuidString]

            // Create time-based trigger
            let timeInterval = reminderDate.timeIntervalSinceNow
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, timeInterval), // Minimum 1 second
                repeats: false
            )

            // Create request with unique identifier
            let identifier = "subscription_reminder_\(subscriptionId.uuidString)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            // Schedule
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("🔔 NotificationManager: Failed to schedule subscription reminder - \(error.localizedDescription)")
                } else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d 'at' h:mm:ss a"
                    print("🔔 NotificationManager: Scheduled reminder for '\(subscriptionName)' at \(formatter.string(from: reminderDate))")
                    print("   Title: \(message.title)")
                    print("   Body: \(message.body)")
                    print("   Fires in: \(Int(timeInterval)) seconds")
                }
            }
        }
    }

    /// Cancel a specific subscription reminder
    func cancelSubscriptionReminder(subscriptionId: UUID) {
        let identifier = "subscription_reminder_\(subscriptionId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        print("🔔 NotificationManager: Cancelled reminder for subscription \(subscriptionId)")
    }

    /// Cancel all subscription reminders
    func cancelAllSubscriptionReminders() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let subscriptionIdentifiers = requests
                .filter { $0.identifier.hasPrefix("subscription_reminder_") }
                .map { $0.identifier }

            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: subscriptionIdentifiers)
            self?.notificationCenter.removeDeliveredNotifications(withIdentifiers: subscriptionIdentifiers)
            print("🔔 NotificationManager: Cancelled \(subscriptionIdentifiers.count) subscription reminders")
        }
    }

    // MARK: - Debug

    /// List all pending notifications (for debugging)
    func listPendingNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            print("🔔 NotificationManager: Pending notifications (\(requests.count)):")
            for request in requests {
                print("   - ID: \(request.identifier)")
                print("     Title: \(request.content.title)")
                print("     Trigger: \(String(describing: request.trigger))")
            }
        }
    }
}
