//
//  CurrencyRateManager.swift
//  Cashooya Playground
//
//  Created by Claude on 9/14/25.
//

import Foundation
import Network
import UIKit

// MARK: - Currency Rate Models

struct DailyRate: Codable {
    let date: String // Format: YYYY-MM-DD
    let primaryToPrimary: Double // Always 1.0 for primary currency
    let primaryToSecondary: Double
    let secondaryToPrimary: Double
    let secondaryToSecondary: Double // Always 1.0 for secondary currency
    
    init(primaryToSecondary: Double) {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        self.date = today
        self.primaryToPrimary = 1.0
        self.primaryToSecondary = primaryToSecondary
        self.secondaryToPrimary = 1.0 / primaryToSecondary
        self.secondaryToSecondary = 1.0
    }
}

// MARK: - Multi-Currency Rate Models

struct HistoricalExchangeRates: Codable {
    let date: String // Format: YYYY-MM-DD
    let baseCurrency: Currency // USD
    let rates: [String: Double] // Currency code -> rate from USD
    
    init(date: String, baseCurrency: Currency = .usd, rates: [String: Double]) {
        self.date = date
        self.baseCurrency = baseCurrency
        self.rates = rates
    }
    
    // Convert amount from one currency to another using historical rates
    func convert(amount: Double, from: Currency, to: Currency) -> Double {
        // Same currency, no conversion needed
        if from == to { return amount }
        
        // If converting from base currency (USD)
        if from == baseCurrency {
            guard let toRate = rates[to.rawValue] else { return amount }
            return amount * toRate
        }
        
        // If converting to base currency (USD)
        if to == baseCurrency {
            guard let fromRate = rates[from.rawValue] else { return amount }
            return amount / fromRate
        }
        
        // Converting between two non-base currencies
        guard let fromRate = rates[from.rawValue],
              let toRate = rates[to.rawValue] else { return amount }
        
        // Convert via USD: from -> USD -> to
        let usdAmount = amount / fromRate
        return usdAmount * toRate
    }
}

struct HistoricalRatesDatabase: Codable {
    private var rates: [String: HistoricalExchangeRates] = [:]
    
    mutating func addRates(for date: String, rates: HistoricalExchangeRates) {
        self.rates[date] = rates
    }
    
    func getRates(for date: String) -> HistoricalExchangeRates? {
        return rates[date]
    }
    
    func findNearestRates(to targetDate: Date, within days: Int = 7) -> HistoricalExchangeRates? {
        let formatter = DateFormatter.yyyyMMdd
        let targetDateString = formatter.string(from: targetDate)
        
        // First try exact match
        if let exactRates = rates[targetDateString] {
            return exactRates
        }
        
        // Find nearest date within range
        var nearestDate: Date?
        var nearestDifference = TimeInterval.greatestFiniteMagnitude
        
        for dateString in rates.keys {
            guard let date = formatter.date(from: dateString) else { continue }
            let difference = abs(date.timeIntervalSince(targetDate))
            
            // Only consider dates within the specified range
            if difference <= TimeInterval(days * 24 * 3600) && difference < nearestDifference {
                nearestDifference = difference
                nearestDate = date
            }
        }
        
        if let nearestDate = nearestDate {
            let nearestDateString = formatter.string(from: nearestDate)
            return rates[nearestDateString]
        }
        
        return nil
    }
    
    func getAllDates() -> [String] {
        return Array(rates.keys).sorted()
    }
}

struct CurrencyExchangeRates: Codable {
    let date: String
    let baseCurrency: Currency // The currency all rates are relative to
    let rates: [String: Double] // Currency code -> rate from base currency
    
    init(baseCurrency: Currency, rates: [String: Double]) {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        self.date = today
        self.baseCurrency = baseCurrency
        self.rates = rates
    }
    
