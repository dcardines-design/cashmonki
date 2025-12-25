//
//  BudgetManager.swift
//  CashMonki
//
//  Created by Claude on 12/24/25.
//

import Foundation
import SwiftUI

class BudgetManager: ObservableObject {
    static let shared = BudgetManager()

    private let userManager = UserManager.shared
    private let categoriesManager = CategoriesManager.shared

    private init() {}

    // MARK: - Budget Queries

    /// Get all budgets for the currently selected wallet
    var budgetsForSelectedWallet: [Budget] {
        guard let selectedWalletId = AccountManager.shared.selectedSubAccountId else {
            return []
        }
        return userManager.currentUser.budgets.filter { $0.walletId == selectedWalletId && $0.isActive }
    }

    /// Get all active budgets
    var allActiveBudgets: [Budget] {
        return userManager.currentUser.budgets.filter { $0.isActive }
    }

    /// Find budget for a specific category in a wallet
    func budget(for categoryId: UUID, in walletId: UUID) -> Budget? {
        return userManager.currentUser.budgets.first {
            $0.categoryId == categoryId && $0.walletId == walletId && $0.isActive
        }
    }

    // MARK: - Spent Amount Calculations

    /// Get spent amount for a budget in the current period
    func spentAmount(for budget: Budget) -> Double {
        let periodRange = currentPeriodRange(for: budget.period)
        let transactions = getTransactionsForBudget(budget, in: periodRange)
        return transactions.reduce(0) { $0 + abs($1.amount) }
    }

    /// Get spent amount for a budget in a specific display period (for cross-period viewing)
    func spentAmount(for budget: Budget, displayPeriod: BudgetPeriod) -> Double {
        let periodRange = currentPeriodRange(for: displayPeriod)
        let transactions = getTransactionsForBudget(budget, in: periodRange)
        return transactions.reduce(0) { $0 + abs($1.amount) }
    }

    /// Get spent amount for a budget in a specific display period containing a specific date
    func spentAmount(for budget: Budget, displayPeriod: BudgetPeriod, on date: Date) -> Double {
        let periodRange = periodRange(for: displayPeriod, containing: date)
        let transactions = getTransactionsForBudget(budget, in: periodRange)
        return transactions.reduce(0) { $0 + abs($1.amount) }
    }

    /// Get spent amount for a budget in a specific date
    func spentAmount(for budget: Budget, on date: Date) -> Double {
        let periodRange = periodRange(for: budget.period, containing: date)
        let transactions = getTransactionsForBudget(budget, in: periodRange)
        return transactions.reduce(0) { $0 + abs($1.amount) }
    }

    /// Get the equivalent budget amount for a different display period
    func equivalentAmount(for budget: Budget, displayPeriod: BudgetPeriod) -> Double {
        if budget.period == displayPeriod {
            return budget.amount
        }
        return convertAmount(budget.amount, from: budget.period, to: displayPeriod)
    }

    /// Get transactions matching budget (category + subcategories + wallet + date range)
    func getTransactionsForBudget(_ budget: Budget, in dateRange: ClosedRange<Date>) -> [Txn] {
        let walletTransactions = userManager.currentUser.transactions
            .filter { $0.walletID == budget.walletId }
            .filter { dateRange.contains($0.date) }
            .filter { $0.amount < 0 } // Expenses only

        // Match parent category OR any of its subcategories
        let allCategoryIds = getCategoryAndSubcategoryIds(for: budget.categoryId)

        return walletTransactions.filter { txn in
            if let txnCategoryId = txn.categoryId {
                return allCategoryIds.contains(txnCategoryId)
            }
            // Fallback to name matching for older transactions without categoryId
            return txn.category == budget.categoryName
        }
    }

    /// Get category ID and all its subcategory IDs
    private func getCategoryAndSubcategoryIds(for categoryId: UUID) -> Set<UUID> {
        var ids: Set<UUID> = [categoryId]

        // Find the parent category and get its subcategory IDs
        if let result = categoriesManager.findCategoryOrSubcategoryById(categoryId),
           let category = result.category {
            let subcategoryIds = category.subcategories.map { $0.id }
            ids.formUnion(subcategoryIds)
        }

        return ids
    }

    // MARK: - Period Date Range Calculations

