//
//  HomePageCharts.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI

// MARK: - Chart Helper Functions

fileprivate func formatLineChartValue(_ value: Double) -> String {
    let absValue = abs(value)
    let rounded = roundToNearestFiveOrTen(absValue)
    let sign = value < 0 ? "-" : ""
    if rounded >= 1000 {
        let roundedThousand = roundToNearestFiveOrTen(rounded / 1000)
        return "\(sign)\(Int(roundedThousand))k"
    } else {
        return "\(sign)\(Int(rounded))"
    }
}

// Format exact amounts for data point display (no abbreviation)
fileprivate func formatExactAmount(_ value: Double) -> String {
    let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = ","

    let formattedAmount = formatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.2f", abs(value))
    let sign = value < 0 ? "-" : ""
    return "\(sign)\(primaryCurrency.symbol)\(formattedAmount)"
}

// Format date for legend (like "Nov 11" or "3PM" for day view)
fileprivate func formatLegendDate(_ date: Date, rangeSelection: HomePage.RangeSelection) -> String {
    let formatter = DateFormatter()
    switch rangeSelection {
    case .day:
        formatter.dateFormat = "ha" // Shows "3PM", "11AM", etc.
    case .week, .month, .quarter:
        formatter.dateFormat = "MMM d" // Shows "Nov 11", etc.
    }
    return formatter.string(from: date)
}

fileprivate func roundToNearestFiveOrTen(_ value: Double) -> Double {
    if value >= 100 {
        return round(value / 10) * 10
    } else if value >= 10 {
        return round(value / 5) * 5
    } else {
        return round(value)
    }
}

// Normalize dates for chart plotting based on range selection
fileprivate func normalizeDateForChart(_ date: Date, rangeSelection: HomePage.RangeSelection) -> Date {
    let calendar = Calendar.current
    
    switch rangeSelection {
    case .day:
        // For day view, KEEP time components for hourly granularity like other filters
        return date
    case .week, .month, .quarter:
        // For other views, keep the full timestamp for granular plotting
        return date
    }
}

// Calculate cumulative balance up to (but not including) a specific date
fileprivate func calculateCumulativeBalance(
    allTransactions: [Txn],
    beforeDate: Date
) -> Double {
    let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
    let rateManager = CurrencyRateManager.shared

    return allTransactions
        .filter { $0.date < beforeDate }
        .reduce(0.0) { sum, txn in
            let convertedAmount: Double
            if txn.primaryCurrency == primaryCurrency {
                convertedAmount = txn.amount
            } else {
                convertedAmount = rateManager.convertAmount(txn.amount, from: txn.primaryCurrency, to: primaryCurrency)
            }
            return sum + convertedAmount
        }
}

// Simple line chart data - one point per transaction with running total
fileprivate func createLineChartData(
    transactions: [Txn],
    startDate: Date,
    endDate: Date,
    chartFilter: HomePage.ChartFilter,
    rangeSelection: HomePage.RangeSelection,
    startingBalance: Double = 0
) -> [(date: Date, amount: Double)] {
    var dataPoints: [(date: Date, amount: Double)] = []
    var runningTotal: Double = startingBalance

    // Add starting point
    dataPoints.append((date: startDate, amount: startingBalance))

    // Add one point per transaction (simple diagonal lines between points)
    for transaction in transactions {
        let transactionImpact = getTransactionImpact(transaction, chartFilter: chartFilter)
        runningTotal += transactionImpact
        dataPoints.append((date: transaction.date, amount: runningTotal))
    }

    // Add final point to extend line to end of period
    if let lastAmount = dataPoints.last?.amount {
        dataPoints.append((date: endDate, amount: lastAmount))
    }

    return dataPoints
}

fileprivate func getTransactionImpact(_ transaction: Txn, chartFilter: HomePage.ChartFilter) -> Double {
    // Convert to primary currency
    let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
    let convertedAmount: Double
    
    if transaction.primaryCurrency == primaryCurrency {
        convertedAmount = transaction.amount
    } else {
        let rateManager = CurrencyRateManager.shared
        convertedAmount = rateManager.convertAmount(
            transaction.amount,
            from: transaction.primaryCurrency,
            to: primaryCurrency
        )
    }
    
    // Apply chart filter logic
    switch chartFilter {
    case .balance:
        return convertedAmount
    case .income:
        return convertedAmount > 0 ? convertedAmount : 0
    case .expense:
        return convertedAmount < 0 ? abs(convertedAmount) : 0
    }
}

// Calculate running total at any specific time (previous value logic)
fileprivate func calculateRunningTotalAtTime(
    targetTime: Date,
    transactions: [Txn],
    startDate: Date,
    chartFilter: HomePage.ChartFilter,
    rangeSelection: HomePage.RangeSelection,
    startingBalance: Double = 0
) -> Double {
    var runningTotal: Double = startingBalance

    // Process all transactions up to and including the target time
    let normalizedTargetTime = normalizeDateForChart(targetTime, rangeSelection: rangeSelection)

    for transaction in transactions {
        let normalizedTransactionDate = normalizeDateForChart(transaction.date, rangeSelection: rangeSelection)

        // Include transactions up to the target time for all views (including day view for hourly granularity)
        let shouldIncludeTransaction = normalizedTransactionDate <= normalizedTargetTime

        if shouldIncludeTransaction {
            let impact = getTransactionImpact(transaction, chartFilter: chartFilter)
            runningTotal += impact
        } else {
            break // Transactions are sorted, so we can stop here
        }
    }

    return runningTotal
}

