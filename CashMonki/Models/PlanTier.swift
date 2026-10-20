//
//  PlanTier.swift
//  CashMonki
//
//  Single source of truth for what each plan unlocks.
//  The active tier is resolved from RevenueCat entitlements in RevenueCatManager.
//

import Foundation

/// The user's plan. Resolved from RevenueCat entitlements:
/// `cashmonki-subs` → Pro, else `cashmonki-plus` → Plus, else Free.
/// Existing subscribers (`cashmonki-subs`) are Pro.
enum PlanTier: String, CaseIterable {
    case free
    case plus
    case pro

    // MARK: - RevenueCat identifiers

    /// Entitlement for Pro (the original subscription; existing subscribers keep it).
    static let proEntitlementID = "cashmonki-subs"
    /// Entitlement for the Plus products.
    static let plusEntitlementID = "cashmonki-plus"

    // MARK: - Limits (nil = unlimited)

    /// Daily Ask (AI chat) messages. Pro's cap is a fair-use ceiling, not a selling point.
    static let freeDailyAskLimit = 3
    static let plusDailyAskLimit = 10
    static let proDailyAskLimit = 100

    /// Daily receipt analyses (scan + upload).
    static let freeDailyScanLimit = 3
    static let plusDailyScanLimit = 10

    /// Wallets (accounts). Plus and Pro are unlimited.
    static let freeWalletLimit = 2

    /// Recurring items (subscriptions tracked in the app). Plus and Pro are unlimited.
    static let freeRecurringLimit = 2

    /// Messages per day in Ask.
    var dailyAskLimit: Int {
        switch self {
        case .free: return Self.freeDailyAskLimit
        case .plus: return Self.plusDailyAskLimit
        case .pro: return Self.proDailyAskLimit
        }
    }

    /// Receipt analyses per day; nil means unlimited.
    var dailyScanLimit: Int? {
        switch self {
        case .free: return Self.freeDailyScanLimit
        case .plus: return Self.plusDailyScanLimit
        case .pro: return nil
        }
    }

    /// Wallets the user can hold; nil means unlimited.
    var walletLimit: Int? {
        self == .free ? Self.freeWalletLimit : nil
    }

    /// Recurring items the user can track; nil means unlimited.
    var recurringLimit: Int? {
        self == .free ? Self.freeRecurringLimit : nil
    }

    /// Creating and editing custom categories (Plus and Pro).
    var allowsCustomCategories: Bool {
        self != .free
    }

    /// Any paid plan (Plus or Pro).
    var isPaid: Bool {
        self != .free
    }

    // MARK: - Debug override

    /// DEBUG-only: `-forceTier free|plus|pro` launch argument (read from the
    /// argument domain of UserDefaults) pins the tier so UI tests can exercise each plan.
    static var debugForcedTier: PlanTier? {
        #if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: "forceTier") else { return nil }
        return PlanTier(rawValue: raw.lowercased())
        #else
        return nil
        #endif
    }
}

/// Package identifiers in the `cashmonki-tiers` offering.
enum TierPackageID: String, CaseIterable {
    case plusMonthly = "plus_monthly"
    case plusYearly = "plus_yearly"
    case proMonthly = "pro_monthly"
    case proYearly = "pro_yearly"

    /// Offering that carries the Plus/Pro packages (paywall redesign).
    static let offeringID = "cashmonki-tiers"

    var tier: PlanTier {
        switch self {
        case .plusMonthly, .plusYearly: return .plus
        case .proMonthly, .proYearly: return .pro
        }
    }
}
