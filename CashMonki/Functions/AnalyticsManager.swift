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

        // Mixpanel (MixpanelManager handles the type conversion internally)
        MixpanelManager.shared.trackCustom(event.rawValue, properties: nil)

        #if DEBUG
        print("📊 Analytics: Tracked '\(event.rawValue)' to PostHog + Mixpanel")
        #endif
    }

    /// Track a custom event to all analytics services
    func trackCustom(_ eventName: String, properties: [String: Any]? = nil) {
        PostHogManager.shared.captureCustom(eventName, properties: properties)
        MixpanelManager.shared.trackCustom(eventName, properties: nil)
    }

    // MARK: - User Identification

    /// Identify user across all analytics services
    func identify(userId: String, email: String? = nil, name: String? = nil) {
        if let email = email {
            PostHogManager.shared.identifyWithEmail(userId: userId, email: email, name: name)
            MixpanelManager.shared.identifyWithEmail(userId: userId, email: email, name: name)
        } else {
            PostHogManager.shared.identify(userId: userId)
            MixpanelManager.shared.identify(userId: userId)
        }

        print("✅ Analytics: User identified across all services")
    }

    // MARK: - Session Management

    /// Reset sessions across all analytics services (on logout)
    func reset() {
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
        MixpanelManager.shared.trackCustom("screen_viewed", properties: nil)
    }
}
