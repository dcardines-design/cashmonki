//
//  DummyDataGenerator.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import Foundation
import UIKit

enum DummyDataGenerator {
    
    // MARK: - Helper Methods
    
    /// Safely get current user ID, with fallback if UserManager isn't ready
    private static func getCurrentUserId() -> UUID {
        // For now, return UserManager.shared.currentUser.id since we fixed the initialization order
        // If crashes persist, we can add more safety checks here
        return UserManager.shared.currentUser.id
    }
    
    // Generate a detailed sample transaction from the SAMPLE-RECEIPT asset
    static func generateSampleReceiptTransaction() -> Txn {
        // Load the sample receipt image from assets
        let receiptImage = UIImage(named: "SAMPLE-RECEIPT")
        
        // Create receipt item from the sample receipt (Claude Pro subscription)
        let claudeProItem = ReceiptItem(
            description: "Claude Pro",
            quantity: 1,
            unitPrice: 20.00,
            totalPrice: 20.00
        )
        
        // 🔥 SET Claude Pro transaction to FIXED DATE: October 23, 2025
        let cal = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 10
        dateComponents.day = 23
        dateComponents.hour = Int.random(in: 7...23)
        dateComponents.minute = Int.random(in: 0...59)
        
        let receiptDate = cal.date(from: dateComponents) ?? Date()
        print("🔥 DummyDataGenerator: Claude Pro transaction set to FIXED DATE: October 23, 2025 - \(receiptDate)")
        
        // Create historical createdAt for Claude Pro transaction - simulate it was added a few days after receipt date
        let daysAfterReceipt = Int.random(in: 2...5)
        let hoursAfterReceipt = Int.random(in: 3...7)
        let historicalCreatedAt = cal.date(byAdding: .day, value: daysAfterReceipt, to: receiptDate) ?? receiptDate
        let finalCreatedAt = cal.date(byAdding: .hour, value: hoursAfterReceipt, to: historicalCreatedAt) ?? historicalCreatedAt
        
        return Txn(
            userId: getCurrentUserId(),
            category: "Utilities", // Software/AI service fits under Utilities
            amount: -1120.00, // Negative for expense (20 USD * 56 exchange rate = 1120 PHP)
            date: receiptDate,
            createdAt: finalCreatedAt, // ✅ Now uses historical timestamp!
            receiptImage: receiptImage,
            merchantName: "Anthropic, PBC",
            paymentMethod: "VISA - 6174",
            receiptNumber: "2689-4620-8154",
            invoiceNumber: "XWF05DEX-0001",
            items: [claudeProItem],
            originalAmount: 20.00,
            originalCurrency: .usd,
            primaryCurrency: .php, // Convert to PHP as primary currency
            exchangeRate: 56.0 // 1 USD = 56 PHP (approximate rate)
        )
    }
    