    // Convert amount from one currency to another
    func convert(amount: Double, from: Currency, to: Currency) -> Double {
        // Same currency, no conversion needed
        if from == to { return amount }
        
        // If converting from base currency
        if from == baseCurrency {
            guard let toRate = rates[to.rawValue] else { return amount }
            return amount * toRate
        }
        
        // If converting to base currency
        if to == baseCurrency {
            guard let fromRate = rates[from.rawValue] else { return amount }
            return amount / fromRate
        }
        
        // Converting between two non-base currencies
        guard let fromRate = rates[from.rawValue],
              let toRate = rates[to.rawValue] else { return amount }
        
        // Convert via base currency: from -> base -> to
        let baseAmount = amount / fromRate
        return baseAmount * toRate
    }
}

struct ConversionRates: Codable {
    var rates: [String: DailyRate] = [:] // Key: YYYY-MM-DD
    
    mutating func setRate(for date: String, primaryToSecondary: Double) {
        rates[date] = DailyRate(primaryToSecondary: primaryToSecondary)
    }
    
    func getRate(for date: String) -> DailyRate? {
        return rates[date]
    }
    
    func getTodayRate() -> DailyRate? {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return getRate(for: today)
    }
}

// MARK: - Currency Rate Manager

class CurrencyRateManager: ObservableObject {
    static let shared = CurrencyRateManager()
    
    @Published var primaryCurrency: Currency = .php
    @Published var secondaryCurrency: Currency? = nil
    @Published var conversionRates: ConversionRates = ConversionRates()
    @Published var multiCurrencyRates: CurrencyExchangeRates?
    @Published var historicalRatesDatabase: HistoricalRatesDatabase = HistoricalRatesDatabase()
    @Published var isOnline: Bool = false
    @Published var lastUpdateDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // UserDefaults keys
    private let primaryCurrencyKey = "primaryCurrency"
    private let secondaryCurrencyKey = "secondaryCurrency"
    private let conversionRatesKey = "conversionRates"
    private let historicalRatesKey = "historicalRatesDatabase"
    private let lastUpdateDateKey = "lastUpdateDate"
    
    private init() {
        loadSavedData()
        startNetworkMonitoring()
        initializeCurrentExchangeRates()
    }
    
    // MARK: - Historical Exchange Rates Initialization
    
    private func initializeHistoricalRates() {
        print("📊 Initializing historical exchange rates database...")
        
        // Sample historical data for the past 6 months (for demonstration)
        // In a real app, this would be loaded from a comprehensive database
        let historicalData = generateSampleHistoricalRates()
        
        for (date, rates) in historicalData {
            let historicalRates = HistoricalExchangeRates(date: date, rates: rates)
            historicalRatesDatabase.addRates(for: date, rates: historicalRates)
        }
        
        print("📊 Initialized \(historicalData.count) days of historical exchange rates")
        saveData() // Persist the historical data
    }
    
    private func generateSampleHistoricalRates() -> [String: [String: Double]] {
        var historicalData: [String: [String: Double]] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        // Generate data for the past 180 days (6 months)
        for dayOffset in 0..<180 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dateString = DateFormatter.yyyyMMdd.string(from: date)
            
            // Base rates with slight historical variations (simulated)
            let variation = Double.random(in: 0.95...1.05) // ±5% variation
            let baseRates: [String: Double] = [
                "PHP": 58.693 * variation,
                "USD": 1.0,
                "EUR": 0.9613 * variation,
                "GBP": 0.8113 * variation,
                "JPY": 154.00 * variation,
                "CAD": 1.4487 * variation,
                "AUD": 1.6198 * variation,
                "CHF": 0.9045 * variation,
                "CNY": 7.3248 * variation,
                "INR": 86.234 * variation,
                "KRW": 1452.8 * variation,
                "SGD": 1.3698 * variation,
                "HKD": 7.7695 * variation,
                "MXN": 20.487 * variation,
                "BRL": 6.1234 * variation,
                "THB": 34.125 * variation,
                "MYR": 4.4892 * variation,
                "IDR": 16284.5 * variation,
                "VND": 24687.3 * variation,
                "NOK": 11.234 * variation,
                "SEK": 11.045 * variation,
                "DKK": 7.1789 * variation,
                "PLN": 4.1256 * variation,
                "CZK": 24.567 * variation,
                "HUF": 398.45 * variation,
                "TRY": 35.234 * variation,
                "ZAR": 18.456 * variation,
                "RUB": 97.234 * variation,
                "AED": 3.6725 * variation,
                "NZD": 1.7834 * variation
            ]
            
            historicalData[dateString] = baseRates
        }
        
