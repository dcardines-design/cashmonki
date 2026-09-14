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

#if canImport(AdServices)
import AdServices
#endif

// MARK: - Analytics Events

enum AnalyticsEvent: String {
    // App Lifecycle
    case appLaunched = "app_launched"
    // No became-active / resigned-active cases: PostHog's built-in
    // Application Opened / Application Backgrounded already cover them.

    // Onboarding
    case onboardingStarted = "onboarding_started"
    case onboardingStepCompleted = "onboarding_step_completed"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case onboardingGoalsSelected = "onboarding_goals_selected"
    case onboardingStressSelected = "onboarding_stress_selected"
    case onboardingOverspentSelected = "onboarding_overspent_selected"
    case onboardingTrackingDifficultySelected = "onboarding_tracking_difficulty_selected"
    case onboardingIdealOutcomeSelected = "onboarding_ideal_outcome_selected"
    case onboardingTrackingFrequencySelected = "onboarding_tracking_frequency_selected"
    case onboardingTrackingMethodSelected = "onboarding_tracking_method_selected"
    case onboardingValueFeatureViewed = "onboarding_value_feature_viewed"
    case onboardingNameCollected = "onboarding_name_collected"

    // Transactions
    case transactionCreated = "transaction_created"
    case transactionEdited = "transaction_edited"
    case transactionDeleted = "transaction_deleted"
    case transactionViewed = "transaction_viewed"

    // Receipt Scanning
    case receiptScanStarted = "receipt_scan_started"
    case receiptScanCompleted = "receipt_scan_completed"
    case receiptScanFailed = "receipt_scan_failed"

    // Roast My Receipt
    case roastMessageTriggered = "roast_message_triggered"
    case roastMessageAttached = "roast_message_attached"

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

    // Recurring / Subscriptions (expense tracking)
    case subscriptionCreated = "recurring_subscription_created"
    case subscriptionEdited = "recurring_subscription_edited"
    case subscriptionDeleted = "recurring_subscription_deleted"
    case subscriptionPaused = "recurring_subscription_paused"
    case subscriptionResumed = "recurring_subscription_resumed"
    case subscriptionTransactionGenerated = "recurring_transaction_generated"

    // Currency
    case currencyChanged = "currency_changed"
    // No currency_conversion_used: conversion runs on every row render, so an
    // event there would be volume noise, not a signal.

    // Subscription
    case paywallViewed = "paywall_viewed"
    case subscriptionStarted = "subscription_started"
    case subscriptionCancelled = "subscription_cancelled"
    case trialStarted = "trial_started"

    // Ask (AI chat)
    case askMessageSent = "ask_message_sent"
    case askReplyReceived = "ask_reply_received"
    case askReplyFailed = "ask_reply_failed"
    case askReplyUnrenderable = "ask_reply_unrenderable"
    case askLimitReached = "ask_limit_reached"
    case askCardShown = "ask_card_shown"
    case askCardConfirmed = "ask_card_confirmed"
    case askCardCancelled = "ask_card_cancelled"
    case askCardSuperseded = "ask_card_superseded"
    case askBatchRowsAdded = "ask_batch_rows_added"

    // Feedback board
    case feedbackSubmitted = "feedback_submitted"
    case feedbackUpvoted = "feedback_upvoted"
    case feedbackCommented = "feedback_commented"
    case feedbackDeleted = "feedback_deleted"
    case feedbackApproved = "feedback_approved"
    case feedbackStatusChanged = "feedback_status_changed"

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

    // MARK: - Internal/Test Device

    private let internalDeviceKey = "posthog_is_internal_device"

    /// Check if this device is marked as internal/test
    var isInternalDevice: Bool {
        get { UserDefaults.standard.bool(forKey: internalDeviceKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: internalDeviceKey)
            if newValue {
                // Register as super property so all events include this
                PostHogSDK.shared.register(["is_internal": true, "is_test_device": true])
                print("🔧 PostHog: Device marked as INTERNAL - all events will include is_internal=true")
            } else {
                PostHogSDK.shared.unregister("is_internal")
                PostHogSDK.shared.unregister("is_test_device")
                print("🔧 PostHog: Device unmarked as internal")
            }
        }
    }

    /// Mark this device as internal/test (persists across app restarts)
    func markAsInternalDevice() {
        isInternalDevice = true
    }

    /// Unmark this device as internal/test
    func unmarkAsInternalDevice() {
        isInternalDevice = false
    }