    static func generateRandom() -> [Txn] {
        
        let cal = Calendar.current
        let currentDate = Date()
        var all: [Txn] = []
        
        // Use historical timestamp for creationTime - simulate transactions were added in October 2025
        let historicalCreationStart = cal.date(from: DateComponents(year: 2025, month: 10, day: 31, hour: 23, minute: 59)) ?? currentDate
        var creationTime = historicalCreationStart // Start from historical date and work backwards
        
        // Generate transactions spread across recent days for proper day separation
        
        for _ in 1...2 {
            
            // Generate 8-15 transactions per month (reduced for Sept/Oct only)
            let transactionCount = Int.random(in: 8...15)
            
            for i in 0..<transactionCount {
                // 🔥 SPREAD TRANSACTIONS ACROSS LAST 7 DAYS for proper day separation
                let randomHour = Int.random(in: 7...23)
                let randomMinute = Int.random(in: 0...59)
                
                // Spread transactions across last 7 days (more recent days get more transactions)
                let daysBack = Int.random(in: 0...6) // 0-6 days ago
                let baseDate = cal.date(byAdding: .day, value: -daysBack, to: currentDate) ?? currentDate
                
                var dateComponents = cal.dateComponents([.year, .month, .day], from: baseDate)
                dateComponents.hour = randomHour
                dateComponents.minute = randomMinute
                
                let transactionDate = cal.date(from: dateComponents) ?? baseDate
                print("🔥 DummyDataGenerator: Transaction \(i+1) set to \(daysBack) days ago: \(transactionDate)")
                
                // Decide if this will be a business or personal transaction
                let isBusinessTransaction = Int.random(in: 1...100) <= 30 // 30% business
                
                let category: String
                let merchant: String
                let amount: Double
                let assignedAccountId: UUID
                
                if isBusinessTransaction {
                    // 🏢 BUSINESS TRANSACTIONS (Rosebud Studio)
                    let isBusinessIncome = Int.random(in: 1...100) <= 25 // 25% income for business
                    
                    if isBusinessIncome {
                        // Business income
                        let businessIncomeCategories = ["Business Income", "Services", "Business Income", "Business Income"]
                        let businessIncomeMerchants = [
                            "Business Income": ["Brand Identity Project", "Logo Design Client", "Web Design Project", "Branding Package"],
                            "Services": ["Marketing Consultation", "Brand Strategy Session", "Design Consultation", "Creative Direction"]
                        ]
                        
                        category = businessIncomeCategories.randomElement()!
                        let merchantList = businessIncomeMerchants[category] ?? ["Business Client"]
                        merchant = merchantList.randomElement()!
                        amount = Double(Int.random(in: 15000...75000)) // Business income range
                    } else {
                        // Business expenses
                        let businessCategories = ["Subscriptions", "Supplies", "Dining", "Tech", "Tech", "Utilities", "Services"]
                        let businessMerchants = [
                            "Subscriptions": ["Adobe Creative Suite", "Figma Pro", "Slack Premium", "Notion Team", "Canva Pro", "Dropbox Business"],
                            "Supplies": ["Office Depot", "Staples", "Amazon Business", "Best Buy Business", "Costco Business"],
                            "Dining": ["Client Lunch", "Team Dinner", "Business Meeting", "Networking Event", "Conference Meal"],
                            "Tech": ["MacBook Pro", "iPad Pro", "Camera Equipment", "Lighting Setup", "Monitor", "External Drive", "Facebook Ads", "Google Ads"],
                            "Utilities": ["Internet Bill", "Phone Bill", "Cloud Storage", "VPN Service", "Security Software"],
                            "Services": ["Accountant", "Lawyer", "Business Consultant", "Tax Preparation", "Insurance"]
                        ]
                        
                        category = businessCategories.randomElement()!
                        let merchantList = businessMerchants[category] ?? ["Business Vendor"]
                        merchant = merchantList.randomElement()!
                        amount = -Double(Int.random(in: 500...8000)) // Business expense range
                    }
                    assignedAccountId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")! // Rosebud Studio
                    
                } else {
                    // 👤 PERSONAL TRANSACTIONS
                    let isPersonalIncome = Int.random(in: 1...100) <= 15 // 15% income for personal
                    
                    if isPersonalIncome {
                        // Personal income
                        let personalIncomeCategories = ["Salary", "Passive", "Business Income", "Investment"]
                        let personalIncomeMerchants = [
                            "Salary": ["Monthly Salary", "Bonus Payment", "Overtime Pay", "Commission"],
                            "Passive": ["Stock Dividends", "Mutual Fund Returns", "Investment Portfolio", "REIT Dividends"],
                            "Business Income": ["Freelance Work", "Photography Gig", "Tutoring", "Uber Driving"],
                            "Investment": ["Crypto Gains", "Trading Profit", "Bond Interest", "Savings Interest"]
                        ]
                        
                        category = personalIncomeCategories.randomElement()!
                        let merchantList = personalIncomeMerchants[category] ?? ["Income Source"]
                        merchant = merchantList.randomElement()!
                        amount = Double(Int.random(in: 5000...35000)) // Personal income range
                    } else {
                        // Personal expenses  
                        let personalCategories = ["Food", "Dining", "Transport", "Clothes", "Fun", "Health", "Personal", "Utilities"]
                        let personalMerchants = [
                            "Food": ["SM Supermarket", "Robinsons", "Puregold", "S&R", "Landers", "Metro Market"],
                            "Dining": ["McDonald's", "Jollibee", "KFC", "Pizza Hut", "Starbucks", "Coffee Bean", "Shakey's"],
                            "Transport": ["Grab", "Uber", "Petron", "Shell", "Caltex", "MRT", "Bus Fare"],
                            "Clothes": ["SM Mall", "Ayala Malls", "Uniqlo", "H&M", "Zara", "Nike", "Adidas"],
                            "Fun": ["Netflix", "Spotify", "Cinema", "Concert", "Gaming", "Books"],
                            "Health": ["Mercury Drug", "Watsons", "Hospital", "Dentist", "Gym Membership"],
                            "Personal": ["Haircut", "Spa", "Beauty", "Clothing", "Accessories"],
                            "Utilities": ["Electric Bill", "Water Bill", "Internet", "Mobile Plan", "Insurance"]
                        ]
                        
                        category = personalCategories.randomElement()!
                        let merchantList = personalMerchants[category] ?? ["Personal Vendor"]
                        merchant = merchantList.randomElement()!
                        amount = -Double(Int.random(in: 50...2500)) // Personal expense range
                    }
                    assignedAccountId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")! // Personal
                }
                
                // Each transaction was "added" at different times to simulate realistic creation order
                creationTime = cal.date(byAdding: .minute, value: -Int.random(in: 15...120), to: creationTime) ?? creationTime
                
                all.append(Txn(
                    userId: getCurrentUserId(),
                    category: category,
                    amount: amount,
                    date: transactionDate,
                    createdAt: creationTime,
                    merchantName: merchant,
                    accountId: assignedAccountId
                ))
            }
        }
        
        // Add a sample receipt transaction for demonstration (2 days ago)
        let receiptDate = cal.date(byAdding: .day, value: -2, to: currentDate) ?? currentDate
        let sampleReceiptTransaction = Txn(
            userId: getCurrentUserId(),
            category: "Dining",
            amount: -875.0,
            date: receiptDate, // 2 days ago
            merchantName: "Sample Restaurant",
            accountId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")! // Personal account
        )
        all.append(sampleReceiptTransaction)
        
        // Add some specific time-based transactions across multiple days for better demonstration
        let calendar = Calendar.current
        
        // Create transactions across the last 5 days to show proper day grouping (mix of income and expenses)
        let multiDayTransactions = [
            (merchant: "Coffee Bean", category: "Dining", amount: -285.0, hour: 7, minute: 15, daysAgo: 0), // Today
            (merchant: "Grab", category: "Transport", amount: -175.0, hour: 8, minute: 45, daysAgo: 0), // Today
            (merchant: "Freelance Client", category: "Business Income", amount: 15000.0, hour: 9, minute: 30, daysAgo: 1), // Yesterday - INCOME
            (merchant: "SM Supermarket", category: "Food", amount: -1250.0, hour: 10, minute: 30, daysAgo: 1), // Yesterday
            (merchant: "McDonald's", category: "Dining", amount: -320.0, hour: 12, minute: 20, daysAgo: 2), // 2 days ago
            (merchant: "Stock Dividends", category: "Passive", amount: 8500.0, hour: 13, minute: 15, daysAgo: 2), // 2 days ago - INCOME
            (merchant: "Watsons", category: "Personal", amount: -185.0, hour: 14, minute: 10, daysAgo: 3), // 3 days ago
            (merchant: "App Store", category: "Business Income", amount: 3200.0, hour: 16, minute: 45, daysAgo: 3), // 3 days ago - INCOME
            (merchant: "Petron", category: "Transport", amount: -2800.0, hour: 17, minute: 55, daysAgo: 4), // 4 days ago
            (merchant: "Pizza Hut", category: "Dining", amount: -890.0, hour: 19, minute: 40, daysAgo: 4), // 4 days ago
            (merchant: "Rental Property", category: "Passive", amount: 25000.0, hour: 20, minute: 10, daysAgo: 5), // 5 days ago - INCOME
            (merchant: "7-Eleven", category: "Food", amount: -95.0, hour: 21, minute: 25, daysAgo: 5) // 5 days ago
        ]
        
        for txnData in multiDayTransactions {
            // Calculate the base date by going back the specified number of days
            let baseDate = calendar.date(byAdding: .day, value: -txnData.daysAgo, to: currentDate) ?? currentDate
            
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
            dateComponents.hour = txnData.hour
            dateComponents.minute = txnData.minute
            
            if let txnDate = calendar.date(from: dateComponents) {
                // Create historical createdAt for October 23rd transactions - simulate they were added 1-3 days later
                let daysAfterTransaction = Int.random(in: 1...3)
                let hoursAfterTransaction = Int.random(in: 2...6)
                let historicalCreatedAt = cal.date(byAdding: .day, value: daysAfterTransaction, to: txnDate) ?? txnDate
                let finalCreatedAt = cal.date(byAdding: .hour, value: hoursAfterTransaction, to: historicalCreatedAt) ?? historicalCreatedAt
                
                let txn = Txn(
                    userId: getCurrentUserId(),
                    category: txnData.category,
                    amount: txnData.amount,
                    date: txnDate,
                    createdAt: finalCreatedAt, // ✅ Now uses historical timestamp!
                    merchantName: txnData.merchant,
                    accountId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")! // 👤 Link to Personal account
                )
                all.append(txn)
            }
        }
        
        // 🏢 ROSEBUD STUDIO BUSINESS TRANSACTIONS across multiple days
        print("🏢 DummyDataGenerator: Adding Rosebud Studio business transactions across multiple days...")
        
        let rosebudStudioTransactions = [
            (merchant: "Adobe Creative Suite", category: "Subscriptions", amount: -2999.0, hour: 8, minute: 30, daysAgo: 1), // Yesterday
            (merchant: "Client Payment - Brand Identity", category: "Business Income", amount: 45000.0, hour: 10, minute: 15, daysAgo: 0), // Today - INCOME
            (merchant: "Office Depot", category: "Supplies", amount: -1850.0, hour: 11, minute: 45, daysAgo: 2), // 2 days ago
            (merchant: "Fiverr Freelancer", category: "Services", amount: -8500.0, hour: 13, minute: 20, daysAgo: 1), // Yesterday
            (merchant: "Business Lunch - Client Meeting", category: "Dining", amount: -3200.0, hour: 12, minute: 30, daysAgo: 3), // 3 days ago
            (merchant: "Shopify Monthly", category: "Subscriptions", amount: -1495.0, hour: 14, minute: 10, daysAgo: 4), // 4 days ago
            (merchant: "Stock Photo License", category: "Subscriptions", amount: -750.0, hour: 15, minute: 25, daysAgo: 2), // 2 days ago
            (merchant: "Web Hosting", category: "Utilities", amount: -1200.0, hour: 16, minute: 40, daysAgo: 5), // 5 days ago
            (merchant: "Logo Design Project", category: "Business Income", amount: 28000.0, hour: 17, minute: 55, daysAgo: 3), // 3 days ago - INCOME
            (merchant: "Print Shop - Business Cards", category: "Tech", amount: -2100.0, hour: 18, minute: 20, daysAgo: 4) // 4 days ago
        ]
        
        // Use a fixed UUID for Rosebud Studio account (will match account creation)
        let rosebudStudioAccountId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        
        for txnData in rosebudStudioTransactions {
            // Calculate the base date by going back the specified number of days
            let baseDate = calendar.date(byAdding: .day, value: -txnData.daysAgo, to: currentDate) ?? currentDate
            
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
            dateComponents.hour = txnData.hour
            dateComponents.minute = txnData.minute
            
            if let txnDate = calendar.date(from: dateComponents) {
                // Create historical createdAt for business transactions
                let daysAfterTransaction = Int.random(in: 1...2)
                let hoursAfterTransaction = Int.random(in: 3...8)
                let historicalCreatedAt = cal.date(byAdding: .day, value: daysAfterTransaction, to: txnDate) ?? txnDate
                let finalCreatedAt = cal.date(byAdding: .hour, value: hoursAfterTransaction, to: historicalCreatedAt) ?? historicalCreatedAt
                
                let txn = Txn(
                    userId: getCurrentUserId(),
                    category: txnData.category,
                    amount: txnData.amount,
                    date: txnDate,
                    createdAt: finalCreatedAt,
                    merchantName: txnData.merchant,
                    accountId: rosebudStudioAccountId // 🏢 Link to Rosebud Studio account
                )
                all.append(txn)
            }
        }
        
        print("🏢 DummyDataGenerator: Added \(rosebudStudioTransactions.count) Rosebud Studio business transactions")
        
        // Sort by date (most recent first)
        return all.sorted { $0.date > $1.date }
    }
    