        return historicalData
    }
    
    // MARK: - Current Exchange Rates (Updated January 2025)
    
    private func initializeCurrentExchangeRates() {
        // Base currency: USD (all rates from 1 USD to target currency)
        let currentRates: [String: Double] = [
            "PHP": 58.693,  // 1 USD = 58.693 PHP
            "USD": 1.0,     // 1 USD = 1.0 USD (base)
            "EUR": 0.9613,  // 1 USD = 0.9613 EUR
            "GBP": 0.8113,  // 1 USD = 0.8113 GBP
            "JPY": 154.00,  // 1 USD = 154.00 JPY (adjusted for 1000 JPY -> 381.13 PHP)
            "CAD": 1.4487,  // 1 USD = 1.4487 CAD
            "AUD": 1.6198,  // 1 USD = 1.6198 AUD
            "CHF": 0.9045,  // 1 USD = 0.9045 CHF
            "CNY": 7.3248,  // 1 USD = 7.3248 CNY
            "INR": 86.234,  // 1 USD = 86.234 INR
            "KRW": 1452.8,  // 1 USD = 1452.8 KRW
            "SGD": 1.3698,  // 1 USD = 1.3698 SGD
            "HKD": 7.7695,  // 1 USD = 7.7695 HKD
            "MXN": 20.487,  // 1 USD = 20.487 MXN
            "BRL": 6.1234,  // 1 USD = 6.1234 BRL
            "THB": 34.125,  // 1 USD = 34.125 THB
            "MYR": 4.4892,  // 1 USD = 4.4892 MYR
            "IDR": 16284.5, // 1 USD = 16284.5 IDR
            "VND": 24687.3, // 1 USD = 24687.3 VND
            "NOK": 11.234,  // 1 USD = 11.234 NOK
            "SEK": 11.045,  // 1 USD = 11.045 SEK
            "DKK": 7.1789,  // 1 USD = 7.1789 DKK
            "PLN": 4.1256,  // 1 USD = 4.1256 PLN
            "CZK": 24.567,  // 1 USD = 24.567 CZK
            "HUF": 398.45,  // 1 USD = 398.45 HUF
            "TRY": 35.234,  // 1 USD = 35.234 TRY
            "ZAR": 18.456,  // 1 USD = 18.456 ZAR
            "RUB": 97.234,  // 1 USD = 97.234 RUB
            "AED": 3.6725,  // 1 USD = 3.6725 AED
            "NZD": 1.7834   // 1 USD = 1.7834 NZD
        ]
        
        multiCurrencyRates = CurrencyExchangeRates(baseCurrency: .usd, rates: currentRates)
        lastUpdateDate = Date()
        
        print("💱 CurrencyRateManager: Initialized with current exchange rates (base: USD)")
        print("💱 Example rates: 1 USD = ₱58.693, 1 USD = ¥156.45, 1 USD = €0.9613")
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Data Persistence
    
    private func loadSavedData() {
        // Load currencies
        if let primaryData = userDefaults.data(forKey: primaryCurrencyKey),
           let primary = try? JSONDecoder().decode(Currency.self, from: primaryData) {
            self.primaryCurrency = primary
        }
        
        if let secondaryData = userDefaults.data(forKey: secondaryCurrencyKey),
           let secondary = try? JSONDecoder().decode(Currency.self, from: secondaryData) {
            self.secondaryCurrency = secondary
        }
        
        // Load conversion rates
        if let ratesData = userDefaults.data(forKey: conversionRatesKey),
           let rates = try? JSONDecoder().decode(ConversionRates.self, from: ratesData) {
            self.conversionRates = rates
        }
        
        // Load historical rates database
        if let historicalData = userDefaults.data(forKey: historicalRatesKey),
           let historical = try? JSONDecoder().decode(HistoricalRatesDatabase.self, from: historicalData) {
            self.historicalRatesDatabase = historical
        } else {
            // Initialize with sample historical data if none exists
            initializeHistoricalRates()
        }
        
        // Load last update date
        if let lastUpdate = userDefaults.object(forKey: lastUpdateDateKey) as? Date {
            self.lastUpdateDate = lastUpdate
        }
    }
    
    func saveData() {
        // Save currencies
        if let primaryData = try? JSONEncoder().encode(primaryCurrency) {
            userDefaults.set(primaryData, forKey: primaryCurrencyKey)
        }
        
        if let secondaryData = try? JSONEncoder().encode(secondaryCurrency) {
            userDefaults.set(secondaryData, forKey: secondaryCurrencyKey)
        }
        
        // Save conversion rates
        if let ratesData = try? JSONEncoder().encode(conversionRates) {
            userDefaults.set(ratesData, forKey: conversionRatesKey)
        }
        
        // Save historical rates database
        if let historicalData = try? JSONEncoder().encode(historicalRatesDatabase) {
            userDefaults.set(historicalData, forKey: historicalRatesKey)
        }
        
        // Save last update date
        if let lastUpdate = lastUpdateDate {
            userDefaults.set(lastUpdate, forKey: lastUpdateDateKey)
        }
        
        userDefaults.synchronize()
    }
    
    // MARK: - Currency Management
    
    func setPrimaryCurrency(_ currency: Currency) {
        let oldPrimary = primaryCurrency
        primaryCurrency = currency
        saveData()
        
        // Clear stored rates when primary currency changes to force fresh fetch
        if oldPrimary != currency {
            print("🔄 RateManager: Primary currency changed from \(oldPrimary.rawValue) to \(currency.rawValue) - clearing old rates")
            conversionRates = ConversionRates() // Clear old rates
            lastUpdateDate = nil // Force refresh
            
            // Convert all existing transactions to new primary currency using historical snapshot rates
            print("📊 Starting batch conversion of all transactions to new primary currency...")
            convertAllTransactionsToNewPrimaryCurrency(currency)
        }
        
        // Fetch new rates if online
        if isOnline {
            fetchTodaysRates()
        }
    }
    
    func setSecondaryCurrency(_ currency: Currency?) {
        secondaryCurrency = currency
        saveData()
        
        // Fetch new rates if online
        if isOnline {
            fetchTodaysRates()
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                
                // Fetch rates when coming online
                if path.status == .satisfied {
                    self?.fetchTodaysRatesIfNeeded()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Rate Fetching
    
    func fetchTodaysRatesIfNeeded() {
        guard isOnline else { return }
        
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        
        // Check if we already have today's rate
        if conversionRates.getRate(for: today) != nil {
            // Check if we should refresh (optional: refresh every few hours)
            if let lastUpdate = lastUpdateDate,
               Date().timeIntervalSince(lastUpdate) < 4 * 3600 { // 4 hours
                return
            }
        }
        
        fetchTodaysRates()
    }
    
    func fetchTodaysRates() {
        guard isOnline else { return }
        
        print("🌐 Fetching today's conversion rates: \(primaryCurrency.rawValue) <-> \(secondaryCurrency?.rawValue ?? "none")")
        
        // Mock API call - replace with actual API
        fetchMockRates { [weak self] rate in
            DispatchQueue.main.async {
                self?.updateTodaysRate(primaryToSecondary: rate)
            }
        }
    }
    
    private func fetchMockRates(completion: @escaping (Double) -> Void) {
        // Mock network delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            guard let secondary = self.secondaryCurrency else {
                completion(1.0) // Default rate if no secondary currency
                return
            }
            let rate = self.getMockExchangeRate(from: self.primaryCurrency, to: secondary)
            completion(rate)
        }
    }
    
    private func updateTodaysRate(primaryToSecondary: Double) {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        conversionRates.setRate(for: today, primaryToSecondary: primaryToSecondary)
        lastUpdateDate = Date()
        saveData()
        
        print("💾 Saved today's rate: 1 \(primaryCurrency.rawValue) = \(primaryToSecondary) \(secondaryCurrency?.rawValue ?? "unknown")")
    }
    
    // MARK: - Rate Retrieval
    
    func getTodaysRate() -> DailyRate? {
        return conversionRates.getTodayRate()
    }
    
    func getRate(for date: Date) -> DailyRate? {
        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        return conversionRates.getRate(for: dateString)
    }
    
    // MARK: - Conversion Helpers
    
    func convertAmount(_ amount: Double, from fromCurrency: Currency, to toCurrency: Currency) -> Double {
        print("💱 CurrencyRateManager: Converting \(amount) \(fromCurrency.rawValue) → \(toCurrency.rawValue)")
        
        // Same currency, no conversion needed
        if fromCurrency == toCurrency {
            print("💱 No conversion needed (same currency)")
            return amount
        }
        
        // Use comprehensive exchange rates if available
        if let rates = multiCurrencyRates {
            let convertedAmount = rates.convert(amount: amount, from: fromCurrency, to: toCurrency)
            print("💱 Converted: \(amount) \(fromCurrency.rawValue) → \(convertedAmount) \(toCurrency.rawValue)")
            
            // Calculate and log exchange rate for transparency
            let rate: Double
            if amount != 0.0 {
                rate = convertedAmount / amount
            } else {
                // When amount is 0, calculate rate directly from exchange rates
                if fromCurrency == rates.baseCurrency {
                    rate = rates.rates[toCurrency.rawValue] ?? 1.0
                } else if toCurrency == rates.baseCurrency {
                    rate = 1.0 / (rates.rates[fromCurrency.rawValue] ?? 1.0)
                } else {
                    let fromRate = rates.rates[fromCurrency.rawValue] ?? 1.0
                    let toRate = rates.rates[toCurrency.rawValue] ?? 1.0
                    rate = toRate / fromRate
                }
            }
            print("💱 Exchange rate used: 1 \(fromCurrency.rawValue) = \(String(format: "%.4f", rate)) \(toCurrency.rawValue)")
            
            return convertedAmount
        }
        
        // Fallback to legacy system for primary/secondary conversion
        if let todaysRate = getTodaysRate(),
           let secondary = secondaryCurrency {
            if fromCurrency == primaryCurrency && toCurrency == secondary {
                let convertedAmount = amount * todaysRate.primaryToSecondary
                print("💱 Legacy conversion (primary→secondary): \(amount) * \(todaysRate.primaryToSecondary) = \(convertedAmount)")
                return convertedAmount
            } else if fromCurrency == secondary && toCurrency == primaryCurrency {
                let convertedAmount = amount * todaysRate.secondaryToPrimary
                print("💱 Legacy conversion (secondary→primary): \(amount) * \(todaysRate.secondaryToPrimary) = \(convertedAmount)")
                return convertedAmount
            }
        }
        
        // Final fallback - use mock rates
        print("⚠️ CurrencyRateManager: Using fallback mock rates")
        let rate = getMockExchangeRate(from: fromCurrency, to: toCurrency)
        let convertedAmount = amount * rate
        print("💱 Mock conversion: \(amount) * \(rate) = \(convertedAmount)")
        return convertedAmount
    }
    
    // MARK: - Historical Snapshot Conversion
    
    /// Convert amount using historical exchange rates from a specific date (snapshot)
    func convertAmountUsingSnapshot(
        _ amount: Double,
        from fromCurrency: Currency,
        to toCurrency: Currency,
        snapshotDate: Date
    ) -> Double {
        print("📊 Converting \(amount) \(fromCurrency.rawValue) → \(toCurrency.rawValue) using snapshot from \(DateFormatter.yyyyMMdd.string(from: snapshotDate))")
        
        // Same currency, no conversion needed
        if fromCurrency == toCurrency {
            print("📊 No conversion needed (same currency)")
            return amount
        }
        
        // Try to get historical rates for the exact date
        if let historicalRates = historicalRatesDatabase.getRates(for: DateFormatter.yyyyMMdd.string(from: snapshotDate)) {
            let convertedAmount = historicalRates.convert(amount: amount, from: fromCurrency, to: toCurrency)
            print("📊 Snapshot conversion successful: \(amount) → \(convertedAmount) (exact date)")
            return convertedAmount
        }
        
        // Try to find nearest historical rates within 7 days
        if let nearestRates = historicalRatesDatabase.findNearestRates(to: snapshotDate, within: 7) {
            let convertedAmount = nearestRates.convert(amount: amount, from: fromCurrency, to: toCurrency)
            print("📊 Snapshot conversion successful: \(amount) → \(convertedAmount) (nearest date: \(nearestRates.date))")
            return convertedAmount
        }
        
        // Fallback to current rates if no historical data available
        print("⚠️ No historical rates found for \(DateFormatter.yyyyMMdd.string(from: snapshotDate)), using current rates")
        return convertAmount(amount, from: fromCurrency, to: toCurrency)
    }
    
    /// Convert all transactions to a new primary currency using their original snapshot dates
    func convertAllTransactionsToNewPrimaryCurrency(_ newPrimaryCurrency: Currency) {
        print("🔄 Converting all transactions to new primary currency: \(newPrimaryCurrency.rawValue)")
        
        let userManager = UserManager.shared
        let allTransactions = userManager.getTransactions()
        var updatedTransactions: [Txn] = []
        
        for transaction in allTransactions {
            // Skip if transaction doesn't need conversion
            guard let originalAmount = transaction.originalAmount,
                  let originalCurrency = transaction.originalCurrency else {
                print("⏭️ Skipping transaction without original currency data: \(transaction.id.uuidString.prefix(8))")
                continue
            }
            
            // Convert using snapshot date (transaction date)
            let newConvertedAmount = convertAmountUsingSnapshot(
                originalAmount,
                from: originalCurrency,
                to: newPrimaryCurrency,
                snapshotDate: transaction.date
            )
            
            // Calculate new exchange rate
            let newExchangeRate = originalAmount != 0 ? newConvertedAmount / originalAmount : 1.0
            
            // Apply correct sign based on income/expense (preserve original sign logic)
            let finalAmount = transaction.amount < 0 ? -abs(newConvertedAmount) : abs(newConvertedAmount)
            
            // Create updated transaction
            let updatedTransaction = Txn(
                txID: transaction.txID,
                accountID: transaction.accountID,
                walletID: transaction.walletID,
                category: transaction.category,
                categoryId: transaction.categoryId,
                amount: finalAmount,
                date: transaction.date,
                createdAt: transaction.createdAt,
                receiptImage: transaction.receiptImage,
                hasReceiptImage: transaction.hasReceiptImage,
                merchantName: transaction.merchantName,
                paymentMethod: transaction.paymentMethod,
                receiptNumber: transaction.receiptNumber,
                invoiceNumber: transaction.invoiceNumber,
                items: transaction.items,
                note: transaction.note,
                originalAmount: originalAmount, // Keep original
                originalCurrency: originalCurrency, // Keep original
                primaryCurrency: newPrimaryCurrency, // Update to new primary
                secondaryCurrency: transaction.secondaryCurrency,
                exchangeRate: newExchangeRate, // Update exchange rate
                secondaryAmount: transaction.secondaryAmount,
                secondaryExchangeRate: transaction.secondaryExchangeRate
            )
            
            updatedTransactions.append(updatedTransaction)
            
            print("✅ Converted transaction \(transaction.id.uuidString.prefix(8)): \(originalCurrency.symbol)\(originalAmount) → \(newPrimaryCurrency.symbol)\(abs(finalAmount))")
        }
        
        // Batch update all transactions
        if !updatedTransactions.isEmpty {
            for updatedTransaction in updatedTransactions {
                userManager.updateTransaction(updatedTransaction)
            }
            print("🎯 Successfully converted \(updatedTransactions.count) transactions to \(newPrimaryCurrency.rawValue)")
        } else {
            print("ℹ️ No transactions required conversion")
        }
    }
    
    // MARK: - Transaction Currency Conversion
    
    /// Create a transaction with automatic currency conversion to user's primary currency
    func createTransaction(
        accountID: UUID,
        walletID: UUID?,
        category: String,
        categoryId: UUID?,
        originalAmount: Double,
        originalCurrency: Currency,
        date: Date,
        merchantName: String? = nil,
        note: String? = nil,
        paymentMethod: String? = nil,
        receiptNumber: String? = nil,
        invoiceNumber: String? = nil,
        items: [ReceiptItem] = [],
        isIncome: Bool = false,
        receiptImage: UIImage? = nil
    ) -> Txn {
        
        let userPrimaryCurrency = CurrencyPreferences.shared.primaryCurrency
        print("💱 Creating transaction: \(originalAmount) \(originalCurrency.rawValue) → \(userPrimaryCurrency.rawValue) (isIncome: \(isIncome))")
        
        // Only convert if currencies are different
        let convertedAmount: Double
        let exchangeRate: Double
        
        if originalCurrency == userPrimaryCurrency {
            // Same currency - no conversion needed
            print("💱 Same currency, no conversion needed")
            convertedAmount = abs(originalAmount)
            exchangeRate = 1.0
        } else {
            // Different currency - convert amount
            print("💱 Different currency, converting...")
            convertedAmount = convertAmount(abs(originalAmount), from: originalCurrency, to: userPrimaryCurrency)
            exchangeRate = originalAmount != 0 ? convertedAmount / abs(originalAmount) : 1.0
        }
        
        // Apply correct sign based on income/expense
        let finalAmount = isIncome ? abs(convertedAmount) : -abs(convertedAmount)
        
        print("💱 Conversion result: \(abs(originalAmount)) → \(convertedAmount) (rate: \(exchangeRate))")
        print("💱 Final amount with sign: \(finalAmount)")
        
        // Only use user-provided notes, don't add automatic currency conversion info
        let finalNote = note
        
        return Txn(
            txID: UUID(),
            accountID: accountID,
            walletID: walletID,
            category: category,
            categoryId: categoryId,
            amount: finalAmount,
            date: date,
            createdAt: Date(),
            receiptImage: receiptImage,
            hasReceiptImage: receiptImage != nil,
            merchantName: merchantName,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber,
            invoiceNumber: invoiceNumber,
            items: items,
            note: finalNote,
            originalAmount: abs(originalAmount),
            originalCurrency: originalCurrency,
            primaryCurrency: userPrimaryCurrency,
            secondaryCurrency: CurrencyPreferences.shared.secondaryCurrency,
            exchangeRate: exchangeRate,
            secondaryAmount: nil, // Could add secondary conversion later
            secondaryExchangeRate: nil,
            userEnteredAmount: abs(originalAmount), // What user actually typed
            userEnteredCurrency: originalCurrency  // Currency user was working in
        )
    }
    
    // MARK: - Mock Exchange Rates (Replace with real API)
    
    private func getMockExchangeRate(from: Currency, to: Currency) -> Double {
        print("🔍 CURRENCY DEBUG: 🎭 getMockExchangeRate called")
        print("🔍 CURRENCY DEBUG: From: \(from.rawValue) → To: \(to.rawValue)")
        
        let rate: Double
        switch (from, to) {
        case (.usd, .php): rate = 56.0
        case (.php, .usd): rate = 1.0/56.0
        case (.eur, .php): rate = 61.0
        case (.php, .eur): rate = 1.0/61.0
        case (.usd, .eur): rate = 0.92
        case (.eur, .usd): rate = 1.09
        case (.gbp, .php): rate = 71.0
        case (.php, .gbp): rate = 1.0/71.0
        case (.usd, .gbp): rate = 0.79
        case (.gbp, .usd): rate = 1.27
        // Add YEN conversions that were missing!
        case (.php, .jpy): rate = 2.6014 // 1 PHP = 2.6014 JPY
        case (.jpy, .php): rate = 1.0/2.6014 // 1 JPY = 0.3844 PHP
        case (.usd, .jpy): rate = 145.68 // 1 USD = 145.68 JPY
        case (.jpy, .usd): rate = 1.0/145.68 // 1 JPY = 0.00686 USD
        default: rate = 1.0
        }
        
        print("🔍 CURRENCY DEBUG: Mock rate found: \(rate)")
        return rate
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Debug Helper
#if DEBUG
private func testCurrencyAccess() {
    let _ = Currency.usd // This should compile if Currency is accessible
}
#endif