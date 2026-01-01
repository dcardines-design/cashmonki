//
//  MixpanelManager.swift
//  CashMonki
//
//  Centralized Mixpanel analytics integration
//

import Foundation
import SwiftUI

#if canImport(Mixpanel)
import Mixpanel
#endif

// MARK: - Mixpanel Manager

#if canImport(Mixpanel)
class MixpanelManager: ObservableObject {
    static let shared = MixpanelManager()

    private var isConfigured = false
    private let internalDeviceKey = "mixpanel_is_internal_device"

    private init() {
        // Re-register internal flag on init if device was previously marked
        if UserDefaults.standard.bool(forKey: internalDeviceKey) && isConfigured {
            Mixpanel.mainInstance().registerSuperProperties(["is_internal": true, "is_test_device": true])
        }
    }

    // MARK: - Internal/Test Device

    /// Check if this device is marked as internal/test
    var isInternalDevice: Bool {
        get { UserDefaults.standard.bool(forKey: internalDeviceKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: internalDeviceKey)
            guard isConfigured else { return }
            if newValue {
                Mixpanel.mainInstance().registerSuperProperties(["is_internal": true, "is_test_device": true])
                print("🔧 Mixpanel: Device marked as INTERNAL")
            } else {
                Mixpanel.mainInstance().unregisterSuperProperty("is_internal")
                Mixpanel.mainInstance().unregisterSuperProperty("is_test_device")
                print("🔧 Mixpanel: Device unmarked as internal")
            }
        }
    }

    func markAsInternalDevice() {
        isInternalDevice = true
    }

    func unmarkAsInternalDevice() {
        isInternalDevice = false
    }

    // MARK: - Configuration

    func configure(token: String) {
        guard !isConfigured else {
            print("⚠️ Mixpanel: Already configured")
            return
        }

        Mixpanel.initialize(token: token, trackAutomaticEvents: true)
        isConfigured = true
        print("✅ Mixpanel: Initialized with token \(token.prefix(8))...")

        // Re-register internal flag if device was previously marked
        if UserDefaults.standard.bool(forKey: internalDeviceKey) {
            Mixpanel.mainInstance().registerSuperProperties(["is_internal": true, "is_test_device": true])
            print("🔧 Mixpanel: Internal device flag restored from previous session")
        }
    }

    // MARK: - Event Tracking

    func track(_ event: AnalyticsEvent, properties: [String: MixpanelType]? = nil) {
        guard isConfigured else {
            print("⚠️ Mixpanel: Not configured")
            return
        }

        Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)

        #if DEBUG
        print("📊 Mixpanel: Tracked '\(event.rawValue)'")
        #endif
    }

    func trackCustom(_ eventName: String, properties: [String: MixpanelType]? = nil) {
        guard isConfigured else {
            print("⚠️ Mixpanel: Not configured")
            return
        }

        Mixpanel.mainInstance().track(event: eventName, properties: properties)

        #if DEBUG
        print("📊 Mixpanel: Tracked custom '\(eventName)'")
        #endif
    }

    // MARK: - User Identification

    func identify(userId: String) {
        guard isConfigured else { return }

        Mixpanel.mainInstance().identify(distinctId: userId)
        print("✅ Mixpanel: User identified - \(userId.prefix(8))...")
    }

    func identifyWithEmail(userId: String, email: String, name: String? = nil) {
        guard isConfigured else { return }

        Mixpanel.mainInstance().identify(distinctId: userId)
        Mixpanel.mainInstance().people.set(properties: [
            "$email": email,
            "$name": name ?? ""
        ])

        // Mark internal users
        let internalEmails = [
            "dcardinesiii@gmail.com",
            "dante@rosebudstudio.com"
        ]
        let internalDomains = ["@rosebudstudio.com"]

        let isInternal = internalEmails.contains(email.lowercased()) ||
                         internalDomains.contains(where: { email.lowercased().hasSuffix($0) })

        if isInternal {
            Mixpanel.mainInstance().people.set(properties: ["is_internal": true])
            print("📊 Mixpanel: Marked user as internal")
        }

        print("✅ Mixpanel: User identified with email")
    }

    // MARK: - User Properties

    func setUserProperties(_ properties: [String: MixpanelType]) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().people.set(properties: properties)
    }

    func incrementUserProperty(_ property: String, by amount: Double = 1) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().people.increment(property: property, by: amount)
    }

    // MARK: - Super Properties (sent with every event)

    func registerSuperProperties(_ properties: [String: MixpanelType]) {
        guard isConfigured else { return }
        Mixpanel.mainInstance().registerSuperProperties(properties)
    }

    // MARK: - Session Management

    func reset() {
        guard isConfigured else { return }
        Mixpanel.mainInstance().reset()
        print("🔄 Mixpanel: Session reset")
    }

    func flush() {
        guard isConfigured else { return }
        Mixpanel.mainInstance().flush()
        print("📤 Mixpanel: Events flushed")
    }

    // MARK: - Opt In/Out

    func optOut() {
        guard isConfigured else { return }
        Mixpanel.mainInstance().optOutTracking()
        print("🔒 Mixpanel: User opted out")
    }

    func optIn() {
        guard isConfigured else { return }
        Mixpanel.mainInstance().optInTracking()
        print("✅ Mixpanel: User opted in")
    }

    // MARK: - Convenience Methods

    func trackTransactionCreated(amount: Double, currency: String, category: String, isIncome: Bool) {
        track(.transactionCreated, properties: [
            "amount": amount,
            "currency": currency,
            "category": category,
            "is_income": isIncome
        ])
    }

    func trackReceiptScan(success: Bool, merchant: String? = nil, errorMessage: String? = nil) {
        if success {
            track(.receiptScanCompleted, properties: [
                "merchant": merchant ?? "unknown"
            ])
        } else {
            track(.receiptScanFailed, properties: [
                "error": errorMessage ?? "unknown"
            ])
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
}

#else
// MARK: - Fallback Implementation (when Mixpanel is not available)

class MixpanelManager: ObservableObject {
    static let shared = MixpanelManager()

    private init() {}

    func configure(token: String) {
        print("❌ Mixpanel: SDK not available - add Mixpanel package via SPM")
    }

    func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {}
    func trackCustom(_ eventName: String, properties: [String: Any]? = nil) {}
    func identify(userId: String) {}
    func identifyWithEmail(userId: String, email: String, name: String? = nil) {}
    func setUserProperties(_ properties: [String: Any]) {}
    func incrementUserProperty(_ property: String, by amount: Double = 1) {}
    func registerSuperProperties(_ properties: [String: Any]) {}
    func reset() {}
    func flush() {}
    func optOut() {}
    func optIn() {}

    func trackTransactionCreated(amount: Double, currency: String, category: String, isIncome: Bool) {}
    func trackReceiptScan(success: Bool, merchant: String? = nil, errorMessage: String? = nil) {}
    func trackOnboardingStep(_ step: String, stepNumber: Int) {}
    func trackError(_ error: Error, context: String) {}
    func trackPaywallViewed(source: String, hasUsedTrial: Bool) {}
}

#endif
