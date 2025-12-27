//
//  PostHogManager.swift
//  CashMonki
//
//  Centralized PostHog analytics integration
//

import Foundation
import SwiftUI
import UIKit

#if canImport(PostHog)
import PostHog
#endif

// MARK: - Analytics Events

enum AnalyticsEvent: String {
    // App Lifecycle
    case appLaunched = "app_launched"
    case appBecameActive = "app_became_active"
    case appResignedActive = "app_resigned_active"

    // Onboarding
    case onboardingStarted = "onboarding_started"
    case onboardingStepCompleted = "onboarding_step_completed"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"

    // Transactions
    case transactionCreated = "transaction_created"
    case transactionEdited = "transaction_edited"
    case transactionDeleted = "transaction_deleted"
    case transactionViewed = "transaction_viewed"

    // Receipt Scanning
    case receiptScanStarted = "receipt_scan_started"
    case receiptScanCompleted = "receipt_scan_completed"
    case receiptScanFailed = "receipt_scan_failed"

    // Wallets
    case walletCreated = "wallet_created"
    case walletEdited = "wallet_edited"
    case walletDeleted = "wallet_deleted"
    case walletSwitched = "wallet_switched"

    // Categories
    case categoryCreated = "category_created"
    case categoryEdited = "category_edited"
    case categoryDeleted = "category_deleted"

    // Budgets
    case budgetCreated = "budget_created"
    case budgetEdited = "budget_edited"
    case budgetDeleted = "budget_deleted"

    // Currency
    case currencyChanged = "currency_changed"
    case currencyConversionUsed = "currency_conversion_used"

    // Subscription
    case paywallViewed = "paywall_viewed"
    case subscriptionStarted = "subscription_started"
    case subscriptionCancelled = "subscription_cancelled"
    case trialStarted = "trial_started"

    // Settings
    case settingsOpened = "settings_opened"
    case languageChanged = "language_changed"

    // Errors
    case errorOccurred = "error_occurred"
    case syncFailed = "sync_failed"
}

// MARK: - PostHog Manager

#if canImport(PostHog)
class PostHogManager: ObservableObject {
    static let shared = PostHogManager()

    // MARK: - Configuration
    // Note: PostHog is initialized via PostHogAppDelegate for early startup
    // This manager provides convenience methods for tracking events

    private var isConfigured: Bool {
        // Check if SDK is already set up via AppDelegate
        return true // Always true since AppDelegate handles setup
    }

    // MARK: - Published Properties

    @Published var isSessionReplayEnabled: Bool = true

    // MARK: - Initialization

    private init() {}

    // MARK: - Event Capture

    func capture(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        guard isConfigured else {
            print("⚠️ PostHog: Not configured - call configure() first")
            return
        }

        if let properties = properties {
            PostHogSDK.shared.capture(event.rawValue, properties: properties)
        } else {
            PostHogSDK.shared.capture(event.rawValue)
        }

        #if DEBUG
        print("📊 PostHog: Captured '\(event.rawValue)' \(properties != nil ? "with properties" : "")")
        #endif
    }

    func captureCustom(_ eventName: String, properties: [String: Any]? = nil) {
        guard isConfigured else {
            print("⚠️ PostHog: Not configured - call configure() first")
            return
        }

        if let properties = properties {
            PostHogSDK.shared.capture(eventName, properties: properties)
        } else {
            PostHogSDK.shared.capture(eventName)
        }

        #if DEBUG
        print("📊 PostHog: Captured custom '\(eventName)'")
        #endif
    }

    // MARK: - Screen Tracking

    func screen(_ screenName: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }

        PostHogSDK.shared.screen(screenName, properties: properties)