// Simple struct for mapped transaction data (since Txn.date is immutable)
fileprivate struct MappedTransactionData {
    let originalTransaction: Txn
    let mappedDate: Date
    let amount: Double
}

// Map previous period transactions to current period timeline for comparison
fileprivate func mapPreviousPeriodToCurrentTimeline(
    previousTransactions: [Txn],
    previousPeriodStart: Date,
    previousPeriodEnd: Date,
    currentPeriodStart: Date,
    currentPeriodEnd: Date,
    chartFilter: HomePage.ChartFilter
) -> [MappedTransactionData] {
    let previousDuration = previousPeriodEnd.timeIntervalSince(previousPeriodStart)
    let currentDuration = currentPeriodEnd.timeIntervalSince(currentPeriodStart)
    
    return previousTransactions.map { transaction in
        // Calculate relative position in previous period (0.0 to 1.0)
        let relativePosition = transaction.date.timeIntervalSince(previousPeriodStart) / previousDuration
        
        // Map to equivalent position in current period
        let mappedDate = currentPeriodStart.addingTimeInterval(currentDuration * relativePosition)
        
        // Get transaction impact for the chart filter
        let impact = getTransactionImpact(transaction, chartFilter: chartFilter)
        
        return MappedTransactionData(
            originalTransaction: transaction,
            mappedDate: mappedDate,
            amount: impact
        )
    }
}

// Helper function to find previous period value at a specific time
fileprivate func findPreviousPeriodValue(
    at targetTime: Date,
    in previousPeriodData: [(date: Date, amount: Double)]
) -> Double {
    var previousValue: Double = 0
    
    for (i, dataPoint) in previousPeriodData.enumerated() {
        if dataPoint.date >= targetTime {
            if i > 0 {
                // Use previous data point value (step-wise behavior)
                previousValue = previousPeriodData[i - 1].amount
            } else {
                previousValue = dataPoint.amount
            }
            break
        } else if i == previousPeriodData.count - 1 {
            // Use last data point if target time is beyond all data
            previousValue = dataPoint.amount
        }
    }
    
    return previousValue
}

// Simple line chart data from mapped transaction data (for previous period comparison)
fileprivate func createLineChartDataFromMapped(
    mappedData: [MappedTransactionData],
    startDate: Date,
    endDate: Date,
    startingBalance: Double = 0
) -> [(date: Date, amount: Double)] {
    var dataPoints: [(date: Date, amount: Double)] = []
    var runningTotal: Double = startingBalance

    // Add starting point
    dataPoints.append((date: startDate, amount: startingBalance))

    // Sort and add one point per transaction
    let sortedData = mappedData.sorted { $0.mappedDate < $1.mappedDate }
    for mappedTransaction in sortedData {
        runningTotal += mappedTransaction.amount
        dataPoints.append((date: mappedTransaction.mappedDate, amount: runningTotal))
    }

    // Add final point
    if let lastAmount = dataPoints.last?.amount {
        dataPoints.append((date: endDate, amount: lastAmount))
    }

    return dataPoints
}

// Straight lines with smooth state transitions

// MARK: - HomePage Chart Extensions

extension HomePage {
    
