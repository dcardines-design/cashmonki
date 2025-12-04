//
//  HomePageHelpers.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI
import PhotosUI
import Foundation

// MARK: - HomePage Helper Functions

extension HomePage {
    
    // MARK: - Chart Data Processing
    
    // Check if there's actual transaction data to display in the chart
    internal func hasTransactionDataForChart() -> Bool {
        let transactions = accountManager.filteredTransactions
        
        // Get the start date for the current period
        let (startDate, _) = getExactTimePoints()
        
        // Check if there are any transactions in the current period being displayed
        return transactions.contains { $0.date >= startDate }
    }
    
    // Get the end date for the current period (always current time)
    private func getEndDateForPeriod(startDate: Date) -> Date {
        // Always return current time - no data beyond "now"
        return Date()
    }
    
    // MARK: - Cumulative Balance Chart Data
    
    internal func getCumulativeBalanceDataWithTimestamps() -> ([Double], [Date]) {
        let transactions = accountManager.filteredTransactions
        
        // Get time period start date
        let (startDate, _) = getExactTimePoints()
        let endDate = getEndDateForPeriod(startDate: startDate)
        
        // Get transactions in the time period only, sorted by date
        let sortedTransactions = transactions
            .filter { $0.date >= startDate && $0.date < endDate }
            .sorted { $0.date < $1.date }
        
        var balanceData: [Double] = []
        var timestampData: [Date] = []
        
        // Always start at $0 at the beginning of the period (period-specific)
        balanceData.append(0)
        timestampData.append(startDate)
        
        // Add data points at each actual transaction moment
        var runningTotal: Double = 0
        for transaction in sortedTransactions {
            runningTotal += getTransactionImpact(transaction)
            balanceData.append(runningTotal)
            timestampData.append(transaction.date)
        }
        
        // Add final point at current time if we have transactions
        if !sortedTransactions.isEmpty {
            if timestampData.last! < endDate {
                balanceData.append(runningTotal) // Same total as last transaction
                timestampData.append(endDate)
            }
        }
        
        return (balanceData, timestampData)
    }
    
    internal func getCumulativeBalanceData() -> [Double] {
        let transactions = accountManager.filteredTransactions
        
        // Get time period and create time chunks
        let (startDate, chunkCount, chunkDuration) = getTimeChunks()
        
        // Sort transactions by date
        let sortedTransactions = transactions
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
        
        // Calculate starting balance (transactions before start date)
        let earlierTransactions = transactions.filter { $0.date < startDate }
        var runningBalance = earlierTransactions.reduce(0) { total, txn in
            return total + getTransactionImpact(txn)
        }
        
        // Create data points for each time chunk
        var balanceData: [Double] = []
        
        for chunkIndex in 0..<chunkCount {
            let chunkStart = startDate.addingTimeInterval(TimeInterval(chunkIndex) * chunkDuration)
            let chunkEnd = chunkStart.addingTimeInterval(chunkDuration)
            
            // Find transactions in this chunk and apply them to running balance
            let chunkTransactions = sortedTransactions.filter { txn in
                return txn.date >= chunkStart && txn.date < chunkEnd
            }
            
            // Apply transactions in chronological order
            for txn in chunkTransactions {
                runningBalance += getTransactionImpact(txn)
            }
            
            balanceData.append(runningBalance)
        }
        
        // If no data points, add starting balance
        if balanceData.isEmpty {
            balanceData.append(runningBalance)
        }
        
        return balanceData
    }
    
    private func getTransactionImpact(_ transaction: Txn) -> Double {
        // CRITICAL: Convert transaction amount to user's primary currency
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        let convertedAmount: Double
        
        // Check if transaction is already in primary currency
        if transaction.primaryCurrency == primaryCurrency {
            // Transaction is already in primary currency, use amount directly
            convertedAmount = transaction.amount
        } else {
            // Convert from transaction's primary currency to current user's primary currency
            let rateManager = CurrencyRateManager.shared
            convertedAmount = rateManager.convertAmount(
                transaction.amount,
                from: transaction.primaryCurrency,
                to: primaryCurrency
            )
            
            // Debug log for currency conversions
            print("💱 CHART: Converting \(transaction.amount) \(transaction.primaryCurrency.rawValue) → \(convertedAmount) \(primaryCurrency.rawValue)")
        }
        
        // Apply chart filter logic using converted amount
        switch chartFilter {
        case .balance:
            // Show cumulative balance: income adds, expenses subtract
            return convertedAmount
            
        case .income:
            // Only show income transactions (positive amounts)
            return convertedAmount > 0 ? convertedAmount : 0
            
        case .expense:
            // Only show expense transactions (negative amounts), but as positive for cumulative chart
            return convertedAmount < 0 ? abs(convertedAmount) : 0
        }
    }
    