    // MARK: - Published Properties

    @Published var isSessionReplayEnabled: Bool = true

    // MARK: - Initialization

    // MARK: - Build environment

    /// Where this build came from: "debug" (Xcode/simulator), "testflight" (sandbox
    /// receipt) or "app_store". Registered as a super property so every event
    /// carries it and dashboards can exclude beta traffic.
    static var buildEnvironment: String {
        #if DEBUG
        return "debug"
        #elseif targetEnvironment(simulator)
        return "debug"
        #else
        // TestFlight installs ship a "sandboxReceipt"; App Store installs a "receipt".
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "app_store"
        #endif
    }

    /// True only for real App Store installs.
    static var isProductionInstall: Bool { buildEnvironment == "app_store" }

    /// Stamps every event with the build environment so dashboards can exclude
    /// TestFlight/debug traffic. Called right after PostHogSDK.setup().
    func registerBuildEnvironment() {
        PostHogSDK.shared.register([
            "app_environment": Self.buildEnvironment,
            "is_production_install": Self.isProductionInstall
        ])
        print("📊 PostHog: app_environment=\(Self.buildEnvironment)")
    }

    // MARK: - Acquisition attribution

    private let installDateKey = "attribution_install_date"
    private let installVersionKey = "attribution_install_version"
    private let searchAdsKey = "attribution_search_ads_payload"

    /// Stamps every event with where this install came from, so marketing spend can be
    /// tied to activation and revenue. Without this, campaign performance is unmeasurable.
    /// Call once, right after registerBuildEnvironment().
    func registerAttribution() {
        let defaults = UserDefaults.standard
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // First launch on this device defines the install cohort. Persisted so the
        // values stay stable for the lifetime of the install.
        if defaults.string(forKey: installDateKey) == nil {
            defaults.set(ISO8601DateFormatter().string(from: Date()), forKey: installDateKey)
            defaults.set(version, forKey: installVersionKey)
        }

        PostHogSDK.shared.register([
            "install_date": defaults.string(forKey: installDateKey) ?? "",
            "install_version": defaults.string(forKey: installVersionKey) ?? version,
            "current_version": version
        ])

        if let cached = defaults.dictionary(forKey: searchAdsKey) {
            PostHogSDK.shared.register(cached)
        } else {
            fetchSearchAdsAttribution()
        }
    }

    /// Resolves the Apple Search Ads attribution token into campaign/ad-group/keyword ids.
    /// Apple's endpoint 404s for a short window after install, so this retries a few times.
    private func fetchSearchAdsAttribution(attempt: Int = 0) {
        #if canImport(AdServices)
        guard #available(iOS 14.3, *) else { return }
        guard attempt < 3 else {
            print("📊 PostHog: Search Ads attribution gave up after \(attempt) attempts")
            return
        }

        let token: String
        do {
            token = try AAAttribution.attributionToken()
        } catch {
            print("📊 PostHog: no Search Ads attribution token (\(error.localizedDescription))")
            return
        }

        var request = URLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            // 404 means Apple has not finished processing the token yet.
            guard status == 200, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let delay = Double(attempt + 1) * 5.0
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.fetchSearchAdsAttribution(attempt: attempt + 1)
                }
                return
            }

            var props: [String: Any] = ["acquisition_source": "apple_search_ads"]
            if let attributed = json["attribution"] as? Bool, attributed == false {
                props["acquisition_source"] = "organic"
            }
            for key in ["campaignId", "adGroupId", "keywordId", "countryOrRegion", "clickDate", "conversionType"] {
                if let value = json[key] {
                    props["asa_\(key)"] = value
                }
            }

            UserDefaults.standard.set(props, forKey: self.searchAdsKey)
            PostHogSDK.shared.register(props)
            PostHogSDK.shared.capture("attribution_resolved", properties: props)
            print("📊 PostHog: attribution resolved — \(props["acquisition_source"] ?? "unknown")")
        }.resume()
        #endif
    }

    private init() {
        // Re-register internal flag on init if device was previously marked
        if UserDefaults.standard.bool(forKey: internalDeviceKey) {
            PostHogSDK.shared.register(["is_internal": true, "is_test_device": true])
            print("🔧 PostHog: Internal device flag restored from previous session")
        }
    }

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

    static var buildEnvironment: String { "unavailable" }
    static var isProductionInstall: Bool { false }

    private init() {}

    func registerBuildEnvironment() {}
    func registerAttribution() {}

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