    // MARK: - Fixed Sample Data for Manual Generation
    
    static func generateFixedSampleData() -> [Txn] {
        print("🎯 DummyDataGenerator: Generating FIXED sample data for October 23...")
        
        let userManager = UserManager.shared
        let currentUserId = userManager.currentUser.id
        print("👤 DummyDataGenerator: Current user ID: \(currentUserId.uuidString)")
        print("👤 DummyDataGenerator: Current user name: \(userManager.currentUser.name)")
        
        let cal = Calendar.current
        let currentDate = Date()
        print("📅 DummyDataGenerator: Current date: \(currentDate)")
        
        // FIXED DATE: October 23 (yesterday's date)
        let fixedDate = cal.date(from: DateComponents(year: 2025, month: 10, day: 23)) ?? currentDate
        print("📅 DummyDataGenerator: Fixed date set to: \(fixedDate)")
        
        // FIXED TRANSACTIONS - These never change
        let fixedTransactions = [
            // Personal transactions
            (merchant: "Coffee Bean", category: "Dining", amount: -285.0, hour: 7, minute: 15),
            (merchant: "Grab", category: "Transport", amount: -175.0, hour: 8, minute: 45),
            (merchant: "SM Supermarket", category: "Food", amount: -1250.0, hour: 10, minute: 30),
            (merchant: "McDonald's", category: "Dining", amount: -320.0, hour: 12, minute: 20),
            (merchant: "Watsons", category: "Personal", amount: -185.0, hour: 14, minute: 10),
            (merchant: "Petron", category: "Transport", amount: -2800.0, hour: 17, minute: 55),
            (merchant: "Pizza Hut", category: "Dining", amount: -890.0, hour: 19, minute: 40),
            (merchant: "7-Eleven", category: "Food", amount: -95.0, hour: 21, minute: 25),
            
            // Income transactions
            (merchant: "Freelance Client", category: "Business Income", amount: 15000.0, hour: 9, minute: 30),
            (merchant: "Stock Dividends", category: "Passive", amount: 8500.0, hour: 13, minute: 15),
            (merchant: "Rental Property", category: "Passive", amount: 25000.0, hour: 20, minute: 10),
            
            // Business transactions
            (merchant: "Adobe Creative Suite", category: "Subscriptions", amount: -2999.0, hour: 8, minute: 30),
            (merchant: "Office Depot", category: "Supplies", amount: -1850.0, hour: 11, minute: 45),
            (merchant: "Client Payment - Brand Identity", category: "Business Income", amount: 45000.0, hour: 10, minute: 15),
            (merchant: "Web Hosting", category: "Utilities", amount: -1200.0, hour: 16, minute: 40)
        ]
        
        var transactions: [Txn] = []
        print("🔧 DummyDataGenerator: Processing \(fixedTransactions.count) fixed transactions...")
        
        for (index, txnData) in fixedTransactions.enumerated() {
            print("🔧 Processing transaction \(index + 1): \(txnData.merchant)")
            // Create date with fixed October 23 + specific time
            var dateComponents = cal.dateComponents([.year, .month, .day], from: fixedDate)
            dateComponents.hour = txnData.hour
            dateComponents.minute = txnData.minute
            
            let transactionDate = cal.date(from: dateComponents) ?? fixedDate
            
            // Fixed creation time (slightly after transaction time)
            let createdAt = cal.date(byAdding: .minute, value: Int.random(in: 5...30), to: transactionDate) ?? transactionDate
            
            // Determine account based on transaction type using actual account IDs
            let userManager = UserManager.shared
            let personalAccount = userManager.currentUser.subAccounts.first { $0.name == "Personal" }
            let businessAccount = userManager.currentUser.subAccounts.first { $0.name == "Business" }
            
            let accountId: UUID
            if txnData.category == "Business Income" || txnData.category == "Subscriptions" || 
               txnData.category == "Supplies" || txnData.category == "Utilities" {
                accountId = businessAccount?.id ?? personalAccount?.id ?? UUID()
                print("🏢 Using business account ID: \(accountId.uuidString.prefix(8))...")
            } else {
                accountId = personalAccount?.id ?? UUID()
                print("👤 Using personal account ID: \(accountId.uuidString.prefix(8))...")
            }
            
            let transaction = Txn(
                userId: currentUserId,
                category: txnData.category,
                amount: txnData.amount,
                date: transactionDate,
                createdAt: createdAt,
                merchantName: txnData.merchant,
                accountId: accountId
            )
            
            transactions.append(transaction)
        }
        
        print("🎯 DummyDataGenerator: Generated \(transactions.count) FIXED transactions for October 23, 2025")
        return transactions.sorted { $0.createdAt > $1.createdAt }
    }
}