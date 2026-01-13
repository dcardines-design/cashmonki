//
//  RecurringTransactionManager.swift
//  CashMonki
//
//  Handles automatic generation of recurring transactions
//

import Foundation
import SwiftUI

class RecurringTransactionManager: ObservableObject {
    static let shared = RecurringTransactionManager()

    private let userManager = UserManager.shared

    // UserDefaults key for tracking last check
    private let lastCheckKey = "RecurringTransactionLastCheck"

    // Timer for continuous generation checking (for minute-frequency testing)
    private var generationTimer: Timer?
    private let timerInterval: TimeInterval = 30 // Check every 30 seconds

    private init() {}

    // MARK: - Timer Management

    /// Start the recurring transaction timer (call when app becomes active)
    func startGenerationTimer() {
        stopGenerationTimer() // Clear any existing timer

        generationTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            self?.processRecurringTransactions()
        }

        // Also run immediately
        processRecurringTransactions()
        print("⏰ RecurringTransactionManager: Generation timer started (every \(Int(timerInterval))s)")
    }

    /// Stop the timer (call when app goes to background)
    func stopGenerationTimer() {
        generationTimer?.invalidate()
        generationTimer = nil
        print("⏰ RecurringTransactionManager: Generation timer stopped")
    }

    // MARK: - Public API

    /// Check and generate all due recurring transactions
    /// Call this on app launch and when app becomes active
    func processRecurringTransactions() {
        print("🔄 RecurringTransactionManager: Processing recurring transactions...")

        let templates = getAllActiveRecurringTemplates()

        if templates.isEmpty {
            print("✅ RecurringTransactionManager: No recurring templates found")
            return
        }

        print("🔍 RecurringTransactionManager: Found \(templates.count) active templates")
        for t in templates {
            print("   - \(t.merchantName ?? t.category): freq=\(t.recurringFrequency?.rawValue ?? "nil"), lastGen=\(t.lastGeneratedDate?.description ?? "nil")")
        }

        var generatedCount = 0

        for template in templates {
            let generated = generateDueTransactions(for: template)
            generatedCount += generated.count
        }

        if generatedCount > 0 {
            print("✅ RecurringTransactionManager: Generated \(generatedCount) recurring transactions")
            // Save after all generations
            userManager.saveCurrentUserLocally()
            // Sync to Firebase if enabled
            userManager.syncToFirebase { success in
                if success {
                    print("✅ RecurringTransactionManager: Synced to Firebase")
                }
            }
        } else {
            print("✅ RecurringTransactionManager: No recurring transactions due")
        }

        // Update last check timestamp
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }

    /// Get all recurring transaction templates
    var allRecurringTemplates: [Txn] {
        return userManager.currentUser.transactions.filter { $0.isRecurring }
    }

    /// Get active recurring templates only
    func getAllActiveRecurringTemplates() -> [Txn] {
        return userManager.currentUser.transactions.filter {
            $0.isRecurring && $0.isRecurringActive
        }
    }

    /// Get all transactions generated from a specific template
    func getGeneratedTransactions(for templateId: UUID) -> [Txn] {
        return userManager.currentUser.transactions.filter {
            $0.recurringTemplateId == templateId
        }
    }

    /// Pause a recurring transaction
    func pauseRecurring(_ templateId: UUID) {
        guard let template = userManager.currentUser.transactions.first(where: { $0.id == templateId && $0.isRecurring }) else { return }
        let updatedTemplate = createUpdatedTemplate(template, isActive: false)
        userManager.updateTransaction(updatedTemplate)
        print("⏸️ RecurringTransactionManager: Paused recurring template \(templateId.uuidString.prefix(8))")
    }

    /// Resume a recurring transaction
    func resumeRecurring(_ templateId: UUID) {
        guard let template = userManager.currentUser.transactions.first(where: { $0.id == templateId && $0.isRecurring }) else { return }
        let updatedTemplate = createUpdatedTemplate(template, isActive: true)
        userManager.updateTransaction(updatedTemplate)
        print("▶️ RecurringTransactionManager: Resumed recurring template \(templateId.uuidString.prefix(8))")
    }

    // MARK: - Transaction Type Detection

    /// Check if a transaction is a template (parent recurring)
    func isTemplate(_ transaction: Txn) -> Bool {
        return transaction.isRecurring && transaction.recurringTemplateId == nil
    }

    /// Check if a transaction is a generated child
    func isGeneratedChild(_ transaction: Txn) -> Bool {
        return !transaction.isRecurring && transaction.recurringTemplateId != nil
    }

    /// Get the parent template for a generated child
    func getParentTemplate(for childId: UUID) -> Txn? {
        guard let child = userManager.currentUser.transactions.first(where: { $0.id == childId }),
              let templateId = child.recurringTemplateId else {
            return nil
        }
        return userManager.currentUser.transactions.first(where: { $0.id == templateId })
    }

    // MARK: - Edit Operations

    /// Update all generated children with new values from template
    func updateAllChildren(templateId: UUID, with updatedFields: (Txn) -> Txn) {
        let children = getGeneratedTransactions(for: templateId)

        for child in children {
            let updatedChild = updatedFields(child)
            userManager.updateTransaction(updatedChild)
        }

        print("✏️ RecurringTransactionManager: Updated \(children.count) children for template \(templateId.uuidString.prefix(8))")

        userManager.saveCurrentUserLocally()
        userManager.syncToFirebase { success in
            if success {
                print("✅ RecurringTransactionManager: Child updates synced to Firebase")
            }
        }
    }

    /// Update only future children (children with date >= fromDate)
    func updateFutureChildren(templateId: UUID, with updatedFields: (Txn) -> Txn, fromDate: Date = Date()) {
        let children = getGeneratedTransactions(for: templateId)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: fromDate)
        let futureChildren = children.filter { calendar.startOfDay(for: $0.date) >= startOfToday }

        for child in futureChildren {
            let updatedChild = updatedFields(child)
            userManager.updateTransaction(updatedChild)
        }

        print("✏️ RecurringTransactionManager: Updated \(futureChildren.count) future children for template \(templateId.uuidString.prefix(8))")

        userManager.saveCurrentUserLocally()
        userManager.syncToFirebase { _ in }
    }

    // MARK: - Delete Operations

    /// Delete template with optional cascade to children
    func deleteTemplate(templateId: UUID, deleteChildren: Bool) {
        if deleteChildren {
            // Cascade delete: remove all generated children
            let children = getGeneratedTransactions(for: templateId)
            for child in children {
                userManager.removeTransaction(withId: child.id)
            }
            print("🗑️ RecurringTransactionManager: Deleted \(children.count) child transactions")
        } else {
            // Convert children to standalone (remove template link)
            let children = getGeneratedTransactions(for: templateId)
            for child in children {
                let standaloneChild = createStandaloneTransaction(from: child)
                userManager.updateTransaction(standaloneChild)
            }
            print("🔗 RecurringTransactionManager: Converted \(children.count) children to standalone")
        }

        // Delete the template itself
        userManager.removeTransaction(withId: templateId)
        print("🗑️ RecurringTransactionManager: Deleted template \(templateId.uuidString.prefix(8))")

        userManager.saveCurrentUserLocally()
        userManager.syncToFirebase { success in
            if success {
                print("✅ RecurringTransactionManager: Template deletion synced to Firebase")
            }
        }
    }

    /// Delete a generated child and optionally stop future occurrences
    func deleteGeneratedChild(childId: UUID, stopFuture: Bool) {
        guard let child = userManager.currentUser.transactions.first(where: { $0.id == childId }) else {
            print("⚠️ RecurringTransactionManager: Child transaction \(childId.uuidString.prefix(8)) not found")
            return
        }

        // Delete the child
        userManager.removeTransaction(withId: childId)
        print("🗑️ RecurringTransactionManager: Deleted child transaction \(childId.uuidString.prefix(8))")

        // Optionally deactivate parent
        if stopFuture, let templateId = child.recurringTemplateId {
            pauseRecurring(templateId)
            print("⏸️ RecurringTransactionManager: Paused parent template \(templateId.uuidString.prefix(8))")
        }

        userManager.saveCurrentUserLocally()
        userManager.syncToFirebase { _ in }
    }

    /// Create a standalone version of a generated transaction (removes template link)
    private func createStandaloneTransaction(from child: Txn) -> Txn {
        return Txn(
            txID: child.txID,
            accountID: child.accountID,
            walletID: child.walletID,
            category: child.category,
            categoryId: child.categoryId,
            amount: child.amount,
            date: child.date,
            createdAt: child.createdAt,
            receiptImage: nil,
            hasReceiptImage: child.hasReceiptImage,
            merchantName: child.merchantName,
            paymentMethod: child.paymentMethod,
            receiptNumber: child.receiptNumber,
            invoiceNumber: child.invoiceNumber,
            items: child.items,
            note: child.note,
            originalAmount: child.originalAmount,
            originalCurrency: child.originalCurrency,
            primaryCurrency: child.primaryCurrency,
            secondaryCurrency: child.secondaryCurrency,
            exchangeRate: child.exchangeRate,
            secondaryAmount: child.secondaryAmount,
            secondaryExchangeRate: child.secondaryExchangeRate,
            userEnteredAmount: child.userEnteredAmount,
            userEnteredCurrency: child.userEnteredCurrency,
            // Clear recurring fields to make standalone
            isRecurring: false,
            recurringFrequency: nil,
            recurringTemplateId: nil,  // Remove template link
            lastGeneratedDate: nil,
            isRecurringActive: false
        )
    }

    // MARK: - Private Methods

    /// Generate all due transactions for a template (handles catch-up)
    private func generateDueTransactions(for template: Txn) -> [Txn] {
        guard let frequency = template.recurringFrequency else {
            print("⚠️ RecurringTransactionManager: Template \(template.id.uuidString.prefix(8)) has no frequency")
            return []
        }

        var generated: [Txn] = []
        let now = Date()
        let calendar = Calendar.current

        // Determine the starting point for generation
        // Use lastGeneratedDate if available, otherwise use the transaction's date
        let startDate = template.lastGeneratedDate ?? template.date

        // Calculate all due dates between last generation and now
        var nextDate = frequency.nextOccurrence(from: startDate)

        print("🔍 Generation check for \(template.merchantName ?? template.category):")
        print("   - startDate: \(formatDate(startDate))")
        print("   - nextDate: \(formatDate(nextDate))")
        print("   - now: \(formatDate(now))")
        print("   - nextDate <= now: \(nextDate <= now)")

        while nextDate <= now {
            // Check for duplicate (same template + same date/minute depending on frequency)
            if !transactionExistsForDate(templateId: template.id, date: nextDate, frequency: frequency) {
                let newTransaction = createTransactionFromTemplate(template, forDate: nextDate)
                userManager.addTransaction(newTransaction)
                generated.append(newTransaction)
                print("💰 RecurringTransactionManager: Generated \(template.merchantName ?? template.category) for \(formatDate(nextDate))")
            } else {
                print("⏭️ RecurringTransactionManager: Skipped duplicate for \(formatDate(nextDate))")
            }

            // Move to next occurrence
            nextDate = frequency.nextOccurrence(from: nextDate)
        }

        // Update the template's lastGeneratedDate to the last generated transaction's date
        // This keeps the schedule precise (e.g., every minute on the minute)
        if let lastGenerated = generated.last {
            updateTemplateLastGenerated(template, to: lastGenerated.date)
        }

        return generated
    }

    /// Check if a transaction already exists for this template on this date
    /// For minute frequency: check same minute
    /// For other frequencies: check same day
    private func transactionExistsForDate(templateId: UUID, date: Date, frequency: RecurringFrequency? = nil) -> Bool {
        let calendar = Calendar.current
        return userManager.currentUser.transactions.contains { txn in
            guard txn.recurringTemplateId == templateId else { return false }

            // For 5-minute frequency, check within same 5-minute window (for testing)
            if frequency == .fiveMinutes {
                let txnComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: txn.date)
                let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                return txnComponents == dateComponents
            }

            // For all other frequencies, check same day
            return calendar.isDate(txn.date, inSameDayAs: date)
        }
    }

    /// Create a new transaction from template
    private func createTransactionFromTemplate(_ template: Txn, forDate date: Date) -> Txn {
        return Txn(
            txID: UUID(),
            accountID: template.accountID,
            walletID: template.walletID,
            category: template.category,
            categoryId: template.categoryId,
            amount: template.amount,
            date: date,
            createdAt: Date(),
            receiptImage: nil,
            hasReceiptImage: false,
            merchantName: template.merchantName,
            paymentMethod: template.paymentMethod,
            receiptNumber: nil,
            invoiceNumber: nil,
            items: [],
            note: template.note,
            originalAmount: template.originalAmount,
            originalCurrency: template.originalCurrency,
            primaryCurrency: template.primaryCurrency,
            secondaryCurrency: template.secondaryCurrency,
            exchangeRate: template.exchangeRate,
            secondaryAmount: template.secondaryAmount,
            secondaryExchangeRate: template.secondaryExchangeRate,
            userEnteredAmount: template.userEnteredAmount,
            userEnteredCurrency: template.userEnteredCurrency,
            // Generated transactions are NOT recurring themselves
            isRecurring: false,
            recurringFrequency: nil,
            recurringTemplateId: template.id, // Link back to parent template
            lastGeneratedDate: nil,
            isRecurringActive: false
        )
    }

    /// Update template's lastGeneratedDate
    private func updateTemplateLastGenerated(_ template: Txn, to date: Date) {
        let updatedTemplate = Txn(
            txID: template.txID,
            accountID: template.accountID,
            walletID: template.walletID,
            category: template.category,
            categoryId: template.categoryId,
            amount: template.amount,
            date: template.date,
            createdAt: template.createdAt,
            receiptImage: nil,
            hasReceiptImage: template.hasReceiptImage,
            merchantName: template.merchantName,
            paymentMethod: template.paymentMethod,
            receiptNumber: template.receiptNumber,
            invoiceNumber: template.invoiceNumber,
            items: template.items,
            note: template.note,
            originalAmount: template.originalAmount,
            originalCurrency: template.originalCurrency,
            primaryCurrency: template.primaryCurrency,
            secondaryCurrency: template.secondaryCurrency,
            exchangeRate: template.exchangeRate,
            secondaryAmount: template.secondaryAmount,
            secondaryExchangeRate: template.secondaryExchangeRate,
            userEnteredAmount: template.userEnteredAmount,
            userEnteredCurrency: template.userEnteredCurrency,
            // Preserve recurring fields, update lastGeneratedDate
            isRecurring: template.isRecurring,
            recurringFrequency: template.recurringFrequency,
            recurringTemplateId: template.recurringTemplateId,
            lastGeneratedDate: date,
            isRecurringActive: template.isRecurringActive
        )
        userManager.updateTransaction(updatedTemplate)
    }

    /// Helper to create updated template with active state change
    private func createUpdatedTemplate(_ template: Txn, isActive: Bool) -> Txn {
        return Txn(
            txID: template.txID,
            accountID: template.accountID,
            walletID: template.walletID,
            category: template.category,
            categoryId: template.categoryId,
            amount: template.amount,
            date: template.date,
            createdAt: template.createdAt,
            receiptImage: nil,
            hasReceiptImage: template.hasReceiptImage,
            merchantName: template.merchantName,
            paymentMethod: template.paymentMethod,
            receiptNumber: template.receiptNumber,
            invoiceNumber: template.invoiceNumber,
            items: template.items,
            note: template.note,
            originalAmount: template.originalAmount,
            originalCurrency: template.originalCurrency,
            primaryCurrency: template.primaryCurrency,
            secondaryCurrency: template.secondaryCurrency,
            exchangeRate: template.exchangeRate,
            secondaryAmount: template.secondaryAmount,
            secondaryExchangeRate: template.secondaryExchangeRate,
            userEnteredAmount: template.userEnteredAmount,
            userEnteredCurrency: template.userEnteredCurrency,
            // Update isRecurringActive
            isRecurring: template.isRecurring,
            recurringFrequency: template.recurringFrequency,
            recurringTemplateId: template.recurringTemplateId,
            lastGeneratedDate: template.lastGeneratedDate,
            isRecurringActive: isActive
        )
    }

    /// Format date for logging
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
