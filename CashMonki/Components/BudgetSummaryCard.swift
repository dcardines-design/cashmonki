//
//  BudgetSummaryCard.swift
//  CashMonki
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct BudgetSummaryCard: View {
    let budgets: [Budget]
    let displayPeriod: BudgetPeriod
    let date: Date

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    private let budgetManager = BudgetManager.shared
    private let rateManager = CurrencyRateManager.shared

    @State private var isExpanded: Bool = false

    private let collapsedLimit = 5

    // MARK: - Budget Data

    private struct BudgetData: Identifiable {
        let id: UUID
        let categoryName: String
        let emoji: String
        let spent: Double
        let budget: Double

        var spentPercentage: Double {
            guard budget > 0 else { return 0 }
            return (spent / budget) * 100
        }
    }

    // MARK: - Computed Properties

    private var budgetDataList: [BudgetData] {
        // Sort by spent amount (highest first)
        let sortedBudgets = budgets.sorted {
            getSpentAmount(for: $0) > getSpentAmount(for: $1)
        }

        return sortedBudgets.map { budget in
            let spent = getSpentAmount(for: budget)
            let budgetAmount = getBudgetAmount(for: budget)

            return BudgetData(
                id: budget.id,
                categoryName: budget.categoryName,
                emoji: TxnCategoryIcon.emojiFor(category: budget.categoryName),
                spent: spent,
                budget: budgetAmount
            )
        }
    }

    /// Returns budgets based on expanded state
    private var displayBudgetDataList: [BudgetData] {
        let allData = budgetDataList

        if isExpanded || allData.count <= collapsedLimit {
            return allData
        }

        // Show first 5 items when collapsed
        return Array(allData.prefix(collapsedLimit))
    }

    /// Whether there are more budgets than the collapsed limit
    private var hasMoreBudgets: Bool {
        budgetDataList.count > collapsedLimit
    }

    /// Combined spent amount of remaining (hidden) budgets
    private var remainingSpent: Double {
        let allData = budgetDataList
        guard allData.count > collapsedLimit else { return 0 }
        return Array(allData.dropFirst(collapsedLimit)).reduce(0) { $0 + $1.spent }
    }

    /// Combined budget amount of remaining (hidden) budgets
    private var remainingBudget: Double {
        let allData = budgetDataList
        guard allData.count > collapsedLimit else { return 0 }
        return Array(allData.dropFirst(collapsedLimit)).reduce(0) { $0 + $1.budget }
    }

    /// Percentage spent of remaining budgets
    private var remainingSpentPercentage: Int {
        guard remainingBudget > 0 else { return 0 }
        return Int((remainingSpent / remainingBudget) * 100)
    }

    private var totalSpent: Double {
        budgets.reduce(0) { $0 + getSpentAmount(for: $1) }
    }

    private var totalBudget: Double {
        budgets.reduce(0) { $0 + getBudgetAmount(for: $1) }
    }

    private var periodLabel: String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()

        switch displayPeriod {
        case .daily:
            if calendar.isDateInToday(date) {
                return "Total budget today"
            } else if calendar.isDateInYesterday(date) {
                return "Total budget yesterday"
            } else {
                formatter.dateFormat = "MMM d"
                return "Total budget \(formatter.string(from: date))"
            }

        case .weekly:
            let currentWeek = calendar.component(.weekOfYear, from: now)
            let currentYear = calendar.component(.yearForWeekOfYear, from: now)
            let dateWeek = calendar.component(.weekOfYear, from: date)
            let dateYear = calendar.component(.yearForWeekOfYear, from: date)

            if currentWeek == dateWeek && currentYear == dateYear {
                return "Total budget this week"
            } else if currentWeek - 1 == dateWeek && currentYear == dateYear {
                return "Total budget last week"
            } else {
                // Show week date range
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? date
                formatter.dateFormat = "MMM d"
                return "Total budget \(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
            }

        case .monthly:
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            let dateMonth = calendar.component(.month, from: date)
            let dateYear = calendar.component(.year, from: date)

            if currentMonth == dateMonth && currentYear == dateYear {
                return "Total budget this month"
            } else if (currentMonth - 1 == dateMonth && currentYear == dateYear) ||
                      (currentMonth == 1 && dateMonth == 12 && currentYear - 1 == dateYear) {
                return "Total budget last month"
            } else {
                formatter.dateFormat = "MMM yyyy"
                return "Total budget \(formatter.string(from: date))"
            }

        case .quarterly:
            let currentQuarter = ((calendar.component(.month, from: now) - 1) / 3) + 1
            let currentYear = calendar.component(.year, from: now)
            let dateQuarter = ((calendar.component(.month, from: date) - 1) / 3) + 1
            let dateYear = calendar.component(.year, from: date)

            if currentQuarter == dateQuarter && currentYear == dateYear {
                return "Total budget this quarter"
            } else {
                return "Total budget Q\(dateQuarter) \(dateYear)"
            }

        case .yearly:
            let currentYear = calendar.component(.year, from: now)
            let dateYear = calendar.component(.year, from: date)

            if currentYear == dateYear {
                return "Total budget this year"
            } else {
                return "Total budget \(dateYear)"
            }
        }
    }

    // MARK: - Helper Methods

    private func getSpentAmount(for budget: Budget) -> Double {
        let spent = budgetManager.spentAmount(for: budget, displayPeriod: displayPeriod, on: date)
        // Convert to primary currency if needed
        if budget.currency != currencyPrefs.primaryCurrency {
            return rateManager.convertAmount(spent, from: budget.currency, to: currencyPrefs.primaryCurrency)
        }
        return spent
    }

    private func getBudgetAmount(for budget: Budget) -> Double {
        var amount = budget.amount
        // Convert period if needed
        if budget.period != displayPeriod {
            amount = budgetManager.convertAmount(amount, from: budget.period, to: displayPeriod)
        }
        // Convert currency if needed
        if budget.currency != currencyPrefs.primaryCurrency {
            return rateManager.convertAmount(amount, from: budget.currency, to: currencyPrefs.primaryCurrency)
        }
        return amount
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header + Total amounts (8px spacing to match Balance card)
                VStack(alignment: .leading, spacing: 8) {
                    Text(periodLabel)
                        .font(AppFonts.overusedGroteskMedium(size: 18))
                        .foregroundStyle(.secondary)

                    // Total amounts (spent / total budget)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currencyPrefs.formatPrimaryAmount(totalSpent))
                            .font(AppFonts.overusedGroteskSemiBold(size: 34))
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Text("/")
                                .font(AppFonts.overusedGroteskMedium(size: 18))
                                .foregroundStyle(AppColors.foregroundTertiary)

                            Text(currencyPrefs.formatPrimaryAmount(totalBudget))
                                .font(AppFonts.overusedGroteskMedium(size: 18))
                                .foregroundStyle(AppColors.foregroundTertiary)
                        }
                    }
                }

                // Segmented progress bar
                segmentedProgressBar
            }

            // Budget breakdown list
            VStack(spacing: 16) {
                ForEach(displayBudgetDataList) { data in
                    budgetRow(data: data)
                }

                // Show All / Show Less button when there are more than 5 budgets
                if hasMoreBudgets {
                    showAllToggleRow
                }
            }
        }
        .padding(20)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Show All Toggle Row

    private var showAllToggleRow: some View {
        HStack(spacing: 8) {
            // Show All / Show Less button
            AppButton(
                title: isExpanded ? "Show Less" : "Show All",
                action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                },
                hierarchy: .ghostPrimary,
                size: .doubleExtraSmall
            )

            Spacer()

            // Only show amounts when collapsed (Show All state)
            if !isExpanded {
                HStack(spacing: 4) {
                    Text(currencyPrefs.formatPrimaryAmount(remainingSpent))
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundStyle(remainingSpent > remainingBudget ? AppColors.destructiveForeground : AppColors.foregroundSecondary)

                    Text("/")
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundStyle(AppColors.foregroundTertiary)

                    Text(currencyPrefs.formatPrimaryAmount(remainingBudget))
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundStyle(AppColors.foregroundTertiary)
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBarColor: Color {
        guard totalBudget > 0 else { return AppColors.successForeground }
        let percentage = totalSpent / totalBudget

        if percentage > 1.0 {
            return AppColors.destructiveForeground  // Over budget - red
        } else if percentage >= 0.75 {
            return AppColors.accentOrange           // 75-100% - orange
        } else {
            return AppColors.successForeground      // Under 75% - green
        }
    }

    private var segmentedProgressBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Filled portion (single color based on status)
                let usedProportion = totalBudget > 0 ? min(totalSpent / totalBudget, 1.0) : 0
                let filledWidth = geometry.size.width * usedProportion

                if filledWidth > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressBarColor)
                        .frame(width: filledWidth)
                }

                // Remaining space with striped pattern
                let remainingWidth = geometry.size.width - filledWidth

                if remainingWidth > 2 {
                    stripedRemainingBar(width: remainingWidth)
                }
            }
        }
        .frame(height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Striped Remaining Bar

    private func stripedRemainingBar(width: CGFloat) -> some View {
        let stripeWidth: CGFloat = 4
        let spacing: CGFloat = 4
        let stripeUnit = stripeWidth + spacing  // 8px per stripe unit
        // Calculate stripe count to fill the entire width (add extra to ensure full coverage)
        let stripeCount = Int(ceil(width / stripeUnit)) + 1

        return HStack(spacing: spacing) {
            ForEach(0..<stripeCount, id: \.self) { _ in
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: stripeWidth, height: 20)
                    .background(Color(hex: "DCE2F4") ?? AppColors.linePrimary)
                    .cornerRadius(4)
            }
        }
        .frame(width: width, alignment: .trailing)  // Align to trailing edge
        .clipped()
    }

    // MARK: - Budget Row

    private func budgetRow(data: BudgetData) -> some View {
        HStack(spacing: 8) {
            // Emoji (hidden for "Others" row)
            if !data.emoji.isEmpty {
                Text(data.emoji)
                    .font(.system(size: 16))
            }

            // Category name
            Text(data.categoryName)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(AppColors.foregroundPrimary)

            Spacer()

            // Amounts only (no percentage)
            HStack(spacing: 4) {
                Text(currencyPrefs.formatPrimaryAmount(data.spent))
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(data.spent > data.budget ? AppColors.destructiveForeground : AppColors.foregroundSecondary)

                Text("/")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(AppColors.foregroundTertiary)

                Text(currencyPrefs.formatPrimaryAmount(data.budget))
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(AppColors.foregroundTertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        BudgetSummaryCard(
            budgets: [
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Transportation", amount: 5500, currency: .php, period: .monthly),
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Bills & Utilities", amount: 5000, currency: .php, period: .monthly),
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Entertainment", amount: 1200, currency: .php, period: .monthly),
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Dining & Drinks", amount: 1200, currency: .php, period: .monthly)
            ],
            displayPeriod: .daily,
            date: Date()
        )
    }
    .padding()
    .background(AppColors.surfacePrimary)
}