        #if DEBUG
        print("📊 PostHog: Screen '\(screenName)'")
        #endif
    }

    // MARK: - User Identification

    func identify(userId: String, properties: [String: Any]? = nil) {
        guard isConfigured else {
            print("⚠️ PostHog: Not configured - call configure() first")
            return
        }

        PostHogSDK.shared.identify(userId, userProperties: properties)
        print("✅ PostHog: User identified - \(userId.prefix(8))...")
    }

    func identifyWithEmail(userId: String, email: String, name: String? = nil) {
        var properties: [String: Any] = ["email": email]
        if let name = name {
            properties["name"] = name
        }

        // Mark internal users based on email domain or specific emails
        let internalEmails = [
            "dcardinesiii@gmail.com",
            "dante@rosebudstudio.com"
        ]
        let internalDomains = [
            "@rosebudstudio.com"
        ]

        let isInternal = internalEmails.contains(email.lowercased()) ||
                         internalDomains.contains(where: { email.lowercased().hasSuffix($0) })

        if isInternal {
            properties["is_internal"] = true
            print("📊 PostHog: Marked user as internal")
        }

        identify(userId: userId, properties: properties)
    }

    // MARK: - User Properties

    func setUserProperties(_ properties: [String: Any]) {
        guard isConfigured else { return }

        // Re-identify with updated properties
        let distinctId = PostHogSDK.shared.getDistinctId()
        PostHogSDK.shared.identify(distinctId, userProperties: properties)
    }

    func registerSuperProperties(_ properties: [String: Any]) {
        guard isConfigured else { return }

        for (key, value) in properties {
            PostHogSDK.shared.register([key: value])
        }
    }

    // MARK: - Groups (for multi-account analytics)

    func setGroup(type: String, key: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }

        PostHogSDK.shared.group(type: type, key: key, groupProperties: properties)
    }

    // MARK: - Feature Flags

    func isFeatureEnabled(_ flagKey: String) -> Bool {
        guard isConfigured else { return false }
        return PostHogSDK.shared.isFeatureEnabled(flagKey)
    }

    func getFeatureFlag(_ flagKey: String) -> Any? {
        guard isConfigured else { return nil }
        return PostHogSDK.shared.getFeatureFlag(flagKey)
    }

    func reloadFeatureFlags(completion: (() -> Void)? = nil) {
        guard isConfigured else { return }

        PostHogSDK.shared.reloadFeatureFlags {
            print("✅ PostHog: Feature flags reloaded")
            completion?()
        }
    }

    // MARK: - Session Management

    func reset() {
        guard isConfigured else { return }

        PostHogSDK.shared.reset()
        print("🔄 PostHog: Session reset")
    }

    func flush() {
        guard isConfigured else { return }

        PostHogSDK.shared.flush()
        print("📤 PostHog: Events flushed")
    }

    // MARK: - Opt In/Out

    func optOut() {
        guard isConfigured else { return }
        PostHogSDK.shared.optOut()
        print("🔒 PostHog: User opted out of tracking")
    }

    func optIn() {
        guard isConfigured else { return }
        PostHogSDK.shared.optIn()
        print("✅ PostHog: User opted in to tracking")
    }

    var isOptedOut: Bool {
        guard isConfigured else { return false }
        return PostHogSDK.shared.isOptOut()
    }

    // MARK: - Convenience Methods for Common Events

    func trackTransactionCreated(amount: Double, currency: String, category: String, isIncome: Bool) {
        capture(.transactionCreated, properties: [
            "amount": amount,
            "currency": currency,
            "category": category,
            "is_income": isIncome
        ])
    }

    func trackReceiptScan(success: Bool, merchant: String? = nil, errorMessage: String? = nil) {
        if success {
            capture(.receiptScanCompleted, properties: [
                "merchant": merchant ?? "unknown"
            ])
        } else {
            capture(.receiptScanFailed, properties: [
                "error": errorMessage ?? "unknown"
            ])
        }
    }

    func trackOnboardingStep(_ step: String, stepNumber: Int) {
        capture(.onboardingStepCompleted, properties: [
            "step_name": step,
            "step_number": stepNumber
        ])
    }

    func trackError(_ error: Error, context: String) {
        capture(.errorOccurred, properties: [
            "error_message": error.localizedDescription,
            "context": context
        ])
    }

    func trackPaywallViewed(source: String, hasUsedTrial: Bool) {
        capture(.paywallViewed, properties: [
            "source": source,
            "has_used_trial": hasUsedTrial
        ])
    }
}

#else
// MARK: - Fallback Implementation (when PostHog is not available)

class PostHogManager: ObservableObject {
    static let shared = PostHogManager()

    @Published var isSessionReplayEnabled: Bool = false

    private init() {}

    func configure() {
        print("❌ PostHog: SDK not available - add PostHog package via SPM")
    }

    func configureAsync() async {
        print("❌ PostHog: SDK not available")
    }

    func capture(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {}
    func captureCustom(_ eventName: String, properties: [String: Any]? = nil) {}
    func screen(_ screenName: String, properties: [String: Any]? = nil) {}
    func identify(userId: String, properties: [String: Any]? = nil) {}
    func identifyWithEmail(userId: String, email: String, name: String? = nil) {}
    func setUserProperties(_ properties: [String: Any]) {}
    func registerSuperProperties(_ properties: [String: Any]) {}
    func setGroup(type: String, key: String, properties: [String: Any]? = nil) {}
    func isFeatureEnabled(_ flagKey: String) -> Bool { false }
    func getFeatureFlag(_ flagKey: String) -> Any? { nil }
    func reloadFeatureFlags(completion: (() -> Void)? = nil) {}
    func reset() {}
    func flush() {}
    func optOut() {}
    func optIn() {}
    var isOptedOut: Bool { false }

    func trackTransactionCreated(amount: Double, currency: String, category: String, isIncome: Bool) {}
    func trackReceiptScan(success: Bool, merchant: String? = nil, errorMessage: String? = nil) {}
    func trackOnboardingStep(_ step: String, stepNumber: Int) {}
    func trackError(_ error: Error, context: String) {}
    func trackPaywallViewed(source: String, hasUsedTrial: Bool) {}
}

#endif