    internal func getExactTimePoints() -> (startDate: Date, timePoints: [Date]) {
        let cal = Calendar.current
        let now = Date()
        
        switch rangeSelection {
        case .day:
            // Start of today to current time
            let startOfToday = cal.startOfDay(for: now)
            let timePoints = (0..<7).compactMap { i in
                let timePoint = startOfToday.addingTimeInterval(TimeInterval(i * 4 * 3600))
                return timePoint <= now ? timePoint : nil
            }
            // Always ensure current time is included
            let finalPoints = timePoints + [now]
            return (startOfToday, Array(Set(finalPoints)).sorted())
            
        case .week:
            // Start of week to current day
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let timePoints = (0..<8).compactMap { i in
                let timePoint = startOfWeek.addingTimeInterval(TimeInterval(i * 24 * 3600))
                return timePoint <= now ? timePoint : nil
            }
            // Always ensure current time is included
            let finalPoints = timePoints + [now]
            return (startOfWeek, Array(Set(finalPoints)).sorted())
            
        case .month:
            // Start of month to current date
            let startOfMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
            let timePoints = (0..<11).compactMap { i in
                let timePoint = startOfMonth.addingTimeInterval(TimeInterval(i * 3 * 24 * 3600))
                return timePoint <= now ? timePoint : nil
            }
            // Always ensure current time is included
            let finalPoints = timePoints + [now]
            return (startOfMonth, Array(Set(finalPoints)).sorted())
            
        case .quarter:
            // Start of quarter to current date
            let currentMonth = cal.component(.month, from: now)
            let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
            let quarterStart = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1)) ?? now
            let timePoints = (0..<13).compactMap { i in
                let timePoint = quarterStart.addingTimeInterval(TimeInterval(i * 7 * 24 * 3600))
                return timePoint <= now ? timePoint : nil
            }
            // Always ensure current time is included
            let finalPoints = timePoints + [now]
            return (quarterStart, Array(Set(finalPoints)).sorted())
        }
    }
    
    private func getTimeChunks() -> (startDate: Date, chunkCount: Int, chunkDuration: TimeInterval) {
        let cal = Calendar.current
        let now = Date()
        
        switch rangeSelection {
        case .day:
            // 24 hours broken into 6 chunks of 4 hours each (as requested)
            let startOfToday = cal.startOfDay(for: now)
            return (startOfToday, 6, 4 * 3600) // 4 hours in seconds
            
        case .week:
            // 7 days broken into 7 chunks of 1 day each
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, 7, 24 * 3600) // 1 day in seconds
            
        case .month:
            // 30 days broken into 10 chunks of 3 days each
            let startOfMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, 10, 3 * 24 * 3600) // 3 days in seconds
            
        case .quarter:
            // 90 days broken into 12 chunks of ~7.5 days each
            let quarterStart = cal.date(byAdding: .month, value: -3, to: now) ?? now
            return (quarterStart, 12, 7.5 * 24 * 3600) // ~7.5 days in seconds
        }
    }
    
    internal func getCumulativeChartLabels() -> [String] {
        let cal = Calendar.current
        let now = Date()
        
        switch rangeSelection {
        case .day:
            // Show key times throughout the day (every 4 hours)
            let startOfToday = cal.startOfDay(for: now)
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            
            var labels: [String] = []
            // Show 12 AM, 4 AM, 8 AM, 12 PM, 4 PM, 8 PM, 12 AM (next day)
            for i in 0..<7 {
                let timePoint = startOfToday.addingTimeInterval(TimeInterval(i * 4 * 3600))
                labels.append(formatter.string(from: timePoint))
            }
            return labels
            
        case .week:
            // Show all 7 days of the week (Sun through Sat)
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            
            var labels: [String] = []
            for i in 0..<7 {
                let dayPoint = startOfWeek.addingTimeInterval(TimeInterval(i * 24 * 3600))
                labels.append(formatter.string(from: dayPoint))
            }
            return labels
            
        case .month:
            // Show key dates throughout the month (weekly intervals)
            let startOfMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = cal.dateInterval(of: .month, for: now)?.end ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            
            var labels: [String] = []
            let monthDuration = endOfMonth.timeIntervalSince(startOfMonth)
            
            // Show 5 points across the month (roughly weekly)
            for i in 0..<5 {
                let timePoint = startOfMonth.addingTimeInterval(TimeInterval(i) * monthDuration / 4)
                labels.append(formatter.string(from: timePoint))
            }
            return labels
            
        case .quarter:
            // Show each month in the quarter
            let currentMonth = cal.component(.month, from: now)
            let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            
            var labels: [String] = []
            // Show the 3 months in the quarter
            for i in 0..<3 {
                let monthDate = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth + i, day: 1)) ?? now
                labels.append(formatter.string(from: monthDate))
            }
            return labels
        }
    }

    internal func getLineChartData() -> ([Double], [Double]) {
        let transactions = accountManager.filteredTransactions
        let cal = Calendar.current
        let now = Date()
        
        // Create time buckets based on selected range
        let bucketCount = 15 // Number of data points in the line
        var currentPeriodData: [Double] = Array(repeating: 0, count: bucketCount)
        var previousPeriodData: [Double] = Array(repeating: 0, count: bucketCount)
        
        switch rangeSelection {
        case .day:
            // 24 hours divided into 15 buckets (1.6 hours each)
            let startOfToday = cal.startOfDay(for: now)
            let endOfToday = cal.dateInterval(of: .day, for: now)?.end ?? now
            let endOfYesterday = cal.date(byAdding: .day, value: -1, to: endOfToday) ?? now
            
            // Calculate bucket duration based on full period, not just current time
            let totalDayDuration = endOfToday.timeIntervalSince(startOfToday)
            let bucketDuration = totalDayDuration / Double(bucketCount)
            
            for transaction in transactions {
                if transaction.date >= startOfToday && transaction.date <= min(now, endOfToday) {
                    let timeSinceStart = transaction.date.timeIntervalSince(startOfToday)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    currentPeriodData[bucketIndex] += abs(transaction.amount)
                } else if transaction.date <= endOfYesterday {
                    let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
                    let timeSinceStart = transaction.date.timeIntervalSince(startOfYesterday)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    previousPeriodData[bucketIndex] += abs(transaction.amount)
                }
            }
            
        case .week:
            // Full week period divided into 15 buckets
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            let endOfLastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: endOfWeek) ?? now
            
            let totalWeekDuration = endOfWeek.timeIntervalSince(startOfWeek)
            let bucketDuration = totalWeekDuration / Double(bucketCount)
            
            for transaction in transactions {
                if transaction.date >= startOfWeek && transaction.date <= min(now, endOfWeek) {
                    let timeSinceStart = transaction.date.timeIntervalSince(startOfWeek)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    currentPeriodData[bucketIndex] += abs(transaction.amount)
                } else if transaction.date <= endOfLastWeek {
                    let startOfLastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek
                    let timeSinceStart = transaction.date.timeIntervalSince(startOfLastWeek)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    previousPeriodData[bucketIndex] += abs(transaction.amount)
                }
            }
            
        case .month:
            // Full month period divided into 15 buckets
            let startOfMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = cal.dateInterval(of: .month, for: now)?.end ?? now
            let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
            let endOfLastMonth = cal.date(byAdding: .month, value: -1, to: endOfMonth) ?? now
            
            let totalMonthDuration = endOfMonth.timeIntervalSince(startOfMonth)
            let bucketDuration = totalMonthDuration / Double(bucketCount)
            
            for transaction in transactions {
                if transaction.date >= startOfMonth && transaction.date <= min(now, endOfMonth) {
                    let timeSinceStart = transaction.date.timeIntervalSince(startOfMonth)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    currentPeriodData[bucketIndex] += abs(transaction.amount)
                } else if transaction.date >= startOfLastMonth && transaction.date <= endOfLastMonth {
                    let timeSinceStart = transaction.date.timeIntervalSince(startOfLastMonth)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    previousPeriodData[bucketIndex] += abs(transaction.amount)
                }
            }
            
        case .quarter:
            // Full quarter period divided into 15 buckets
            let currentMonth = cal.component(.month, from: now)
            let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
            let quarterStart = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1)) ?? now
            let quarterEndMonth = quarterStartMonth + 2
            let quarterEnd = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterEndMonth + 1, day: 1))?.addingTimeInterval(-24*3600) ?? now
            
            let lastQuarterStart = cal.date(byAdding: .month, value: -3, to: quarterStart) ?? now
            let lastQuarterEnd = cal.date(byAdding: .month, value: -3, to: quarterEnd) ?? now
            
            let totalQuarterDuration = quarterEnd.timeIntervalSince(quarterStart)
            let bucketDuration = totalQuarterDuration / Double(bucketCount)
            
            for transaction in transactions {
                if transaction.date >= quarterStart && transaction.date <= min(now, quarterEnd) {
                    let timeSinceStart = transaction.date.timeIntervalSince(quarterStart)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    currentPeriodData[bucketIndex] += abs(transaction.amount)
                } else if transaction.date >= lastQuarterStart && transaction.date <= lastQuarterEnd {
                    let timeSinceStart = transaction.date.timeIntervalSince(lastQuarterStart)
                    let bucketIndex = min(Int(timeSinceStart / bucketDuration), bucketCount - 1)
                    previousPeriodData[bucketIndex] += abs(transaction.amount)
                }
            }
        }
        
        return (currentPeriodData, previousPeriodData)
    }
    
    // Get line chart data with timestamp alignment for proper X-axis positioning
    internal func getLineChartDataWithTimestamps() -> (currentData: [(value: Double, timestamp: Date)], previousData: [(value: Double, timestamp: Date)]) {
        let transactions = accountManager.filteredTransactions
        let cal = Calendar.current
        
        // Get the chart dates to align data with
        let chartDates = getChartLabelDates()
        
        var currentPeriodData: [(value: Double, timestamp: Date)] = []
        var previousPeriodData: [(value: Double, timestamp: Date)] = []
        
        // Group transactions by the chart label time periods
        for (index, labelDate) in chartDates.enumerated() {
            let nextDate = index < chartDates.count - 1 ? chartDates[index + 1] : labelDate.addingTimeInterval(24 * 3600)
            
            // Find transactions in this time bucket
            let bucketTransactions = transactions.filter { txn in
                txn.date >= labelDate && txn.date < nextDate
            }
            
            let totalValue = bucketTransactions.reduce(0) { total, txn in
                return total + abs(txn.amount)
            }
            
            if totalValue > 0 {
                currentPeriodData.append((value: totalValue, timestamp: labelDate))
            }
        }
        
        // For previous period, get equivalent time period from previous cycle
        switch rangeSelection {
        case .day:
            // Yesterday's data
            for (index, labelDate) in chartDates.enumerated() {
                let yesterdayEquivalent = cal.date(byAdding: .day, value: -1, to: labelDate) ?? labelDate
                let nextDate = index < chartDates.count - 1 ? cal.date(byAdding: .day, value: -1, to: chartDates[index + 1]) ?? yesterdayEquivalent.addingTimeInterval(4 * 3600) : yesterdayEquivalent.addingTimeInterval(4 * 3600)
                
                let bucketTransactions = transactions.filter { txn in
                    txn.date >= yesterdayEquivalent && txn.date < nextDate
                }
                
                let totalValue = bucketTransactions.reduce(0) { total, txn in
                    return total + abs(txn.amount)
                }
                
                if totalValue > 0 {
                    previousPeriodData.append((value: totalValue, timestamp: labelDate)) // Use current label date for positioning
                }
            }
            
        case .week:
            // Last week's data
            for (index, labelDate) in chartDates.enumerated() {
                let lastWeekEquivalent = cal.date(byAdding: .weekOfYear, value: -1, to: labelDate) ?? labelDate
                let nextDate = index < chartDates.count - 1 ? cal.date(byAdding: .weekOfYear, value: -1, to: chartDates[index + 1]) ?? lastWeekEquivalent.addingTimeInterval(24 * 3600) : lastWeekEquivalent.addingTimeInterval(24 * 3600)
                
                let bucketTransactions = transactions.filter { txn in
                    txn.date >= lastWeekEquivalent && txn.date < nextDate
                }
                
                let totalValue = bucketTransactions.reduce(0) { total, txn in
                    return total + abs(txn.amount)
                }
                
                if totalValue > 0 {
                    previousPeriodData.append((value: totalValue, timestamp: labelDate)) // Use current label date for positioning
                }
            }
            
        case .month:
            // Last month's data
            for (index, labelDate) in chartDates.enumerated() {
                let lastMonthEquivalent = cal.date(byAdding: .month, value: -1, to: labelDate) ?? labelDate
                let nextDate = index < chartDates.count - 1 ? cal.date(byAdding: .month, value: -1, to: chartDates[index + 1]) ?? lastMonthEquivalent.addingTimeInterval(7 * 24 * 3600) : lastMonthEquivalent.addingTimeInterval(7 * 24 * 3600)
                
                let bucketTransactions = transactions.filter { txn in
                    txn.date >= lastMonthEquivalent && txn.date < nextDate
                }
                
                let totalValue = bucketTransactions.reduce(0) { total, txn in
                    return total + abs(txn.amount)
                }
                
                if totalValue > 0 {
                    previousPeriodData.append((value: totalValue, timestamp: labelDate)) // Use current label date for positioning
                }
            }
            
        case .quarter:
            // Last quarter's data
            for (index, labelDate) in chartDates.enumerated() {
                let lastQuarterEquivalent = cal.date(byAdding: .month, value: -3, to: labelDate) ?? labelDate
                let nextDate = index < chartDates.count - 1 ? cal.date(byAdding: .month, value: -3, to: chartDates[index + 1]) ?? lastQuarterEquivalent.addingTimeInterval(30 * 24 * 3600) : lastQuarterEquivalent.addingTimeInterval(30 * 24 * 3600)
                
                let bucketTransactions = transactions.filter { txn in
                    txn.date >= lastQuarterEquivalent && txn.date < nextDate
                }
                
                let totalValue = bucketTransactions.reduce(0) { total, txn in
                    return total + abs(txn.amount)
                }
                
                if totalValue > 0 {
                    previousPeriodData.append((value: totalValue, timestamp: labelDate)) // Use current label date for positioning
                }
            }
        }
        
        return (currentPeriodData, previousPeriodData)
    }
    
    // Helper to get actual dates corresponding to chart labels
    internal func getChartLabelDates() -> [Date] {
        let cal = Calendar.current
        let now = Date()
        
        switch rangeSelection {
        case .day:
            let startOfToday = cal.startOfDay(for: now)
            var dates: [Date] = []
            for i in 0..<7 {
                dates.append(startOfToday.addingTimeInterval(TimeInterval(i * 4 * 3600)))
            }
            return dates
            
        case .week:
            let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            var dates: [Date] = []
            for i in 0..<7 {
                dates.append(startOfWeek.addingTimeInterval(TimeInterval(i * 24 * 3600)))
            }
            return dates
            
        case .month:
            let startOfMonth = cal.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = cal.dateInterval(of: .month, for: now)?.end ?? now
            let monthDuration = endOfMonth.timeIntervalSince(startOfMonth)
            
            var dates: [Date] = []
            for i in 0..<5 {
                dates.append(startOfMonth.addingTimeInterval(TimeInterval(i) * monthDuration / 4))
            }
            return dates
            
        case .quarter:
            let currentMonth = cal.component(.month, from: now)
            let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
            
            var dates: [Date] = []
            for i in 0..<3 {
                let monthDate = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth + i, day: 1)) ?? now
                dates.append(monthDate)
            }
            return dates
        }
    }
    
    // Helper function to round values to nearest 5 or 10 for cleaner chart display
    private func roundToNearestFiveOrTen(_ value: Double) -> Double {
        if value >= 100 {
            // For values >= 100, round to nearest 10
            return round(value / 10) * 10
        } else if value >= 10 {
            // For values 10-99, round to nearest 5
            return round(value / 5) * 5
        } else {
            // For values < 10, round to nearest 1
            return round(value)
        }
    }
    
    internal func formatCumulativeValue(_ value: Double) -> String {
        // Format using primary currency symbol for chart Y-axis
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        let absValue = abs(value)
        let sign = value >= 0 ? "" : "-"
        let symbol = primaryCurrency.symbol
        
        if absValue >= 1000000 {
            // Round millions to nearest 5 or 10
            let millionValue = absValue / 1000000
            let roundedMillion = roundToNearestFiveOrTen(millionValue)
            return "\(symbol)\(sign)\(Int(roundedMillion))M"
        } else if absValue >= 1000 {
            // Round thousands to nearest 5 or 10
            let thousandValue = absValue / 1000
            let roundedThousand = roundToNearestFiveOrTen(thousandValue)
            return "\(symbol)\(sign)\(Int(roundedThousand))k"
        } else {
            // Round smaller values to nearest 5 or 10
            let rounded = roundToNearestFiveOrTen(absValue)
            return "\(symbol)\(sign)\(Int(rounded))"
        }
    }
    
    internal func getTooltipAmountText(_ balance: Double) -> String {
        // Always format in user's primary currency since balance is already converted
        let currencyPrefs = CurrencyPreferences.shared
        return currencyPrefs.formatPrimaryAmount(balance)
    }
    
    internal func formatTooltipDateTime(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)
        
        return "\(dateString)\n\(timeString)"
    }
    
    internal func formatLineChartValue(_ value: Double) -> String {
        let rounded = roundToNearestFiveOrTen(abs(value))
        if rounded >= 1000 {
            let roundedThousand = roundToNearestFiveOrTen(rounded / 1000)
            return "\(Int(roundedThousand))k"
        } else {
            return "\(Int(rounded))"
        }
    }
    
    internal func getLineChartStartLabel() -> String {
        let cal = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch rangeSelection {
        case .day:
            startDate = cal.startOfDay(for: now)
            let formatter = DateFormatter()
            formatter.dateFormat = "h a"
            return formatter.string(from: startDate) // "12 AM"
            
        case .week:
            startDate = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "E" // "Mon"
            return formatter.string(from: startDate)
            
        case .month:
            startDate = cal.dateInterval(of: .month, for: now)?.start ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: startDate) // "Nov 1"
            
        case .quarter:
            // Start of current quarter
            let currentMonth = cal.component(.month, from: now)
            let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
            startDate = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1)) ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: startDate) // "Oct 1"
        }
    }
    
    internal func getLineChartEndLabel() -> String {
        let cal = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        
        switch rangeSelection {
        case .day:
            // End of today (11:59 PM)
            let endOfToday = cal.dateInterval(of: .day, for: now)?.end ?? now
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: endOfToday) // "11:59 PM"
            
        case .week:
            // End of current week
            let endOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            formatter.dateFormat = "E"
            return formatter.string(from: endOfWeek) // "Sun"
            
        case .month:
            // End of current month
            let endOfMonth = cal.dateInterval(of: .month, for: now)?.end ?? now
            formatter.dateFormat = "MMM d"
            return formatter.string(from: endOfMonth) // "Nov 30"
            
        case .quarter:
            // End of current quarter
            let currentMonth = cal.component(.month, from: now)
            let quarterEndMonth = ((currentMonth - 1) / 3 + 1) * 3
            let quarterEnd = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterEndMonth + 1, day: 1))?.addingTimeInterval(-24*3600) ?? now
            formatter.dateFormat = "MMM d"
            return formatter.string(from: quarterEnd) // "Dec 31"
        }
    }
    
    // MARK: - Formatting Functions
    
    func amountText(_ value: Double) -> String { 
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0  // Hide .00
        formatter.maximumFractionDigits = 2  // Show up to .01
        formatter.groupingSeparator = ","
        formatter.numberStyle = .decimal
        
        let formattedAmount = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.0f", abs(value))
        return "\(value < 0 ? "-" : "+")\(formattedAmount)"
    }
    
    func getFallbackSystemName(for iconName: String) -> String {
        switch iconName {
        case "plus": return "plus"
        case "scan": return "qrcode.viewfinder"  
        case "clock": return "clock"
        default: return "square.and.arrow.up"
        }
    }
    
    func dateSubtitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d, yyyy"
        return df.string(from: date)
    }
    
    func currency(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = ","
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        let formatted = nf.string(from: NSNumber(value: value)) ?? "0"
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        return "\(primaryCurrency.symbol)\(formatted)"
    }
    
    func formatChartAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
    
    // MARK: - Receipt Analysis
    
    func analyzeReceiptImage(_ image: UIImage, source: AnalyzingSource = .scan) {
        print("🚀📸 ==== RECEIPT ANALYSIS STARTED ====")
        print("📱 Source: \(source == .scan ? "CAMERA CAPTURE" : "PHOTO UPLOAD")")
        print("📐 Image size: \(image.size.width) x \(image.size.height)")
        print("🔍 Toast manager available: ✅")
        print("🔑 API key check:")
        print("   - Keychain: \(KeychainManager.shared.exists(for: .openRouterAPIKey) ? "✅ EXISTS" : "❌ MISSING")")
        if let key = Config.openRouterAPIKey {
            print("   - Config returns: \(key.prefix(10))...")
        } else {
            print("   - Config returns: ❌ NIL")
        }
        
        // Start the toast animation
        toastManager.startReceiptAnalysis()
        print("🍞 Receipt analysis toast started")
        
        isAnalyzingReceipt = true
        analyzingSource = source
        receiptAnalysisError = nil
        
        let creationTime = Date()
        AIReceiptAnalyzer.shared.analyzeReceipt(image: image, creationTime: creationTime) { result in
            DispatchQueue.main.async {
                print("🔄📸 ==== RECEIPT ANALYSIS COMPLETED ====")
                isAnalyzingReceipt = false
                analyzingSource = nil
                originalTileClicked = nil
                
                switch result {
                case .success(let analysis):
                    print("✅ Receipt analysis SUCCESS!")
                    print("🏪 Merchant: \(analysis.merchantName)")
                    print("💰 Amount: \(analysis.totalAmount) \(analysis.currency.rawValue)")
                    print("📅 Date: \(analysis.date)")
                    print("📂 Category: \(analysis.category)")
                    print("💳 Payment: \(analysis.paymentMethod)")
                    print("📋 Items: \(analysis.items.count)")
                    
                    // Record usage for receipt analysis
                    dailyUsageManager.recordReceiptAnalysis()
                    print("📊 HomePage: Recorded receipt analysis usage")
                    
                    // Complete the toast animation and show confirmation sheet after done animation
                    toastManager.completeReceiptAnalysis {
                        print("🍞 Analysis toast completed, showing confirmation sheet")
                        // This runs after the done animation has been shown
                        pendingReceiptImage = image
                        pendingReceiptAnalysis = analysis
                        showingReceiptConfirmation = true
                    }
                    
                case .failure(let error):
                    print("❌📸 ==== RECEIPT ANALYSIS FAILED ====")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ Error type: \(type(of: error))")
                    if let receiptError = error as? ReceiptAIError {
                        print("❌ Specific receipt error: \(receiptError)")
                    }
                    
                    // Use smart error handling that automatically detects network vs regular errors
                    toastManager.failReceiptAnalysis(error: error) {
                        // Handle failure completion if needed
                    }
                    
                    // Provide specific error messages based on error type
                    if let receiptError = error as? ReceiptAIError {
                        switch receiptError {
                        case .missingAPIKey:
                            receiptAnalysisError = "⚠️ API key not configured. Please check app settings."
                        case .imageProcessingFailed:
                            receiptAnalysisError = "📷 Could not process image. Try taking a clearer photo."
                        case .requestCreationFailed:
                            receiptAnalysisError = "🔧 Request setup failed. Please try again."
                        case .noDataReceived:
                            receiptAnalysisError = "📡 No response from AI service. Check internet connection."
                        case .invalidResponse:
                            receiptAnalysisError = "🤖 AI service returned invalid response. Try again."
                        case .jsonExtractionFailed:
                            receiptAnalysisError = "📄 Could not understand AI response. Try different image."
                        case .missingRequiredFields:
                            receiptAnalysisError = "📋 AI could not extract receipt data. Try clearer photo."
                        }
                    } else {
                        receiptAnalysisError = "🔍 Could not analyze image. Try again in good lighting or cropping closer."
                    }
                    
                    print("🔍 DEBUGGING INFO:")
                    print("   - Error type: \(type(of: error))")
                    print("   - Error description: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("   - Domain: \(nsError.domain)")
                        print("   - Code: \(nsError.code)")
                        print("   - UserInfo: \(nsError.userInfo)")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Photo Processing
    
    internal func loadDirectPhoto(_ item: PhotosPickerItem) {
        print("📸 HomePage: Loading photo from direct picker")
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        print("✅ HomePage: Photo loaded successfully, analyzing...")
                        self.analyzeReceiptImage(image, source: .upload)
                        // Reset photo picker state so user can select again
                        self.selectedDirectPhoto = nil
                    }
                } else {
                    DispatchQueue.main.async {
                        print("❌ HomePage: Failed to create image from data")
                        self.receiptAnalysisError = "📷 Could not process selected image. Please try another photo."
                        // Reset photo picker state so user can try again
                        self.selectedDirectPhoto = nil
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ HomePage: Failed to load photo: \(error)")
                    self.receiptAnalysisError = "📁 Could not load selected image. Please try again."
                    // Reset photo picker state so user can try again
                    self.selectedDirectPhoto = nil
                }
            }
        }
    }
}