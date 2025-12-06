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
    
    // MARK: - Numerical Progression System
    
    /// Get current onboarding step based on user's progression number
    /// 0=not started, 1=email done, 2=name done, 3=currency done, 4=goals done, 5=complete
    func getCurrentOnboardingStep() -> OnboardingStep {
        let user = UserManager.shared.currentUser
        
        // Auto-migrate legacy users if they haven't been migrated
        if user.onboardingCompleted == 0 && !hasMigrationCompleted() {
            migrateLegacyUserToNumericalSystem()
        }
        
        let progressNumber = user.onboardingCompleted
        print("🔢 OnboardingStateManager: Current progression number: \(progressNumber)")
        
        switch progressNumber {
        case 0:
            // Not started - determine initial step
            return determineInitialStep()
        case 1:
            // Email done, show name collection
            print("🔢 Next step: Name Collection (email completed)")
            return .nameCollection
        case 2:
            // Name done, show currency selection
            print("🔢 Next step: Currency Selection (name completed)")
            return .currencySelection
        case 3:
            // Currency done, show goal selection
            print("🔢 Next step: Goal Selection (currency completed)")
            return .goalSelection
        case 4:
            // Goals done, show transaction addition
            print("🔢 Next step: Transaction Addition (goals completed)")
            return .transactionAddition
        case 5:
            // Fully complete
            print("🔢 Onboarding fully complete")
            return .transactionAddition // Fallback, shouldn't show onboarding
        default:
            // Invalid progression number - fix it
            if progressNumber > 5 {
                print("🚨 INVALID progression number \(progressNumber) > 5 - correcting to 5 (complete)")
                UserManager.shared.updateOnboardingProgress(5)
                return .transactionAddition
            } else if progressNumber < 0 {
                print("🚨 INVALID progression number \(progressNumber) < 0 - correcting to 0 (not started)")
                UserManager.shared.updateOnboardingProgress(0)
                return determineInitialStep()
            } else {
                print("⚠️ Unknown progression number \(progressNumber), defaulting to email confirmation")
                return .emailConfirmation
            }
        }
    }
    
    /// Determine initial step for new users (progression = 0)
    private func determineInitialStep() -> OnboardingStep {
        print("🔢 Determining initial step for new user...")
        
        #if canImport(FirebaseAuth)
        // Check if this is a Google user with verified email
        if let currentUser = Auth.auth().currentUser {
            let isGoogleSignIn = currentUser.providerData.contains { $0.providerID == "google.com" }
            
            if isGoogleSignIn {
                print("🔢 Google user detected - checking current progression")
                let currentProgress = UserManager.shared.currentUser.onboardingCompleted
                
                if currentProgress == 0 {
                    print("🔢 Google user at step 0 - setting progression to 1 (email verified) and showing name collection")
                    // For Google users, set progression to 1 (email verified) and show name collection
                    setOnboardingProgress(to: 1)
                    return .nameCollection
                } else {
                    print("🔢 Google user already has progression \(currentProgress) - determining step from progression")
                    // User already has progression, determine step directly from number
                    switch currentProgress {
                    case 1: return .nameCollection
                    case 2: return .currencySelection
                    case 3: return .goalSelection
                    case 4: return .transactionAddition
                    case 5: return .transactionAddition // Complete
                    default: return .emailConfirmation
                    }
                }
            }
        }
        #endif
        
        // Regular users start with email verification
        print("🔢 Regular user - starting at email confirmation (step 1)")
        return .emailConfirmation
    }
    
    /// Set user to specific onboarding progression number
    func setOnboardingProgress(to targetProgress: Int) {
        let currentProgress = UserManager.shared.currentUser.onboardingCompleted
        
        // Validate target progression
        if targetProgress < 0 || targetProgress > 5 {
            print("🚨 OnboardingStateManager: INVALID target progression \(targetProgress) - must be 0-5")
            return
        }
        
        // CRITICAL FIX: Never downgrade progression to prevent race conditions
        if targetProgress < currentProgress {
            print("🚨 OnboardingStateManager: PREVENTING downgrade from \(currentProgress) to \(targetProgress)")
            print("   - This prevents race conditions during migration")
            return
        }
        
        print("🔢 Setting onboarding progression: \(currentProgress) → \(targetProgress)")
        UserManager.shared.updateOnboardingProgress(targetProgress)
        
        // Mark as complete if we've reached the final step
        if targetProgress >= 5 {
            print("🎉 OnboardingStateManager: Reached progression 5 - marking onboarding as complete")
            markAsComplete()
        }
    }
    
    /// Legacy method - use setOnboardingProgress(to:) instead
    @available(*, deprecated, message: "Use setOnboardingProgress(to:) instead")
    func advanceToNextStep() {
        let currentProgress = UserManager.shared.currentUser.onboardingCompleted
        let nextProgress = min(currentProgress + 1, 5) // Safety cap at 5
        setOnboardingProgress(to: nextProgress)
    }
    
    /// Check if onboarding is fully complete
    func isOnboardingComplete() -> Bool {
        return UserManager.shared.currentUser.onboardingCompleted >= 5
    }
    
    /// Migrate existing users from legacy gate system to numerical progression
    func migrateLegacyUserToNumericalSystem() {
        let user = UserManager.shared.currentUser
        
        // Skip migration if user already has a progression number > 0
        if user.onboardingCompleted > 0 {
            print("🔄 OnboardingStateManager: User already has progression number \(user.onboardingCompleted), skipping migration")
            return
        }
        
        // CRITICAL FIX: Prevent multiple migrations in the same session
        if UserDefaults.standard.bool(forKey: "migrationInProgress") {
            print("🚨 OnboardingStateManager: Migration already in progress - skipping to prevent race condition")
            return
        }
        
        // Set migration lock
        UserDefaults.standard.set(true, forKey: "migrationInProgress")
        
        print("🔄 OnboardingStateManager: ======= MIGRATING LEGACY USER =======")
        print("🔄 Starting migration from legacy gate system to numerical progression")
        
        // Check each gate and determine highest completed step
        var highestCompletedStep = 0
        
        // Email verification (step 1)
        if checkEmailVerificationGate() {
            highestCompletedStep = 1
            print("🔄 Migration: Email verification ✅ → progression: 1")
        }
        
        // Name collection (step 2)
        if checkNameCollectionGate() {
            highestCompletedStep = 2
            print("🔄 Migration: Name collection ✅ → progression: 2")
        }
        
        // Currency selection (step 3)
        if checkCurrencySelectionGate() {
            highestCompletedStep = 3
            print("🔄 Migration: Currency selection ✅ → progression: 3")
        }
        
        // Goal selection (step 4)
        if checkGoalSelectionGate() {
            highestCompletedStep = 4
            print("🔄 Migration: Goal selection ✅ → progression: 4")
        }
        
        // Transaction addition (step 5)
        if checkTransactionGate() {
            highestCompletedStep = 5
            print("🔄 Migration: Transaction addition ✅ → progression: 5 (complete)")
        }
        
        print("🔄 Migration: Final progression number: \(highestCompletedStep)")
        
        // Update user's progression number
        UserManager.shared.updateOnboardingProgress(highestCompletedStep)
        
        // Set migration flag to prevent re-migration
        UserDefaults.standard.set(true, forKey: "hasCompletedNumericalMigration")
        
        // Clear migration lock
        UserDefaults.standard.set(false, forKey: "migrationInProgress")
        
        print("🔄 OnboardingStateManager: ======= MIGRATION COMPLETE =======")
        print("🔄 User migrated to progression number: \(highestCompletedStep)")
    }
    
    /// Check if migration has been completed
    private func hasMigrationCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedNumericalMigration")
    }
    
    // MARK: - Legacy Gate Validation (for migration)
    
    /// Validate all onboarding gates and return their status
    func validateAllGates() -> [OnboardingGate: Bool] {
        var results: [OnboardingGate: Bool] = [:]
        
        results[.emailVerification] = checkEmailVerificationGate()
        results[.nameCollection] = checkNameCollectionGate()
        results[.currencySelection] = checkCurrencySelectionGate()
        results[.goalSelection] = checkGoalSelectionGate()
        
        print("🔍 OnboardingStateManager: Legacy gate validation results:")
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
        // Only check completion flags since all users have a primary currency by default
        let hasCompletedCurrencySelection = UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection")
        let hasSetPrimaryCurrency = UserDefaults.standard.bool(forKey: "hasSetPrimaryCurrency")
        
        // Either completion flag being true means currency onboarding is complete
        let currencyComplete = hasCompletedCurrencySelection || hasSetPrimaryCurrency
        
        print("🔍 OnboardingStateManager: Currency gate - complete: \(currencyComplete)")
        print("   - Primary currency: \(CurrencyPreferences.shared.primaryCurrency.rawValue)")
        print("   - Completed currency selection: \(hasCompletedCurrencySelection)")
        print("   - Has set primary currency: \(hasSetPrimaryCurrency)")
        print("   - Final result: \(currencyComplete)")
        
        return currencyComplete
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
        
        // CRITICAL FIX: Check for invalid progression numbers first
        let currentProgress = UserManager.shared.currentUser.onboardingCompleted
        if currentProgress > 5 {
            print("🚨 OnboardingStateManager: INVALID progression \(currentProgress) > 5 - fixing to 5 and completing onboarding")
            UserManager.shared.updateOnboardingProgress(5)
            markAsComplete()
            return false
        } else if currentProgress < 0 {
            print("🚨 OnboardingStateManager: INVALID progression \(currentProgress) < 0 - fixing to 0")
            UserManager.shared.updateOnboardingProgress(0)
            // Continue with normal flow
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
            
            // IMPORTANT: Preserve user's current UI step to respect back navigation
            // The user should stay where they were in the UI, regardless of progression number
            print("🔄 OnboardingStateManager: In progress at \(step) - staying at current UI step")
            
            // CRITICAL FIX: Don't auto-advance based on progression when resuming
            // User might have gone back in UI but progression number is ahead
            print("🎯 OnboardingStateManager: Preserving UI step (\(step)) regardless of progression number")
            print("   - This respects back navigation and prevents auto-skipping")
            
            return true
        }
        
        // Not started - check if onboarding is needed based on numerical progression
        if isOnboardingComplete() {
            print("✅ OnboardingStateManager: Numerical progression complete - marking as finished")
            markAsComplete()
            return false
        } else {
            print("🆕 OnboardingStateManager: Not started - starting onboarding based on numerical progression")
            let currentStep = getCurrentOnboardingStep()
            updateState(to: .inProgress(step: currentStep, lastActiveTime: Date()))
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
    
    /// Reset onboarding state to a specific progression number (for wallet deletion)
    func resetOnboardingToStep(_ targetProgression: Int) {
        print("🔄 OnboardingStateManager: RESETTING onboarding state to progression \(targetProgression)")
        
        // Update state based on target progression
        if targetProgression == 0 {
            updateState(to: .notStarted)
        } else {
            let targetStep = getCurrentOnboardingStepForProgression(targetProgression)
            updateState(to: .inProgress(step: targetStep, lastActiveTime: Date()))
        }
        
        // Clear legacy flags based on target progression
        if targetProgression <= 1 {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(false, forKey: "hasCompletedCurrencySelection")
            UserDefaults.standard.set(false, forKey: "hasSetPrimaryCurrency")
            UserDefaults.standard.set(false, forKey: "hasCompletedGoalSelection")
            
            // Clear goal values if resetting to name collection
            UserDefaults.standard.removeObject(forKey: "selectedPrimaryGoal")
            UserDefaults.standard.removeObject(forKey: "selectedPrimaryGoals")
        }
        
        // Always clear transaction step flags when resetting
        UserDefaults.standard.set(false, forKey: "hasReachedTransactionStep")
        UserDefaults.standard.set(false, forKey: "hasSkippedTransactionOnboarding")
        
        print("🔄 OnboardingStateManager: Reset to progression \(targetProgression) with appropriate flags cleared")
    }
    
    /// Helper to get onboarding step for a specific progression number
    private func getCurrentOnboardingStepForProgression(_ progression: Int) -> OnboardingStep {
        switch progression {
        case 0: return .emailConfirmation
        case 1: return .nameCollection
        case 2: return .currencySelection
        case 3: return .goalSelection
        case 4, 5: return .transactionAddition
        default: return .emailConfirmation
        }
    }
    
    /// Reset onboarding state (for testing)
    func resetOnboardingState() {
        print("🔄 OnboardingStateManager: FULL RESET onboarding state")
        resetOnboardingToStep(0)
        
        // Clear migration flags to allow fresh migration
        UserDefaults.standard.set(false, forKey: "hasCompletedNumericalMigration")
        UserDefaults.standard.set(false, forKey: "migrationInProgress")
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