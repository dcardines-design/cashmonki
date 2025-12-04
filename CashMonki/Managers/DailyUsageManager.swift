//
//  DailyUsageManager.swift
//  CashMonki
//
//  Created by Claude on 12/4/25.
//

import Foundation
import Combine

/// Manages daily usage limits for receipt analysis (upload + scan)
/// Free users get 3 daily analyses, Pro users get unlimited
@MainActor
class DailyUsageManager: ObservableObject {
    static let shared = DailyUsageManager()
    
    // MARK: - Constants
    private let maxDailyUsageForFreeUsers = 3
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
    
    // MARK: - Public Methods
    
    /// Check if user can perform receipt analysis
    func canUseReceiptAnalysis() -> Bool {
        resetUsageIfNewDay()
        
        // Pro users get unlimited usage
        if RevenueCatManager.shared.isProUser {
            return true
        }
        
        // Free users limited to daily count
        let currentUsage = getCurrentDailyUsage()
        return currentUsage < maxDailyUsageForFreeUsers
    }
    
    /// Record a receipt analysis usage
    func recordReceiptAnalysis() {
        resetUsageIfNewDay()
        
        // Don't count usage for Pro users
        if RevenueCatManager.shared.isProUser {
            return
        }
        
        let currentUsage = getCurrentDailyUsage()
        let newUsage = currentUsage + 1
        
        UserDefaults.standard.set(newUsage, forKey: usageCountKey)
        
        print("📊 DailyUsageManager: Recorded usage \(newUsage)/\(maxDailyUsageForFreeUsers)")
        updateRemainingUsage()
    }
    
    /// Get remaining usage count for the day
    func getRemainingUsage() -> Int {
        resetUsageIfNewDay()
        
        // Pro users have unlimited
        if RevenueCatManager.shared.isProUser {
            return 999 // Unlimited
        }
        
        let currentUsage = getCurrentDailyUsage()
        return max(0, maxDailyUsageForFreeUsers - currentUsage)
    }
    
    /// Get usage count text for UI display
    func getUsageDisplayText() -> String {
        resetUsageIfNewDay()
        
        // Don't show limits for Pro users
        if RevenueCatManager.shared.isProUser {
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
        return !canUseReceiptAnalysis() && !RevenueCatManager.shared.isProUser
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