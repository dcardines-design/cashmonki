//
//  AnalyticsManager.swift
//  CashMonki
//
//  Unified analytics manager that sends events to both PostHog and Mixpanel
//

import Foundation

/// Unified analytics manager - sends events to all configured analytics services
/// Use this instead of calling PostHogManager and MixpanelManager directly
class AnalyticsManager {
    static let shared = AnalyticsManager()

    private init() {}

    // MARK: - Event Tracking

    /// Track an event to all analytics services
    func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        // PostHog
        PostHogManager.shared.capture(event, properties: properties)

        // Mixpanel (with automatic type conversion)
        MixpanelManager.shared.trackWithAnyProperties(event.rawValue, properties: properties)

        #if DEBUG
        print("📊 Analytics: Tracked '\(event.rawValue)' to PostHog + Mixpanel")
        #endif
    }

    /// Track a custom event to all analytics services
    func trackCustom(_ eventName: String, properties: [String: Any]? = nil) {
        PostHogManager.shared.captureCustom(eventName, properties: properties)
        MixpanelManager.shared.trackWithAnyProperties(eventName, properties: properties)
    }

    // MARK: - User Identification

    /// Identify user across all analytics services
    func identify(userId: String, email: String? = nil, name: String? = nil) {
        registeredTier = nil  // re-stamp the tier on the identified person
        if let email = email {
            PostHogManager.shared.identifyWithEmail(userId: userId, email: email, name: name)
            MixpanelManager.shared.identifyWithEmail(userId: userId, email: email, name: name)
        } else {
            PostHogManager.shared.identify(userId: userId)
            MixpanelManager.shared.identify(userId: userId)
        }

        print("✅ Analytics: User identified across all services")
    }

    // MARK: - Subscription Tier

    /// Last tier registered with the analytics services; cleared on identify/reset so the
    /// next RevenueCat update stamps the (new) person again.
    private var registeredTier: PlanTier?

    /// Registers the plan as a super property (every event) and person property in
    /// PostHog + Mixpanel: `subscription_tier` (free/plus/pro) alongside `is_pro`.
    func setSubscriptionTier(_ tier: PlanTier) {
        guard registeredTier != tier else { return }
        registeredTier = tier

        let properties: [String: Any] = [
            "subscription_tier": tier.rawValue,
            "is_pro": tier == .pro,
            "is_paid": tier.isPaid
        ]
        PostHogManager.shared.registerSuperProperties(properties)
        PostHogManager.shared.setUserProperties(properties)
        MixpanelManager.shared.registerAnySuperProperties(properties)
        MixpanelManager.shared.setAnyUserProperties(properties)

        print("📊 Analytics: subscription_tier=\(tier.rawValue)")
    }

    // MARK: - Session Management

    /// Reset sessions across all analytics services (on logout)
    func reset() {
        registeredTier = nil
        PostHogManager.shared.reset()
        MixpanelManager.shared.reset()
        print("🔄 Analytics: Sessions reset across all services")
    }

    /// Flush events across all analytics services
    func flush() {
        PostHogManager.shared.flush()
        MixpanelManager.shared.flush()
    }

    // MARK: - Opt In/Out

    func optOut() {
        PostHogManager.shared.optOut()
        MixpanelManager.shared.optOut()
    }

    func optIn() {
        PostHogManager.shared.optIn()
        MixpanelManager.shared.optIn()
    }

    // MARK: - Internal/Test Device

    /// Check if this device is marked as internal/test
    var isInternalDevice: Bool {
        PostHogManager.shared.isInternalDevice
    }

    /// Mark this device as internal/test across all analytics services
    /// All events will include `is_internal = true` and `is_test_device = true`
    /// Persists across app restarts
    func markAsInternalDevice() {
        PostHogManager.shared.markAsInternalDevice()
        MixpanelManager.shared.markAsInternalDevice()
        print("🔧 Analytics: Device marked as INTERNAL across all services")
    }

    /// Unmark this device as internal/test
    func unmarkAsInternalDevice() {
        PostHogManager.shared.unmarkAsInternalDevice()
        MixpanelManager.shared.unmarkAsInternalDevice()
        print("🔧 Analytics: Device unmarked as internal")
    }

    // MARK: - Convenience Methods

    func trackTransactionCreated(amount: Double, currency: String, category: String, isIncome: Bool) {
        let properties: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "category": category,
            "is_income": isIncome
        ]
        track(.transactionCreated, properties: properties)
    }

    func trackReceiptScan(success: Bool, merchant: String? = nil, errorMessage: String? = nil) {
        if success {
            track(.receiptScanCompleted, properties: ["merchant": merchant ?? "unknown"])
        } else {
            track(.receiptScanFailed, properties: ["error": errorMessage ?? "unknown"])
        }
    }

    func trackOnboardingStep(_ step: String, stepNumber: Int) {
        track(.onboardingStepCompleted, properties: [
            "step_name": step,
            "step_number": stepNumber
        ])
    }

    func trackError(_ error: Error, context: String) {
        track(.errorOccurred, properties: [
            "error_message": error.localizedDescription,
            "context": context
        ])
    }

    func trackPaywallViewed(source: String, hasUsedTrial: Bool) {
        track(.paywallViewed, properties: [
            "source": source,
            "has_used_trial": hasUsedTrial
        ])
    }

    func trackScreen(_ screenName: String) {
        PostHogManager.shared.screen(screenName)
        MixpanelManager.shared.trackWithAnyProperties("screen_viewed", properties: ["screen_name": screenName])
    }
}
