//
//  DailyUsageManager.swift
//  CashMonki
//
//  Created by Claude on 12/4/25.
//

import Foundation
import Combine

/// Manages daily usage limits for receipt analysis (upload + scan) and Ask chat.
/// Limits come from the user's PlanTier (see PlanTier.swift):
/// scans Free 3 / Plus 10 / Pro unlimited; Ask Free 3 / Plus 10 / Pro 100 (fair use).
@MainActor
class DailyUsageManager: ObservableObject {
    static let shared = DailyUsageManager()
    
    // MARK: - Constants
    private let usageCountKey = "dailyReceiptAnalysisCount"
    private let lastResetDateKey = "lastUsageResetDate"
    
    // MARK: - Published Properties
    @Published var remainingUsage: Int = 3
    @Published var hasReachedLimit: Bool = false
    
    private init() {
        resetUsageIfNewDay()
        updateRemainingUsage()
        
        // Reset at midnight
        Task {
            await scheduleNextMidnightReset()
        }
    }
    
    // MARK: - Tier

    private var tier: PlanTier { RevenueCatManager.shared.planTier }

    /// Receipt analyses allowed today for the current tier; nil = unlimited.
    var dailyScanLimit: Int? { tier.dailyScanLimit }

    // MARK: - Ask chat limits (same daily-reset pattern; per-tier daily cap)

    private let chatUsageCountKey = "dailyChatMessageCount"

    /// Pro's Ask cap is fair use, so its counter only shows once it's this close.
    private let proChatCounterThreshold = 10

    /// Ask messages allowed today for the current tier.
    var dailyChatLimit: Int { tier.dailyAskLimit }

    func canSendChatMessage() -> Bool {
        resetUsageIfNewDay()
        return UserDefaults.standard.integer(forKey: chatUsageCountKey) < dailyChatLimit
    }

    func recordChatMessage() {
        resetUsageIfNewDay()
        let count = UserDefaults.standard.integer(forKey: chatUsageCountKey) + 1
        UserDefaults.standard.set(count, forKey: chatUsageCountKey)
        print("📊 DailyUsageManager: Chat message \(count)/\(dailyChatLimit) (\(tier.rawValue))")
    }

    func getRemainingChatMessages() -> Int {
        resetUsageIfNewDay()
        return max(0, dailyChatLimit - UserDefaults.standard.integer(forKey: chatUsageCountKey))
    }

    /// "3 messages left today" footer line. Free and Plus always see it; Pro only
    /// near its fair-use cap.
    func getChatUsageDisplayText() -> String {
        let remaining = getRemainingChatMessages()
        if tier == .pro && remaining > proChatCounterThreshold { return "" }
        if remaining <= 0 { return "No messages left today" }
        return remaining == 1 ? "1 message left today" : "\(remaining) messages left today"
    }

    // MARK: - Public Methods
    
    /// Check if user can perform receipt analysis
    func canUseReceiptAnalysis() -> Bool {
        resetUsageIfNewDay()
        
        // Unlimited tiers (Pro)
        guard let limit = dailyScanLimit else {
            return true
        }
        
        // Free/Plus limited to the tier's daily count
        let currentUsage = getCurrentDailyUsage()
        return currentUsage < limit
    }
    
    /// Record a receipt analysis usage
    func recordReceiptAnalysis(isOnboarding: Bool = false) {
        resetUsageIfNewDay()
        
        // Don't count usage for unlimited tiers (Pro)
        guard let limit = dailyScanLimit else {
            return
        }
        
        // Don't count onboarding receipt analysis towards daily limit
        if isOnboarding {
            print("📊 DailyUsageManager: Onboarding receipt analysis - not counting towards daily limit")
            return
        }
        
        let currentUsage = getCurrentDailyUsage()
        let newUsage = currentUsage + 1
        
        UserDefaults.standard.set(newUsage, forKey: usageCountKey)
        
        print("📊 DailyUsageManager: Recorded usage \(newUsage)/\(limit) (\(tier.rawValue))")
        updateRemainingUsage()
    }
    
    /// Get remaining usage count for the day
    func getRemainingUsage() -> Int {
        resetUsageIfNewDay()
        
        // Unlimited tiers (Pro)
        guard let limit = dailyScanLimit else {
            return 999 // Unlimited
        }
        
        let currentUsage = getCurrentDailyUsage()
        return max(0, limit - currentUsage)
    }
    
    /// Get usage count text for UI display
    func getUsageDisplayText() -> String {
        resetUsageIfNewDay()
        
        // Don't show limits for unlimited tiers (Pro)
        if dailyScanLimit == nil {
            return ""
        }
        
        let remaining = getRemainingUsage()
        
        if remaining == 0 {
            return "0 left today"
        } else if remaining == 1 {
            return "1 left today"
        } else {
            return "\(remaining) left today"
        }
    }
    
    /// Check if usage limit modal should be shown
    func shouldShowLimitModal() -> Bool {
        return !canUseReceiptAnalysis() && dailyScanLimit != nil
    }
    
    // MARK: - Private Methods
    
    private func getCurrentDailyUsage() -> Int {
        return UserDefaults.standard.integer(forKey: usageCountKey)
    }
    
    private func resetUsageIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast
        let lastResetDay = Calendar.current.startOfDay(for: lastReset)
        
        if today > lastResetDay {
            // Reset usage for new day
            UserDefaults.standard.set(0, forKey: usageCountKey)
            UserDefaults.standard.set(0, forKey: chatUsageCountKey)
            UserDefaults.standard.set(today, forKey: lastResetDateKey)
            
            print("📊 DailyUsageManager: Reset daily usage for new day: \(today)")
            updateRemainingUsage()
        }
    }
    
    private func updateRemainingUsage() {
        self.remainingUsage = self.getRemainingUsage()
        self.hasReachedLimit = !self.canUseReceiptAnalysis()
    }
    
    private func scheduleNextMidnightReset() async {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let midnight = calendar.startOfDay(for: tomorrow)
        
        let timer = Timer(fireAt: midnight, interval: 0, target: self, selector: #selector(handleMidnightReset), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        
        print("📊 DailyUsageManager: Scheduled next reset for: \(midnight)")
    }
    
    @objc private func handleMidnightReset() {
        print("📊 DailyUsageManager: Midnight reset triggered")
        resetUsageIfNewDay()
        Task {
            await scheduleNextMidnightReset() // Schedule next reset
        }
    }
}

// MARK: - Debug Methods
extension DailyUsageManager {
    /// Public method to reset daily usage (for settings button)
    func resetDailyUsage() {
        debugResetUsage()
    }
    
    /// Debug method to manually reset usage (for testing)
    func debugResetUsage() {
        UserDefaults.standard.set(0, forKey: usageCountKey)
        UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
        updateRemainingUsage()
        print("📊 DailyUsageManager: DEBUG - Manually reset usage")
    }
    
    /// Debug method to simulate usage (for testing)
    func debugAddUsage(_ count: Int = 1) {
        let current = getCurrentDailyUsage()
        UserDefaults.standard.set(current + count, forKey: usageCountKey)
        updateRemainingUsage()
        print("📊 DailyUsageManager: DEBUG - Added \(count) usage, total: \(current + count)")
    }
}