    var comparisonChart: some View {
        GeometryReader { geometry in
            let _ = refreshTrigger // Force re-evaluation when refreshTrigger changes
            let availableHeight = geometry.size.height
            let labelHeight: CGFloat = 18 // Height for labels
            let labelSpacing: CGFloat = 6 // Spacing below bars
            let topMargin: CGFloat = 0 // Small margin from top of content area
            let bottomMargin: CGFloat = 4 // Small margin above labels
            
            // Calculate usable height: total - top margin - label area - bottom margin
            let maxBarHeight = availableHeight - topMargin - labelHeight - labelSpacing - bottomMargin
            
            HStack(alignment: .bottom, spacing: 12) {
                // Last period bar
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    
                    // Bar aligned to bottom
                    ZStack {
                        let maxTotalValue = max(abs(cachedCurrentPeriodTotal), abs(cachedPreviousPeriodTotal), 1)
                        let heightRatio = abs(cachedPreviousPeriodTotal) / maxTotalValue
                        let calculatedHeight = heightRatio * maxBarHeight
                        let finalHeight = max(40, calculatedHeight)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.chartPreviousPeriod)
                            .frame(height: finalHeight)
                            .animation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.1), value: cachedPreviousPeriodTotal)
                        
                        // Amount text on the bar
                        Text(currencyPrefs.formatPrimaryAmount(cachedPreviousPeriodTotal))
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.white)
                            .animation(.easeInOut(duration: 0.3).delay(0.05), value: cachedPreviousPeriodTotal)
                    }
                    
                    // Label at the bottom
                    Text(previousPeriodLabel)
                        .font(AppFonts.overusedGroteskMedium(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                
                // Current period bar  
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                    
                    // Bar aligned to bottom
                    ZStack {
                        let maxTotalValue = max(abs(cachedCurrentPeriodTotal), abs(cachedPreviousPeriodTotal), 1)
                        let heightRatio = abs(cachedCurrentPeriodTotal) / maxTotalValue
                        let calculatedHeight = heightRatio * maxBarHeight
                        let finalHeight = max(40, calculatedHeight)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.primary)
                            .frame(height: finalHeight)
                            .animation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.1).delay(0.05), value: cachedCurrentPeriodTotal)
                        
                        // Amount text on the bar
                        Text(currencyPrefs.formatPrimaryAmount(cachedCurrentPeriodTotal))
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.white)
                            .animation(.easeInOut(duration: 0.3).delay(0.1), value: cachedCurrentPeriodTotal)
                    }
                    
                    // Label at the bottom
                    Text(currentPeriodLabel)
                        .font(AppFonts.overusedGroteskMedium(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .padding(.top, topMargin)
            .padding(.bottom, bottomMargin)
            .padding(.horizontal, 8) // Add side margins to match top margin
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Line color based on chart filter: expense=red, income=green, balance=purple
    var chartLineColor: Color {
        switch chartFilter {
        case .expense:
            return AppColors.chartExpense1
        case .income:
            return AppColors.chartIncome2
        case .balance:
            return AppColors.primary
        }
    }

    var lineChart: some View {
        VStack(spacing: 16) {
            let _ = refreshTrigger // Force re-evaluation when refreshTrigger changes
            
            // Calculate enhanced data for smooth dragging with previous value logic
            let transactions = accountManager.filteredTransactions
            let cal = Calendar.current
            let now = Date()
            
            // Get the actual start and end dates for the period
            let (periodStartDate, periodEndDate) = {
                    switch rangeSelection {
                    case .day:
                        let start = cal.startOfDay(for: now)
                        let end = cal.dateInterval(of: .day, for: now)?.end ?? now
                        return (start, end)
                    case .week:
                        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                        let end = cal.dateInterval(of: .weekOfYear, for: now)?.end ?? now
                        return (start, end)
                    case .month:
                        let start = cal.dateInterval(of: .month, for: now)?.start ?? now
                        let end = cal.dateInterval(of: .month, for: now)?.end ?? now
                        return (start, end)
                    case .quarter:
                        let currentMonth = cal.component(.month, from: now)
                        let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
                        let start = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1)) ?? now
                        let quarterEndMonth = quarterStartMonth + 2
                        let end = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterEndMonth + 1, day: 1))?.addingTimeInterval(-24*3600) ?? now
                        return (start, end)
                    }
                }()
            
            // Enhanced data processing for smooth dragging with previous value logic
            let currentPeriodTransactions = transactions.filter { txn in
                txn.date >= periodStartDate && txn.date <= min(now, periodEndDate)
            }.sorted { $0.date < $1.date }

            // For balance mode, calculate cumulative balance before period start
            let startingBalance: Double = chartFilter == .balance
                ? calculateCumulativeBalance(allTransactions: transactions, beforeDate: periodStartDate)
                : 0

            // Create simple line chart data points
            let currentPeriodData = createLineChartData(
                transactions: currentPeriodTransactions,
                startDate: periodStartDate,
                endDate: periodEndDate,
                chartFilter: chartFilter,
                rangeSelection: rangeSelection,
                startingBalance: startingBalance
            )
            
            // Calculate previous period data for comparison
            let (previousPeriodStartDate, mappedPreviousData) = {
                switch rangeSelection {
                case .day:
                    let prevStart = cal.date(byAdding: .day, value: -1, to: periodStartDate) ?? periodStartDate
                    let prevEnd = cal.date(byAdding: .day, value: -1, to: periodEndDate) ?? periodEndDate
                    let prevTransactions = transactions.filter { txn in
                        txn.date >= prevStart && txn.date <= prevEnd
                    }.sorted { $0.date < $1.date }
                    let mapped = mapPreviousPeriodToCurrentTimeline(
                        previousTransactions: prevTransactions,
                        previousPeriodStart: prevStart,
                        previousPeriodEnd: prevEnd,
                        currentPeriodStart: periodStartDate,
                        currentPeriodEnd: periodEndDate,
                        chartFilter: chartFilter
                    )
                    return (prevStart, mapped)
                case .week:
                    let prevStart = cal.date(byAdding: .weekOfYear, value: -1, to: periodStartDate) ?? periodStartDate
                    let prevEnd = cal.date(byAdding: .weekOfYear, value: -1, to: periodEndDate) ?? periodEndDate
                    let prevTransactions = transactions.filter { txn in
                        txn.date >= prevStart && txn.date <= prevEnd
                    }.sorted { $0.date < $1.date }
                    let mapped = mapPreviousPeriodToCurrentTimeline(
                        previousTransactions: prevTransactions,
                        previousPeriodStart: prevStart,
                        previousPeriodEnd: prevEnd,
                        currentPeriodStart: periodStartDate,
                        currentPeriodEnd: periodEndDate,
                        chartFilter: chartFilter
                    )
                    return (prevStart, mapped)
                case .month:
                    let prevStart = cal.date(byAdding: .month, value: -1, to: periodStartDate) ?? periodStartDate
                    let prevEnd = cal.date(byAdding: .month, value: -1, to: periodEndDate) ?? periodEndDate
                    let prevTransactions = transactions.filter { txn in
                        txn.date >= prevStart && txn.date <= prevEnd
                    }.sorted { $0.date < $1.date }
                    let mapped = mapPreviousPeriodToCurrentTimeline(
                        previousTransactions: prevTransactions,
                        previousPeriodStart: prevStart,
                        previousPeriodEnd: prevEnd,
                        currentPeriodStart: periodStartDate,
                        currentPeriodEnd: periodEndDate,
                        chartFilter: chartFilter
                    )
                    return (prevStart, mapped)
                case .quarter:
                    let prevStart = cal.date(byAdding: .month, value: -3, to: periodStartDate) ?? periodStartDate
                    let prevEnd = cal.date(byAdding: .month, value: -3, to: periodEndDate) ?? periodEndDate
                    let prevTransactions = transactions.filter { txn in
                        txn.date >= prevStart && txn.date <= prevEnd
                    }.sorted { $0.date < $1.date }
                    let mapped = mapPreviousPeriodToCurrentTimeline(
                        previousTransactions: prevTransactions,
                        previousPeriodStart: prevStart,
                        previousPeriodEnd: prevEnd,
                        currentPeriodStart: periodStartDate,
                        currentPeriodEnd: periodEndDate,
                        chartFilter: chartFilter
                    )
                    return (prevStart, mapped)
                }
            }()

            // For balance mode, calculate cumulative balance before previous period start
            let previousStartingBalance: Double = chartFilter == .balance
                ? calculateCumulativeBalance(allTransactions: transactions, beforeDate: previousPeriodStartDate)
                : 0

            // Create simple line chart data for previous period
            let previousPeriodData = createLineChartDataFromMapped(
                mappedData: mappedPreviousData,
                startDate: periodStartDate,
                endDate: periodEndDate,
                startingBalance: previousStartingBalance
            )
            
            // Legend - Dynamic based on hover or current filter
            HStack(spacing: 16) {
                // Current period legend
                HStack(spacing: 8) {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 20, height: 6)
                        .background(chartLineColor)
                        .cornerRadius(200)
                        .animation(.easeInOut(duration: 0.6), value: chartFilter)
                    
                    if let dragValue = selectedDragValue, let dragDate = selectedDragDate {
                        // Show hovered data point with specific date
                        HStack(alignment: .top, spacing: 4) {
                            Text(formatExactAmount(dragValue))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text(formatLegendDate(dragDate, rangeSelection: rangeSelection))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(0)
                    } else if let selectedIndex = selectedDataPointIndex,
                       selectedIndex < currentPeriodData.count {
                        // Fallback to discrete data point selection
                        let selectedData = currentPeriodData[selectedIndex]
                        HStack(alignment: .top, spacing: 4) {
                            Text(formatExactAmount(selectedData.amount))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text(formatLegendDate(selectedData.date, rangeSelection: rangeSelection))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(0)
                    } else {
                        // Show current period label (Today, This Week, etc.)
                        HStack(alignment: .top, spacing: 4) {
                            Text(getCurrentFilteredTotal())
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                                .animation(.easeInOut(duration: 0.6), value: chartFilter)
                                .animation(.easeInOut(duration: 0.6), value: rangeSelection)
                            Text(rangeSelection == .day ? "Today" : currentPeriodLabel)
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(0)
                    }
                }
                
                // Previous period legend (positioned to the right with 16px spacing)
                HStack(spacing: 8) {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 20, height: 6)
                        .background(Color(red: 0.86, green: 0.89, blue: 0.96))
                        .cornerRadius(200)
                    
                    // Previous period legend data (dynamic based on hover)
                    if let _ = selectedDragValue, let dragDate = selectedDragDate, previousPeriodData.count > 0 {
                        // Calculate previous period value at the same time position
                        let dragPos = selectedDragPosition ?? 0
                        let targetTime = periodStartDate.addingTimeInterval((periodEndDate.timeIntervalSince(periodStartDate)) * dragPos)
                        
                        // Find corresponding previous period value
                        let previousValue = findPreviousPeriodValue(at: targetTime, in: previousPeriodData)
                        
                        // CRITICAL FIX: Calculate equivalent date in previous period
                        let periodDuration = periodEndDate.timeIntervalSince(periodStartDate)
                        let previousPeriodStartDate = periodStartDate.addingTimeInterval(-periodDuration)
                        let equivalentPreviousPeriodDate = previousPeriodStartDate.addingTimeInterval(dragDate.timeIntervalSince(periodStartDate))
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text(formatExactAmount(previousValue))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text(formatLegendDate(equivalentPreviousPeriodDate, rangeSelection: rangeSelection))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(0)
                    } else if let selectedIndex = selectedDataPointIndex,
                       selectedIndex < currentPeriodData.count, previousPeriodData.count > 0 {
                        // Fallback to discrete data point selection
                        let selectedData = currentPeriodData[selectedIndex]
                        let periodDuration = periodEndDate.timeIntervalSince(periodStartDate)
                        let timeOffset = selectedData.date.timeIntervalSince(periodStartDate)
                        let normalizedTime: Double = periodDuration > 0 ? timeOffset / periodDuration : 0
                        let targetTime = periodStartDate.addingTimeInterval((periodEndDate.timeIntervalSince(periodStartDate)) * normalizedTime)
                        
                        // Find corresponding previous period value
                        let previousValue = findPreviousPeriodValue(at: targetTime, in: previousPeriodData)
                        
                        // CRITICAL FIX: Calculate equivalent date in previous period for discrete selection
                        let previousPeriodStartDate = periodStartDate.addingTimeInterval(-periodDuration)
                        let equivalentPreviousPeriodDate = previousPeriodStartDate.addingTimeInterval(selectedData.date.timeIntervalSince(periodStartDate))
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text(formatExactAmount(previousValue))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text(formatLegendDate(equivalentPreviousPeriodDate, rangeSelection: rangeSelection))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(0)
                    } else if previousPeriodData.count > 0 {
                        // Default state - show previous period total
                        let previousTotal = previousPeriodData.last?.amount ?? 0
                        HStack(alignment: .top, spacing: 4) {
                            Text(formatExactAmount(previousTotal))
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text(rangeSelection == .day ? "Yesterday" : previousPeriodLabel)
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .padding(0)
                    } else {
                        Text(rangeSelection == .day ? "Yesterday" : previousPeriodLabel)
                            .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Chart Area
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let chartWidth = width - 36 // Reserve 36pt gap for Y-axis labels
                
                
                // For balance mode, allow negative values; for income/expense keep min at 0
                let dataMin = min(
                    currentPeriodData.map { $0.amount }.min() ?? 0,
                    previousPeriodData.map { $0.amount }.min() ?? 0
                )
                let dataMax = max(
                    currentPeriodData.map { $0.amount }.max() ?? 1,
                    previousPeriodData.map { $0.amount }.max() ?? 1,
                    1
                )

                // For balance mode, use actual data range; for income/expense, min is 0
                let minValue: Double = chartFilter == .balance ? min(dataMin, 0) : 0
                let maxValue: Double = max(dataMax, chartFilter == .balance ? 0 : 1)

                // Calculate Y-axis label values based on range
                let range = maxValue - minValue
                let yLabel1 = maxValue
                let yLabel2 = minValue + range * 0.67
                let yLabel3 = minValue + range * 0.33
                let yLabel4 = minValue

                ZStack {
                    // Y-axis labels
                    VStack {
                        HStack {
                            Spacer()
                            Text(formatLineChartValue(yLabel1))
                                .font(AppFonts.overusedGroteskMedium(size: 12))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatLineChartValue(yLabel2))
                                .font(AppFonts.overusedGroteskMedium(size: 12))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatLineChartValue(yLabel3))
                                .font(AppFonts.overusedGroteskMedium(size: 12))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatLineChartValue(yLabel4))
                                .font(AppFonts.overusedGroteskMedium(size: 12))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                    }
                    
                    // Calculate previous period points BEFORE drawing so dot can use them
                    let previousPoints: [CGPoint] = {
                        guard previousPeriodData.count > 0 else { return [] }
                        let periodDuration = periodEndDate.timeIntervalSince(periodStartDate)
                        return previousPeriodData.map { dataPoint in
                            let timeOffset = dataPoint.date.timeIntervalSince(periodStartDate)
                            let normalizedTime: Double = periodDuration > 0 ? timeOffset / periodDuration : 0
                            let x = chartWidth * CGFloat(max(0, min(1, normalizedTime)))
                            let normalizedAmount = max(0, min(1, (dataPoint.amount - minValue) / (maxValue - minValue)))
                            let y = height - (height * CGFloat(normalizedAmount))
                            return CGPoint(x: x, y: y)
                        }
                    }()

                    // Previous period line (background) - gray with gradient fill and rounded corners
                    if previousPoints.count > 1 {
                        // Gradient fill under the previous period line (subtle)
                        Path { path in
                            drawRoundedLine(path: &path, points: previousPoints)
                            if let lastPoint = previousPoints.last, let firstPoint = previousPoints.first {
                                path.addLine(to: CGPoint(x: lastPoint.x, y: height))
                                path.addLine(to: CGPoint(x: firstPoint.x, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(
                                colors: [AppColors.linePrimary.opacity(0.15), AppColors.linePrimary.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .animation(.easeInOut(duration: 0.6), value: chartFilter)
                        .animation(.easeInOut(duration: 0.6), value: rangeSelection)

                        // Draw line with rounded corners
                        Path { path in
                            drawRoundedLine(path: &path, points: previousPoints)
                        }
                        .stroke(AppColors.linePrimary, lineWidth: 2)
                        .animation(.easeInOut(duration: 0.6), value: chartFilter)
                        .animation(.easeInOut(duration: 0.6), value: rangeSelection)
                    }

                    // Calculate current period points BEFORE crosshairs so dot can use them
                    let currentPoints: [CGPoint] = {
                        guard currentPeriodData.count > 0 else { return [] }
                        let currentTime = Date()
                        let periodDuration = periodEndDate.timeIntervalSince(periodStartDate)

                        let basePoints: [CGPoint] = currentPeriodData.compactMap { dataPoint in
                            guard dataPoint.date <= currentTime else { return nil }
                            let timeOffset = dataPoint.date.timeIntervalSince(periodStartDate)
                            let normalizedTime: Double = periodDuration > 0 ? timeOffset / periodDuration : 0
                            let x = chartWidth * CGFloat(max(0, min(1, normalizedTime)))
                            let y = height - (height * CGFloat((dataPoint.amount - minValue) / (maxValue - minValue)))
                            return CGPoint(x: x, y: y)
                        }

                        // Extend line to "now"
                        guard let lastPoint = basePoints.last, currentTime <= periodEndDate else { return basePoints }
                        let nowTimeOffset = currentTime.timeIntervalSince(periodStartDate)
                        let nowNormalizedTime = periodDuration > 0 ? nowTimeOffset / periodDuration : 0
                        let nowX = chartWidth * CGFloat(max(0, min(1, nowNormalizedTime)))
                        guard nowX > lastPoint.x + 1 else { return basePoints }
                        return basePoints + [CGPoint(x: nowX, y: lastPoint.y)]
                    }()

                    // Crosshairs (behind the lines)
                    // Enhanced crosshairs for smooth dragging - show crosshairs throughout period, data points only for current data
                    if let dragPos = selectedDragPosition, let _ = selectedDragValue {
                        // Smooth drag crosshairs
                        let pointX = chartWidth * CGFloat(dragPos)
                        // Find clamped positions on lines (dots stay at line endpoints when dragging beyond)
                        let currentPoint = findPointOnLine(atX: pointX, points: currentPoints)
                        let previousPoint = findPointOnLine(atX: pointX, points: previousPoints)

                        // Use current point Y for crosshair, fallback to previous, or hide
                        let crosshairY = currentPoint?.y ?? previousPoint?.y ?? height

                        // Vertical crosshair - dashed with DCE2F4 color
                        Path { path in
                            path.move(to: CGPoint(x: pointX, y: 0))
                            path.addLine(to: CGPoint(x: pointX, y: height))
                        }
                        .stroke(AppColors.linePrimary, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                        // Horizontal crosshair - dashed with DCE2F4 color
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: crosshairY))
                            path.addLine(to: CGPoint(x: chartWidth, y: crosshairY))
                        }
                        .stroke(AppColors.linePrimary, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                        // Data point indicator at drag point (current period)
                        // Dot clamps to line endpoints when dragging beyond
                        if let current = currentPoint {
                            Circle()
                                .fill(chartLineColor)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1)
                                        .frame(width: 8, height: 8)
                                )
                                .position(x: current.x, y: current.y)
                                .zIndex(20)
                        }

                        // Previous period data point indicator (gray dot)
                        // Dot clamps to line endpoints when dragging beyond
                        if let prev = previousPoint {
                            Circle()
                                .fill(Color(red: 0.86, green: 0.89, blue: 0.96))
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1)
                                        .frame(width: 8, height: 8)
                                )
                                .position(x: prev.x, y: prev.y)
                                .zIndex(10)
                        }

                    } else if let selectedIndex = selectedDataPointIndex,
                       selectedIndex < currentPeriodData.count {
                        let selectedData = currentPeriodData[selectedIndex]

                        // Calculate X position for the selected data point
                        let periodDuration = periodEndDate.timeIntervalSince(periodStartDate)
                        let dateForPositioning = selectedData.date
                        let timeOffset = dateForPositioning.timeIntervalSince(periodStartDate)
                        let normalizedTime: Double = periodDuration > 0 ? timeOffset / periodDuration : 0
                        let pointX = chartWidth * CGFloat(max(0, min(1, normalizedTime)))

                        // Find clamped positions on lines (dots stay at line endpoints)
                        let currentPoint = findPointOnLine(atX: pointX, points: currentPoints)
                        let previousPoint = findPointOnLine(atX: pointX, points: previousPoints)

                        // Use current point Y for crosshair, fallback to previous, or default to center
                        let crosshairY = currentPoint?.y ?? previousPoint?.y ?? height / 2

                        // Vertical line (grey)
                        Path { path in
                            path.move(to: CGPoint(x: pointX, y: 0))
                            path.addLine(to: CGPoint(x: pointX, y: height))
                        }
                        .stroke(AppColors.linePrimary, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                        // Horizontal line (grey)
                        if currentPoint != nil || previousPoint != nil {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: crosshairY))
                                path.addLine(to: CGPoint(x: chartWidth, y: crosshairY))
                            }
                            .stroke(AppColors.linePrimary, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }

                        // Data point indicator (current period) - clamps to line endpoints
                        let currentTime = Date()
                        if selectedData.date <= currentTime, let current = currentPoint {
                            Circle()
                                .fill(chartLineColor)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1)
                                        .frame(width: 8, height: 8)
                                )
                                .position(x: current.x, y: current.y)
                                .zIndex(20)
                        }

                        // Previous period data point indicator (gray dot) - clamps to line endpoints
                        if let prev = previousPoint {
                            Circle()
                                .fill(Color(red: 0.86, green: 0.89, blue: 0.96))
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 1)
                                        .frame(width: 8, height: 8)
                                )
                                .position(x: prev.x, y: prev.y)
                                .zIndex(10)
                        }
                    }
                    
                    // Current period line (foreground) - with gradient fill and rounded corners
                    // Uses pre-calculated currentPoints from above (same points used for dot positioning)
                    if currentPoints.count > 1 {
                        // Gradient fill under the line
                        Path { path in
                            drawRoundedLine(path: &path, points: currentPoints)
                            // Close to bottom-right, then bottom-left
                            if let lastPoint = currentPoints.last, let firstPoint = currentPoints.first {
                                path.addLine(to: CGPoint(x: lastPoint.x, y: height))
                                path.addLine(to: CGPoint(x: firstPoint.x, y: height))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(
                                colors: [chartLineColor.opacity(0.3), chartLineColor.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .animation(.easeInOut(duration: 0.6), value: chartFilter)
                        .animation(.easeInOut(duration: 0.6), value: rangeSelection)

                        // Draw line with rounded corners
                        Path { path in
                            drawRoundedLine(path: &path, points: currentPoints)
                        }
                        .stroke(chartLineColor, lineWidth: 2)
                        .animation(.easeInOut(duration: 0.6), value: chartFilter)
                        .animation(.easeInOut(duration: 0.6), value: rangeSelection)
                    }
                    
                    // Crosshairs moved to appear behind lines
                    
                    // Interactive overlay for hover detection
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Enhanced smooth dragging - calculate running total for any X position
                                    if currentPeriodData.count > 0 {
                                        let normalizedX = max(0, min(1, value.location.x / chartWidth))
                                        
                                        // Calculate the date for this X position
                                        let periodDuration = periodEndDate.timeIntervalSince(periodStartDate)
                                        let timeAtPosition = periodStartDate.addingTimeInterval(periodDuration * normalizedX)
                                        
                                        // Find running total at this time position (previous value logic)
                                        let runningTotalAtPosition = calculateRunningTotalAtTime(
                                            targetTime: timeAtPosition,
                                            transactions: currentPeriodTransactions,
                                            startDate: periodStartDate,
                                            chartFilter: chartFilter,
                                            rangeSelection: rangeSelection,
                                            startingBalance: startingBalance
                                        )
                                        
                                        
                                        // Check if this position has actual current period data (not future)
                                        let currentTime = Date()
                                        let hasCurrentData = timeAtPosition <= currentTime && timeAtPosition <= min(currentTime, periodEndDate)
                                        
                                        // Store the drag position and calculated value (always for crosshairs)
                                        selectedDragPosition = normalizedX
                                        selectedDragValue = runningTotalAtPosition
                                        selectedDragDate = timeAtPosition
                                        selectedDragHasCurrentData = hasCurrentData
                                        showingDataPointValue = true
                                    }
                                }
                                .onEnded { _ in
                                    // Reset drag state after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        selectedDragPosition = nil
                                        selectedDragValue = nil
                                        selectedDragDate = nil
                                        selectedDragHasCurrentData = false
                                        selectedDataPointIndex = nil
                                        showingDataPointValue = false
                                    }
                                }
                        )
                }
            }
            .frame(maxHeight: .infinity)
            
            // X-axis labels - Multiple intermediate points
            HStack {
                let labels = getXAxisLabels(startDate: periodStartDate, endDate: periodEndDate)
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    if index == 0 {
                        Text(label)
                            .font(AppFonts.overusedGroteskMedium(size: 12))
                            .foregroundColor(AppColors.foregroundSecondary)
                    } else {
                        Spacer()
                        Text(label)
                            .font(AppFonts.overusedGroteskMedium(size: 12))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }
            }
            .padding(.trailing, 24)
        }
        .frame(height: 280)
    }
    
    // Helper function to get current filtered total for legend
    private func getCurrentFilteredTotal() -> String {
        let transactions = accountManager.filteredTransactions
        let cal = Calendar.current
        let now = Date()
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        let rateManager = CurrencyRateManager.shared

        // Get current period boundaries
        let (periodStartDate, periodEndDate) = {
            switch rangeSelection {
            case .day:
                let start = cal.startOfDay(for: now)
                let end = cal.dateInterval(of: .day, for: now)?.end ?? now
                return (start, end)
            case .week:
                let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let end = cal.dateInterval(of: .weekOfYear, for: now)?.end ?? now
                return (start, end)
            case .month:
                let start = cal.dateInterval(of: .month, for: now)?.start ?? now
                let end = cal.dateInterval(of: .month, for: now)?.end ?? now
                return (start, end)
            case .quarter:
                let currentMonth = cal.component(.month, from: now)
                let quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1
                let start = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1)) ?? now
                let quarterEndMonth = quarterStartMonth + 2
                let end = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterEndMonth + 1, day: 1))?.addingTimeInterval(-24*3600) ?? now
                return (start, end)
            }
        }()

        // For balance mode, use ALL transactions up to now (cumulative)
        // For income/expense, use only current period transactions
        let relevantTransactions: [Txn]
        if chartFilter == .balance {
            relevantTransactions = transactions.filter { $0.date <= now }
        } else {
            relevantTransactions = transactions.filter { txn in
                txn.date >= periodStartDate && txn.date <= min(now, periodEndDate)
            }
        }

        // Calculate total based on chart filter (with currency conversion)
        let total = relevantTransactions.reduce(0.0) { sum, txn in
            // Convert to primary currency
            let convertedAmount: Double
            if txn.primaryCurrency == primaryCurrency {
                convertedAmount = txn.amount
            } else {
                convertedAmount = rateManager.convertAmount(txn.amount, from: txn.primaryCurrency, to: primaryCurrency)
            }

            switch chartFilter {
            case .balance:
                return sum + convertedAmount
            case .income:
                return sum + (convertedAmount > 0 ? convertedAmount : 0)
            case .expense:
                return sum + (convertedAmount < 0 ? abs(convertedAmount) : 0)
            }
        }

        return formatExactAmount(total)
    }
    
    // Helper function to format data point date and time
    private func formatDataPointDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to generate X-axis labels with intermediate points
    private func getXAxisLabels(startDate: Date, endDate: Date) -> [String] {
        let formatter = DateFormatter()
        let cal = Calendar.current
        
        switch rangeSelection {
        case .day:
            // For day view, show times (e.g., 12AM, 6AM, 12PM, 6PM, 12AM)
            formatter.dateFormat = "ha"
            let interval: TimeInterval = 6 * 3600 // 6 hours
            var labels: [String] = []
            var currentDate = startDate
            
            while currentDate <= endDate {
                labels.append(formatter.string(from: currentDate))
                currentDate = currentDate.addingTimeInterval(interval)
            }
            // Ensure we have the end time
            if labels.count < 5 {
                labels.append(formatter.string(from: endDate))
            }
            return Array(labels.prefix(5))
            
        case .week:
            // For week view, show days (e.g., Mon, Tue, Wed, Thu, Fri, Sat, Sun)
            formatter.dateFormat = "E"
            var labels: [String] = []
            var currentDate = startDate
            
            for _ in 0..<7 {
                labels.append(formatter.string(from: currentDate))
                currentDate = cal.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            return labels
            
        case .month:
            // For month view, show week intervals
            formatter.dateFormat = "M/d"
            let weekInterval: TimeInterval = 7 * 24 * 3600 // 1 week
            var labels: [String] = []
            var currentDate = startDate
            
            while currentDate <= endDate {
                labels.append(formatter.string(from: currentDate))
                currentDate = currentDate.addingTimeInterval(weekInterval)
            }
            // Ensure we have the end date
            if labels.count < 5 {
                labels.append(formatter.string(from: endDate))
            }
            return Array(labels.prefix(5))
            
        case .quarter:
            // For quarter view, show months
            formatter.dateFormat = "MMM"
            var labels: [String] = []
            var currentDate = startDate
            
            for _ in 0..<3 {
                labels.append(formatter.string(from: currentDate))
                currentDate = cal.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
            return labels
        }
    }
    
}

// MARK: - Line Chart Helper Functions

/// Find position on line at given X, clamping to endpoints if outside range
/// Returns nil only if there are no points
fileprivate func findPointOnLine(atX targetX: CGFloat, points: [CGPoint]) -> CGPoint? {
    guard let first = points.first, let last = points.last else { return nil }
    guard points.count >= 1 else { return nil }

    // Clamp to first point if before line start
    if targetX < first.x {
        return first
    }

    // Clamp to last point if after line end
    if targetX > last.x {
        return last
    }

    // Single point case
    if points.count == 1 {
        return first
    }

    // Within range - interpolate
    for i in 0..<points.count - 1 {
        let p1 = points[i]
        let p2 = points[i + 1]

        if targetX >= p1.x && targetX <= p2.x {
            let t = (p2.x - p1.x) > 0 ? (targetX - p1.x) / (p2.x - p1.x) : 0
            let y = p1.y + t * (p2.y - p1.y)
            return CGPoint(x: targetX, y: y)
        }
    }

    // Fallback to last point
    return last
}

/// Draws lines through all points with small rounded corners at junctions
fileprivate func drawRoundedLine(path: inout Path, points: [CGPoint], cornerRadius: CGFloat = 4) {
    guard points.count > 0 else { return }
    guard points.count > 1 else {
        path.move(to: points[0])
        return
    }

    // For 2 points, just draw a straight line
    guard points.count > 2 else {
        path.move(to: points[0])
        path.addLine(to: points[1])
        return
    }

    path.move(to: points[0])

    for i in 1..<points.count - 1 {
        let prev = points[i - 1]
        let curr = points[i]
        let next = points[i + 1]

        // Calculate distances to determine safe radius
        let dist1 = hypot(curr.x - prev.x, curr.y - prev.y)
        let dist2 = hypot(next.x - curr.x, next.y - curr.y)
        let minDist = min(dist1, dist2)

        // Use smaller radius for short segments to avoid artifacts
        let safeRadius = min(cornerRadius, minDist / 3)

        if safeRadius > 1 {
            path.addArc(tangent1End: curr, tangent2End: next, radius: safeRadius)
        } else {
            // Too short for rounding, just go straight
            path.addLine(to: curr)
        }
    }

    // Final line to last point
    path.addLine(to: points.last!)
}
