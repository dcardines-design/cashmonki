//
//  OnboardingStateManager.swift
//  CashMonki
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Represents different onboarding gates that must be completed
enum OnboardingGate: String, CaseIterable {
    case emailVerification = "email"
    case nameCollection = "name"  
    case currencySelection = "currency"
    case goalSelection = "goals"
    
    var displayName: String {
        switch self {
        case .emailVerification: return "Email Verification"
        case .nameCollection: return "Name Collection"
        case .currencySelection: return "Currency Selection"
        case .goalSelection: return "Goal Selection"
        }
    }
}

/// Represents the current state of onboarding
enum OnboardingState: Codable {
    case notStarted
    case inProgress(step: OnboardingStep, lastActiveTime: Date)
    case completed(completedAt: Date)
    
    var isComplete: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    var currentStep: OnboardingStep? {
        if case .inProgress(let step, _) = self {
            return step
        }
        return nil
    }
}

/// OnboardingStep enum for consistency
enum OnboardingStep: String, Codable, CaseIterable {
    case emailConfirmation
    case nameCollection
    case currencySelection
    case goalSelection
    case transactionAddition
    
    var displayName: String {
        switch self {
        case .emailConfirmation: return "Email Confirmation"
        case .nameCollection: return "Name Collection"
        case .currencySelection: return "Currency Selection"  
        case .goalSelection: return "Goal Selection"
        case .transactionAddition: return "Transaction Addition"
        }
    }
}

/// Centralized onboarding state management
class OnboardingStateManager: ObservableObject {
    static let shared = OnboardingStateManager()
    
    @Published var currentState: OnboardingState = .notStarted
    
    // Grace period for app backgrounding (30 seconds)
    private let gracePeriodSeconds: TimeInterval = 30
    
    // UserDefaults key for persistence
    private let stateKey = "onboardingState"
    
    // Track last app background time for grace period logic
    private var lastBackgroundTime: Date?
    
    private init() {
        loadState()
        setupNotificationObservers()
        print("🎯 OnboardingStateManager: Initialized with state: \(currentState)")
    }
    
    // MARK: - State Management
    