    /// Get the date range for the current period
    func currentPeriodRange(for period: BudgetPeriod) -> ClosedRange<Date> {
        return periodRange(for: period, containing: Date())
    }

    /// Get the date range for a period containing a specific date
    func periodRange(for period: BudgetPeriod, containing date: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current

        switch period {
        case .daily:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return start...end

        case .weekly:
            // Week starts Monday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            components.weekday = 2 // Monday
            var cal = Calendar(identifier: .gregorian)
            cal.firstWeekday = 2 // Monday
            let start = cal.date(from: components) ?? calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1)
            return start...end

        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1)
            return start...end

        case .quarterly:
            let month = calendar.component(.month, from: date)
            let quarterStart = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: date)
            components.month = quarterStart
            components.day = 1
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .month, value: 3, to: start)!.addingTimeInterval(-1)
            return start...end

        case .yearly:
            var components = calendar.dateComponents([.year], from: date)
            components.month = 1
            components.day = 1
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!.addingTimeInterval(-1)
            return start...end
        }
    }

    // MARK: - Auto-Compute Period Estimates

    /// Convert budget amount to another period (for display estimates)
    func convertAmount(_ amount: Double, from: BudgetPeriod, to: BudgetPeriod) -> Double {
        let dailyAmount = toDailyAmount(amount, from: from)
        return fromDailyAmount(dailyAmount, to: to)
    }

    /// Convert any period amount to daily
    private func toDailyAmount(_ amount: Double, from period: BudgetPeriod) -> Double {
        switch period {
        case .daily:
            return amount
        case .weekly:
            return amount / 7
        case .monthly:
            return amount / 30.44 // Average days per month
        case .quarterly:
            return amount / 91.31 // Average days per quarter
        case .yearly:
            return amount / 365
        }
    }

    /// Convert daily amount to any period
    private func fromDailyAmount(_ dailyAmount: Double, to period: BudgetPeriod) -> Double {
        switch period {
        case .daily:
            return dailyAmount
        case .weekly:
            return dailyAmount * 7
        case .monthly:
            return dailyAmount * 30.44
        case .quarterly:
            return dailyAmount * 91.31
        case .yearly:
            return dailyAmount * 365
        }
    }

    /// Get estimated amounts for all periods based on a budget's set amount
    func periodEstimates(for budget: Budget) -> [BudgetPeriod: Double] {
        var estimates: [BudgetPeriod: Double] = [:]
        for period in BudgetPeriod.allCases {
            estimates[period] = convertAmount(budget.amount, from: budget.period, to: period)
        }
        return estimates
    }

    // MARK: - Budget Progress Calculations

    /// Calculate progress percentage (0.0 to 1.0+)
    func progress(for budget: Budget) -> Double {
        let spent = spentAmount(for: budget)
        guard budget.amount > 0 else { return 0 }
        return spent / budget.amount
    }

    /// Remaining amount (can be negative if over budget)
    func remainingAmount(for budget: Budget) -> Double {
        return budget.amount - spentAmount(for: budget)
    }

    /// Check if budget is over limit
    func isOverBudget(_ budget: Budget) -> Bool {
        return spentAmount(for: budget) > budget.amount
    }

    // MARK: - Color State Helpers

    /// Get the appropriate color for a budget's progress bar
    func progressBarColor(for budget: Budget) -> Color {
        let percentUsed = progress(for: budget)
        if percentUsed > 1.0 {
            return AppColors.destructiveForeground  // Red - over budget
        }
        if percentUsed >= 0.5 {
            return Color(hex: "FF9E15") ?? AppColors.accentOrange  // Orange - 50-100%
        }
        return AppColors.successForeground  // Green - under 50%
    }

    // MARK: - Period Display Helpers

    /// Get human-readable period label for current period
    func currentPeriodLabel(for period: BudgetPeriod) -> String {
        let formatter = DateFormatter()
        let now = Date()

        switch period {
        case .daily:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: now)
        case .weekly:
            let range = currentPeriodRange(for: period)
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: range.lowerBound)) - \(formatter.string(from: range.upperBound))"
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: now)
        case .quarterly:
            let month = Calendar.current.component(.month, from: now)
            let quarter = ((month - 1) / 3) + 1
            let year = Calendar.current.component(.year, from: now)
            return "Q\(quarter) \(year)"
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: now)
        }
    }
}
