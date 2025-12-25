//
//  AccountModels.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import Foundation
import SwiftUI

// MARK: - Account Types
enum SubAccountType: String, CaseIterable, Codable {
    case personal = "personal"
    case business = "business" 
    case savings = "savings"
    case investment = "investment"
    case shared = "shared"
    
    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .business: return "Business"
        case .savings: return "Savings"
        case .investment: return "Investment"
        case .shared: return "Shared"
        }
    }
    
    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .business: return "briefcase.fill"
        case .savings: return "banknote.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .shared: return "person.2.fill"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .personal: return .blue
        case .business: return .orange
        case .savings: return Color(hex: "08AD93") ?? .green
        case .investment: return .purple
        case .shared: return .pink
        }
    }
}

// MARK: - Sub Account Model
struct SubAccount: Identifiable, Codable, Hashable {
    let id: UUID
    let parentUserId: UUID         // Links to main user
    let name: String               // "Personal", "Rosebud Studio"
    let type: SubAccountType
    let currency: Currency
    let colorHex: String           // Hex color for UI
    let customIcon: String?        // Optional custom icon
    var isDefault: Bool
    var isActive: Bool
    var balance: Double?           // Optional manual balance
    var showBalance: Bool          // Show balance in preview
    let createdAt: Date
    var updatedAt: Date
    
    // Computed properties
    var color: Color {
        Color(hex: colorHex) ?? type.defaultColor
    }
    
    var displayIcon: String {
        customIcon ?? type.icon
    }
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    init(
        id: UUID = UUID(),
        parentUserId: UUID,
        name: String,
        type: SubAccountType,
        currency: Currency = .php,
        colorHex: String? = nil,
        customIcon: String? = nil,
        isDefault: Bool = false,
        isActive: Bool = true,
        balance: Double? = nil,
        showBalance: Bool = false
    ) {
        self.id = id
        self.parentUserId = parentUserId
        self.name = name
        self.type = type
        self.currency = currency
        self.colorHex = colorHex ?? type.defaultColor.toHex()
        self.customIcon = customIcon
        self.isDefault = isDefault
        self.isActive = isActive
        self.balance = balance
        self.showBalance = showBalance
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Enhanced User Model
extension UserData {
    // Convert AccountData to SubAccount for compatibility
    var subAccounts: [SubAccount] {
        return accounts.map { accountData in
            SubAccount(
                id: accountData.id,
                parentUserId: self.id,
                name: accountData.name,
                type: convertAccountTypeToSubAccountType(accountData.type),
                currency: accountData.currency,
                isDefault: accountData.isDefault,
                balance: accountData.balance,
                showBalance: accountData.showBalance
            )
        }
    }
    
    // Helper to convert between AccountType and SubAccountType
    private func convertAccountTypeToSubAccountType(_ accountType: AccountType) -> SubAccountType {
        switch accountType {
        case .personal: return .personal
        case .business: return .business
        case .savings: return .savings
        case .investment: return .investment
        default: return .personal // fallback for other types
        }
    }
    
    var activeSubAccounts: [SubAccount] {
        return subAccounts.filter { $0.isActive }
    }
    
    var defaultSubAccount: SubAccount? {
        return subAccounts.first { $0.isDefault } ?? subAccounts.first
    }
    
    func subAccount(withId id: UUID) -> SubAccount? {
        return subAccounts.first { $0.id == id }
    }
    
    func transactionsForSubAccount(_ subAccountId: UUID) -> [Txn] {
        return transactions.filter { $0.walletID == subAccountId }
    }
    
    func balanceForSubAccount(_ subAccountId: UUID) -> Double {
        return transactionsForSubAccount(subAccountId).reduce(0) { $0 + $1.amount }
    }
    
    mutating func addSubAccount(_ subAccount: SubAccount) {
        // Convert SubAccount back to AccountData for now
        let accountData = AccountData(
            id: subAccount.id,
            name: subAccount.name,
            type: convertSubAccountTypeToAccountType(subAccount.type),
            currency: subAccount.currency,
            isDefault: subAccount.isDefault,
            balance: subAccount.balance,
            showBalance: subAccount.showBalance
        )

        // If this is the first account, make it default
        var newAccount = accountData
        if accounts.isEmpty {
            newAccount.isDefault = true
        }
        accounts.append(newAccount)
    }
    
    mutating func setDefaultSubAccount(_ subAccountId: UUID) {
        for index in accounts.indices {
            accounts[index].isDefault = (accounts[index].id == subAccountId)
        }
    }
    
    // Helper to convert between SubAccountType and AccountType
    private func convertSubAccountTypeToAccountType(_ subAccountType: SubAccountType) -> AccountType {
        switch subAccountType {
        case .personal: return .personal
        case .business: return .business
        case .savings: return .savings
        case .investment: return .investment
        case .shared: return .personal // fallback - no equivalent in AccountType
        }
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let int = UInt64(hex, radix: 16) else { return nil }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - Account Creation Helpers
extension SubAccount {
    static func createPersonalAccount(for userId: UUID) -> SubAccount {
        return SubAccount(
            id: UUID(), // Always use unique UUIDs
            parentUserId: userId,
            name: "Personal",
            type: .personal,
            currency: .php,
            isDefault: true
        )
    }
    
    static func createBusinessAccount(for userId: UUID, businessName: String = "Business") -> SubAccount {
        // Always use unique UUIDs - no hardcoded IDs
        let businessAccountId = UUID()
            
        return SubAccount(
            id: businessAccountId,
            parentUserId: userId,
            name: businessName,
            type: .business,
            currency: .php,
            colorHex: "#FF6B35" // Orange color
        )
    }
    
    static func createSavingsAccount(for userId: UUID, name: String = "Savings") -> SubAccount {
        return SubAccount(
            parentUserId: userId,
            name: name,
            type: .savings,
            currency: .php,
            colorHex: "#08AD93" // Green color
        )
    }

    /// Computes the current balance based on starting balance + sum of transactions
    /// - Parameter transactions: All transactions to filter by this wallet
    /// - Returns: The computed current balance (starting balance + transaction sum)
    func currentBalance(transactions: [Txn]) -> Double {
        let startingBalance = balance ?? 0
        let transactionTotal = transactions
            .filter { $0.walletID == self.id }
            .reduce(0) { $0 + $1.amount }
        return startingBalance + transactionTotal
    }
}