    /// Load onboarding state from persistence
    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(OnboardingState.self, from: data) {
            currentState = state
            print("🎯 OnboardingStateManager: Loaded state from persistence: \(state)")
        } else {
            // Migrate from legacy flags if they exist
            migrateLegacyFlags()
        }
    }
    
    /// Save onboarding state to persistence
    private func saveState() {
        if let data = try? JSONEncoder().encode(currentState) {
            UserDefaults.standard.set(data, forKey: stateKey)
            print("🎯 OnboardingStateManager: Saved state: \(currentState)")
        }
    }
    
    /// Migrate from old boolean flags to new state system
    private func migrateLegacyFlags() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasCompletedCurrency = UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection")
        let hasSetPrimaryCurrency = UserDefaults.standard.bool(forKey: "hasSetPrimaryCurrency")
        let hasCompletedGoals = UserDefaults.standard.bool(forKey: "hasCompletedGoalSelection")
        
        print("🔄 OnboardingStateManager: Migrating legacy flags:")
        print("   - hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("   - hasCompletedCurrency: \(hasCompletedCurrency)")
        print("   - hasSetPrimaryCurrency: \(hasSetPrimaryCurrency)")
        print("   - hasCompletedGoals: \(hasCompletedGoals)")
        
        if hasCompletedOnboarding && hasCompletedCurrency && hasSetPrimaryCurrency && hasCompletedGoals {
            // All legacy flags indicate completion
            currentState = .completed(completedAt: Date())
            saveState()
            print("✅ OnboardingStateManager: Migrated to completed state")
        } else if hasCompletedCurrency || hasCompletedGoals {
            // Partially complete - determine current step
            let step: OnboardingStep = determineCurrentStep()
            currentState = .inProgress(step: step, lastActiveTime: Date())
            saveState()
            print("🔄 OnboardingStateManager: Migrated to in-progress state at step: \(step)")
        } else {
            // No legacy completion
            currentState = .notStarted
            saveState()
            print("🆕 OnboardingStateManager: Migrated to not-started state")
        }
    }
    
    // MARK: - Gate Validation
    
    /// Validate all onboarding gates and return their status
    func validateAllGates() -> [OnboardingGate: Bool] {
        var results: [OnboardingGate: Bool] = [:]
        
        results[.emailVerification] = checkEmailVerificationGate()
        results[.nameCollection] = checkNameCollectionGate()
        results[.currencySelection] = checkCurrencySelectionGate()
        results[.goalSelection] = checkGoalSelectionGate()
        
        print("🔍 OnboardingStateManager: Gate validation results:")
        for (gate, passed) in results {
            print("   \(gate.displayName): \(passed ? "✅" : "❌")")
        }
        
        return results
    }
    
    /// Check if transaction addition is complete (has transaction or was skipped)
    func checkTransactionGate() -> Bool {
        // Simple check: user has completed if they have at least 1 transaction OR clicked "complete"
        let hasTransaction = !UserManager.shared.currentUser.transactions.isEmpty
        let hasSkippedViaComplete = UserDefaults.standard.bool(forKey: "hasCompletedTransactionOnboarding")
        
        let isComplete = hasTransaction || hasSkippedViaComplete
        
        print("🔍 OnboardingStateManager: Transaction gate - complete: \(isComplete)")
        print("   - Has transaction: \(hasTransaction) (count: \(UserManager.shared.currentUser.transactions.count))")
        print("   - Clicked complete: \(hasSkippedViaComplete)")
        
        return isComplete
    }
    
    /// Check if all gates are complete
    func areAllGatesComplete() -> Bool {
        let gateResults = validateAllGates()
        let allComplete = gateResults.values.allSatisfy { $0 }
        
        print("🎯 OnboardingStateManager: All gates complete: \(allComplete)")
        return allComplete
    }
    
    /// Get the next incomplete gate
    func getNextIncompleteGate() -> OnboardingGate? {
        let gateResults = validateAllGates()
        
        // Check gates in logical order
        let orderedGates: [OnboardingGate] = [.emailVerification, .nameCollection, .currencySelection, .goalSelection]
        
        for gate in orderedGates {
            if gateResults[gate] == false {
                return gate
            }
        }
        
        return nil
    }
    
    // MARK: - Individual Gate Checks
    
    private func checkEmailVerificationGate() -> Bool {
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            return false
        }
        
        // Check if user is Google sign-in (Google users are auto-verified)
        let isGoogleUser = currentUser.firebaseUID.hasPrefix("google_") || 
                          isGoogleSignInUser()
        
        if isGoogleUser {
            // Gmail users automatically pass email verification
            print("🔍 OnboardingStateManager: Email gate - Gmail user auto-verified")
            return true
        } else {
            // Regular users need to verify email
            #if canImport(FirebaseAuth)
            let isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false
            print("🔍 OnboardingStateManager: Email gate - regular user verified: \(isEmailVerified)")
            return isEmailVerified
            #else
            // If Firebase not available, assume verified for now
            print("🔍 OnboardingStateManager: Email gate - Firebase not available, assuming verified")
            return true
            #endif
        }
    }
    
    /// Check if current user signed in with Google
    private func isGoogleSignInUser() -> Bool {
        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            return currentUser.providerData.contains { $0.providerID == "google.com" }
        }
        #endif
        return false
    }
    
    private func checkNameCollectionGate() -> Bool {
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            return false
        }
        
        // Simple check: if user has any name saved locally, they've completed name collection
        // This checks user data (not Firebase data) as requested
        let trimmedName = currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLocalName = !trimmedName.isEmpty
        
        print("🔍 OnboardingStateManager: Name gate - '\(currentUser.name)' -> valid: \(hasLocalName)")
        print("   - Local name exists: \(hasLocalName)")
        
        return hasLocalName
    }
    
    private func checkFirebaseDisplayName() -> Bool {
        #if canImport(FirebaseAuth)
        if let firebaseUser = Auth.auth().currentUser,
           let displayName = firebaseUser.displayName {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameComponents = trimmedName.components(separatedBy: " ").filter { !$0.isEmpty }
            let hasMultipleWords = nameComponents.count >= 2
            let hasContent = !trimmedName.isEmpty && trimmedName.count >= 1
            
            let isMeaningfulSingleName = nameComponents.count == 1 && 
                                       trimmedName.count >= 1 &&
                                       !trimmedName.contains("@") && 
                                       !trimmedName.contains("+")
            
            let hasValidFirebaseName = hasContent && (hasMultipleWords || isMeaningfulSingleName)
            
            print("🔥 OnboardingStateManager: Firebase displayName: '\(displayName)' -> valid: \(hasValidFirebaseName)")
            return hasValidFirebaseName
        }
        #endif
        print("🔥 OnboardingStateManager: No Firebase displayName found")
        return false
    }
    
    func checkCurrencySelectionGate() -> Bool {
        // Simple check: if user has a currency saved locally, they've completed currency selection
        let hasPrimaryCurrency = !CurrencyPreferences.shared.primaryCurrency.rawValue.isEmpty
        
        print("🔍 OnboardingStateManager: Currency gate - complete: \(hasPrimaryCurrency)")
        print("   - Primary currency: \(CurrencyPreferences.shared.primaryCurrency.rawValue)")
        print("   - Has currency: \(hasPrimaryCurrency)")
        
        return hasPrimaryCurrency
    }
    
    func checkGoalSelectionGate() -> Bool {
        // Simple check: if user has goals saved locally, they've completed goal selection
        let userManagerUser = UserManager.shared.currentUser
        let hasGoals = userManagerUser.goals != nil && !userManagerUser.goals!.isEmpty
        
        print("🔍 OnboardingStateManager: Goals gate - complete: \(hasGoals)")
        print("   - User goals: '\(userManagerUser.goals ?? "nil")'")
        print("   - Has goals: \(hasGoals)")
        
        return hasGoals
    }
    
    // MARK: - Smart Resume Logic
    
    /// Determine if onboarding should be shown on app resume
    func shouldShowOnboardingOnResume() -> Bool {
        print("🎯 OnboardingStateManager: ======= SMART RESUME CHECK =======")
        print("🎯 OnboardingStateManager: Current state: \(currentState)")
        
        // Check if user is authenticated
        guard AuthenticationManager.shared.isAuthenticated else {
            print("🎯 OnboardingStateManager: User not authenticated - no onboarding needed")
            return false
        }
        
        // SPECIAL CASE: If user has reached the transaction step, never show onboarding again
        let hasReachedTransactionStep = UserDefaults.standard.bool(forKey: "hasReachedTransactionStep")
        if hasReachedTransactionStep {
            print("🎯 OnboardingStateManager: User reached transaction step - no re-onboarding")
            if !currentState.isComplete {
                print("🎯 OnboardingStateManager: Marking as complete since transaction step was reached")
                markAsComplete()
            }
            return false
        }
        
        // If already complete and all gates still pass, don't show
        if currentState.isComplete {
            if areAllGatesComplete() {
                print("✅ OnboardingStateManager: Already complete and all gates valid - no onboarding")
                return false
            } else {
                print("⚠️ OnboardingStateManager: Was complete but gates now failing - needs re-onboarding")
                // Reset to determine current step
                updateState(to: .inProgress(step: determineCurrentStep(), lastActiveTime: Date()))
                return true
            }
        }
        
        // Check grace period for in-progress users
        if case .inProgress(let step, let lastActiveTime) = currentState {
            // SPECIAL CASE: If on transaction step, apply special grace period logic
            if step == .transactionAddition {
                print("🎯 OnboardingStateManager: On transaction step - applying special grace period")
                if let backgroundTime = lastBackgroundTime {
                    let timeSinceBackground = Date().timeIntervalSince(backgroundTime)
                    // For transaction step, any backgrounding skips re-onboarding
                    print("🎯 OnboardingStateManager: Transaction step backgrounded (\(timeSinceBackground)s ago) - marking reached")
                    UserDefaults.standard.set(true, forKey: "hasReachedTransactionStep")
                    markAsComplete()
                    return false
                }
            }
            
            if let backgroundTime = lastBackgroundTime {
                let timeSinceBackground = Date().timeIntervalSince(backgroundTime)
                if timeSinceBackground < gracePeriodSeconds {
                    print("🕐 OnboardingStateManager: Within grace period (\(timeSinceBackground)s < \(gracePeriodSeconds)s) - no onboarding")
                    print("🕐 OnboardingStateManager: Last active: \(lastActiveTime), Background: \(backgroundTime)")
                    return false
                }
            }
            
            // Check if gates are now complete (including transaction gate)
            if areAllGatesComplete() && checkTransactionGate() {
                print("✅ OnboardingStateManager: All gates now complete - marking as finished")
                markAsComplete()
                return false
            }
            
            print("🔄 OnboardingStateManager: In progress at \(step) - continuing onboarding")
            return true
        }
        
        // Not started - check if onboarding is needed
        if areAllGatesComplete() {
            print("✅ OnboardingStateManager: All gates complete - marking as finished")
            markAsComplete()
            return false
        } else {
            print("🆕 OnboardingStateManager: Not started and gates incomplete - starting onboarding")
            updateState(to: .inProgress(step: determineCurrentStep(), lastActiveTime: Date()))
            return true
        }
    }
    
    /// Update the current onboarding state
    func updateState(to newState: OnboardingState) {
        print("🎯 OnboardingStateManager: State transition: \(currentState) -> \(newState)")
        currentState = newState
        saveState()
    }
    
    /// Mark onboarding as complete
    func markAsComplete() {
        print("🎉 OnboardingStateManager: Marking onboarding as COMPLETE")
        updateState(to: .completed(completedAt: Date()))
        
        // Also set legacy flags for backward compatibility
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedCurrencySelection")
        UserDefaults.standard.set(true, forKey: "hasSetPrimaryCurrency")
    }
    
    /// Update progress to a specific step
    func updateProgress(to step: OnboardingStep) {
        print("🔄 OnboardingStateManager: Updating progress to step: \(step)")
        updateState(to: .inProgress(step: step, lastActiveTime: Date()))
    }
    
    /// Determine what step user should be on based on completed gates
    private func determineCurrentStep() -> OnboardingStep {
        let gateResults = validateAllGates()
        
        if !gateResults[.emailVerification]! {
            return .emailConfirmation
        } else if !gateResults[.nameCollection]! {
            return .nameCollection
        } else if !gateResults[.currencySelection]! {
            return .currencySelection
        } else if !gateResults[.goalSelection]! {
            return .goalSelection
        } else if !checkTransactionGate() {
            return .transactionAddition
        } else {
            // All complete - should not reach here
            return .transactionAddition
        }
    }
    
    // MARK: - App Lifecycle Handling
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        lastBackgroundTime = Date()
        print("📱 OnboardingStateManager: App entered background at \(Date())")
        
        // Update last active time for in-progress state
        if case .inProgress(let step, _) = currentState {
            updateState(to: .inProgress(step: step, lastActiveTime: Date()))
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 OnboardingStateManager: App entering foreground")
        
        // Grace period and smart resume logic will be handled by shouldShowOnboardingOnResume()
    }
    
    // MARK: - Debugging and Testing
    
    /// Reset onboarding state (for testing)
    func resetOnboardingState() {
        print("🔄 OnboardingStateManager: RESETTING onboarding state")
        updateState(to: .notStarted)
        
        // Clear legacy flags
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "hasCompletedCurrencySelection")
        UserDefaults.standard.set(false, forKey: "hasSetPrimaryCurrency")
        UserDefaults.standard.set(false, forKey: "hasCompletedGoalSelection")
        
        // Clear goal values
        UserDefaults.standard.removeObject(forKey: "selectedPrimaryGoal")
        UserDefaults.standard.removeObject(forKey: "selectedPrimaryGoals")
        
        // CRITICAL FIX: Clear transaction step flag to prevent blocking new user onboarding
        UserDefaults.standard.set(false, forKey: "hasReachedTransactionStep")
        UserDefaults.standard.set(false, forKey: "hasSkippedTransactionOnboarding")
        
        print("🔄 OnboardingStateManager: Cleared all onboarding flags and goal values")
    }
    
    /// Get detailed state information for debugging
    func getDebugInfo() -> String {
        let gateResults = validateAllGates()
        
        var info = """
        🎯 OnboardingStateManager Debug Info:
        📊 Current State: \(currentState)
        📱 Last Background: \(lastBackgroundTime?.description ?? "Never")
        🕐 Grace Period: \(gracePeriodSeconds)s
        
        🚪 Gate Status:
        """
        
        for gate in OnboardingGate.allCases {
            let status = gateResults[gate] == true ? "✅" : "❌"
            info += "\n   \(status) \(gate.displayName)"
        }
        
        return info
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}