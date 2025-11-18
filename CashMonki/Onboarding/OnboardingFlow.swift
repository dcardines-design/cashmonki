//
//  OnboardingFlow.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onBack: (() -> Void)? // Optional callback for going back to registration
    let userEmail: String? // Email from registration
    let isNewRegistration: Bool // Whether this is a new registration or existing user
    let forceStartStep: OnboardingStep? // Optional parameter to force a specific starting step for debugging
    
    @State private var currentStep: OnboardingStep = .emailConfirmation
    @State private var collectedName: String = ""
    @State private var selectedCurrency: Currency = .php
    @State private var isNavigatingForward: Bool = true // Track navigation direction
    @State private var isDismissing: Bool = false // Track slide down dismissal
    
    // State manager integration
    @ObservedObject private var onboardingStateManager = OnboardingStateManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    
    var body: some View {
        Group {
            currentStepView
        }
        .offset(y: isDismissing ? UIScreen.main.bounds.height : 0)
        .animation(.easeInOut(duration: 0.35), value: isDismissing)
        .onChange(of: currentStep) { oldValue, newValue in
            print("🔥 TRANSITION DEBUG: ======= CURRENT STEP CHANGED =======")
            print("🔥 TRANSITION DEBUG: Step changed from \(oldValue) to \(newValue)")
            print("🔥 TRANSITION DEBUG: isNavigatingForward: \(isNavigatingForward)")
            print("🔥 TRANSITION DEBUG: SwiftUI should trigger transition animation now...")
        }
        .onAppear {
            print("🎆 OnboardingFlow: ======= ONBOARDING FLOW START =======")
            print("🎆 OnboardingFlow: Starting progressive onboarding process")
            print("📧 OnboardingFlow: User email: \(userEmail ?? "No email provided")")
            print("👤 OnboardingFlow: Is new registration: \(isNewRegistration)")
            
            // GOOGLE DEBUG: Check if this is a Google user
            if let currentUser = AuthenticationManager.shared.currentUser {
                print("🎆 OnboardingFlow: GOOGLE DEBUG - User details:")
                print("   - Name: '\(currentUser.name)'")
                print("   - Email: '\(currentUser.email)'")
                print("   - Firebase UID: '\(currentUser.firebaseUID)'")
                
                // Check if this is a Google sign-in
                #if canImport(FirebaseAuth)
                if let firebaseUser = Auth.auth().currentUser {
                    let isGoogleSignIn = firebaseUser.providerData.contains { $0.providerID == "google.com" }
                    print("   - Is Google sign-in: \(isGoogleSignIn)")
                    print("   - Provider data: \(firebaseUser.providerData.map { $0.providerID })")
                }
                #endif
            }
            
            // Use forceStartStep for debugging, otherwise determine initial step
            let initialStep: OnboardingStep
            if let forcedStep = forceStartStep {
                initialStep = forcedStep
                print("🐛 OnboardingFlow: DEBUG MODE - Forcing start step: \(forcedStep)")
            } else {
                initialStep = determineInitialStep()
                print("🔄 OnboardingFlow: Determined initial step: \(initialStep)")
            }
            
            currentStep = initialStep
            print("🔄 OnboardingFlow: Starting with step: \(currentStep)")
            print("🎆 OnboardingFlow: ======= ONBOARDING FLOW READY =======")
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        ZStack {
            switch currentStep {
            case .emailConfirmation:
                if let email = userEmail {
                    EmailConfirmationViewContainer(
                        email: email,
                        isPresented: $isPresented,
                        currentStep: $currentStep,
                        isNavigatingForward: $isNavigatingForward,
                        onBack: onBack
                    )
                    .transition(.asymmetric(
                        insertion: isNavigatingForward ? 
                            .move(edge: .trailing).combined(with: .opacity) :  // Forward: slide in from right
                            .move(edge: .leading).combined(with: .opacity),   // Back: slide in from left
                        removal: isNavigatingForward ? 
                            .move(edge: .leading).combined(with: .opacity) :   // Forward: slide out to left  
                            .move(edge: .trailing).combined(with: .opacity)    // Back: slide out to right
                    ))
                } else {
                    // Skip email confirmation if no email provided
                    CurrencyOnboardingView(
                        isPresented: $isPresented,
                        onCurrencySelected: { currency in
                            print("💰 OnboardingFlow: Currency selected: \(currency)")
                            selectedCurrency = currency
                            completeOnboarding()
                        },
                        onBack: onBack
                    )
                    .transition(.asymmetric(
                        insertion: isNavigatingForward ? 
                            .move(edge: .trailing).combined(with: .opacity) :  // Forward: slide in from right
                            .move(edge: .leading).combined(with: .opacity),   // Back: slide in from left
                        removal: isNavigatingForward ? 
                            .move(edge: .leading).combined(with: .opacity) :   // Forward: slide out to left  
                            .move(edge: .trailing).combined(with: .opacity)    // Back: slide out to right
                    ))
                }
                
            case .nameCollection:
                NameCollectionView(
                    isPresented: $isPresented,
                    onNameCollected: { name in
                        print("👤 OnboardingFlow: Name collected: \(name)")
                        collectedName = name
                        
                        // Update the authenticated user's name
                        if AuthenticationManager.shared.currentUser != nil {
                            // Update user name in authentication manager and user manager
                            print("👤 OnboardingFlow: Calling UserManager.updateUserName with: '\(name)'")
                            UserManager.shared.updateUserName(name)
                            
                            // Force UI refresh to ensure wallet name updates are reflected
                            DispatchQueue.main.async {
                                print("🔄 OnboardingFlow: Forcing UI refresh for wallet name update")
                                AccountManager.shared.objectWillChange.send()
                            }
                        }
                        
                        // Progressive: Check what's next
                        let nextStep = determineNextStepAfterName()
                        print("➡️ OnboardingFlow: Name completed, next step: \(nextStep)")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = nextStep
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from name collection to email confirmation")
                        isNavigatingForward = false // Backward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .emailConfirmation
                        }
                    },
                    isNewRegistration: isNewRegistration
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ? 
                        .move(edge: .trailing).combined(with: .opacity) :  // Forward: slide in from right
                        .move(edge: .leading).combined(with: .opacity),   // Back: slide in from left
                    removal: isNavigatingForward ? 
                        .move(edge: .leading).combined(with: .opacity) :   // Forward: slide out to left  
                        .move(edge: .trailing).combined(with: .opacity)    // Back: slide out to right
                ))
                
            case .currencySelection:
                CurrencyOnboardingView(
                    isPresented: $isPresented,
                    onCurrencySelected: { currency in
                        print("💰 OnboardingFlow: ======= CURRENCY SELECTED =======")
                        print("💰 OnboardingFlow: Currency selected in step 2: \(currency)")
                        print("💰 OnboardingFlow: Currency details: \(currency.rawValue) (\(currency.displayName)) \(currency.symbol)")
                        selectedCurrency = currency
                        
                        // Progressive: Check what's next after currency
                        let nextStep = determineNextStepAfterCurrency()
                        print("➡️ OnboardingFlow: Currency completed, next step: \(nextStep)")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = nextStep
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from currency selection to name collection")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .nameCollection
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ? 
                        .move(edge: .trailing).combined(with: .opacity) :  // Forward: slide in from right
                        .move(edge: .leading).combined(with: .opacity),   // Back: slide in from left
                    removal: isNavigatingForward ? 
                        .move(edge: .leading).combined(with: .opacity) :   // Forward: slide out to left  
                        .move(edge: .trailing).combined(with: .opacity)    // Back: slide out to right
                ))
                
            case .goalSelection:
                GoalsOnboardingView(
                    isPresented: $isPresented,
                    onGoalSelected: { goal in
                        print("🎯 OnboardingFlow: ======= GOAL SELECTED =======")
                        print("🎯 OnboardingFlow: Goal selected: \(goal)")
                        print("🎯 OnboardingFlow: Waiting for goal data to be saved...")
                        
                        // Give a small delay to ensure UserDefaults.set() completes before proceeding
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("🎯 OnboardingFlow: Goals saved, proceeding to next step...")
                            
                            // Progressive: Check what's next after goals
                            let nextStep = determineNextStepAfterGoals()
                            print("➡️ OnboardingFlow: Goals completed, next step: \(nextStep)")
                            isNavigatingForward = true // Forward navigation
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                                currentStep = nextStep
                            }
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from goal selection to currency selection")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .currencySelection
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ? 
                        .move(edge: .trailing).combined(with: .opacity) :  // Forward: slide in from right
                        .move(edge: .leading).combined(with: .opacity),   // Back: slide in from left
                    removal: isNavigatingForward ? 
                        .move(edge: .leading).combined(with: .opacity) :   // Forward: slide out to left  
                        .move(edge: .trailing).combined(with: .opacity)    // Back: slide out to right
                ))
                
            case .transactionAddition:
                OnboardingTransactionView(
                    isPresented: $isPresented,
                    onComplete: {
                        print("💰 OnboardingFlow: ======= TRANSACTION STEP COMPLETED =======")
                        print("💰 OnboardingFlow: Transaction onboarding completed, finishing overall onboarding...")
                        completeOnboarding()
                    },
                    onBack: {
                        print("🔥 TRANSITION DEBUG: ======= ONBOARDING FLOW BACK TRANSITION =======")
                        print("🔥 TRANSITION DEBUG: Current step before: \(currentStep)")
                        print("🔥 TRANSITION DEBUG: isNavigatingForward before: \(isNavigatingForward)")
                        print("🔥 TRANSITION DEBUG: Setting isNavigatingForward = false")
                        isNavigatingForward = false
                        print("🔥 TRANSITION DEBUG: Setting currentStep = .goalSelection with animation")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .goalSelection
                        }
                        print("🔥 TRANSITION DEBUG: Current step after: \(currentStep)")
                        print("🔥 TRANSITION DEBUG: isNavigatingForward after: \(isNavigatingForward)")
                        print("🔥 TRANSITION DEBUG: ======= BACK TRANSITION SETUP COMPLETE =======")
                    }
                )
                .environmentObject(toastManager)
                .transition(.asymmetric(
                    insertion: isNavigatingForward ? 
                        .move(edge: .trailing).combined(with: .opacity) :  // Forward: slide in from right
                        .move(edge: .leading).combined(with: .opacity),   // Back: slide in from left
                    removal: isNavigatingForward ? 
                        .move(edge: .leading).combined(with: .opacity) :   // Forward: slide out to left  
                        .move(edge: .trailing).combined(with: .opacity)    // Back: slide out to right
                ))
            }
        }
    }
    
    // MARK: - Progressive Onboarding Logic
    
    private func determineInitialStep() -> OnboardingStep {
        print("🔍 OnboardingFlow: ======= DETERMINING INITIAL STEP =======")
        // Check what data is missing and determine starting point
        guard let currentUser = AuthenticationManager.shared.currentUser else {
            print("⚠️ OnboardingFlow: No current user, defaulting to email confirmation")
            return .emailConfirmation
        }
        
        print("🔍 OnboardingFlow: Current user found:")
        print("   - Email: \(currentUser.email)")
        print("   - Name: '\(currentUser.name)'")
        print("   - Firebase UID: \(currentUser.firebaseUID)")
        
        let isEmailVerified = checkEmailVerification()
        let hasCompleteName = checkUserHasCompleteName(currentUser.name)
        let hasCurrency = checkUserHasCurrency()
        let hasGoal = checkUserHasGoal()
        
        print("🔍 OnboardingFlow: Progressive gate check:")
        print("   📧 Email verified: \(isEmailVerified ? "✅" : "❌") - \(currentUser.email)")
        print("   📝 Complete name: \(hasCompleteName ? "✅" : "❌") - '\(currentUser.name)'")
        print("   💰 Currency set: \(hasCurrency ? "✅" : "❌")")
        print("   🎯 Goal selected: \(hasGoal ? "✅" : "❌")")
        
        // Progressive logic - prioritize email verification first
        print("🔍 OnboardingFlow: Determining step based on gates:")
        if !isEmailVerified {
            print("🎯 OnboardingFlow: ❌ Email not verified - starting with email verification")
            print("🔍 OnboardingFlow: ======= STEP DECISION: .emailConfirmation =======")
            return .emailConfirmation
        } else if !hasCompleteName {
            print("🎯 OnboardingFlow: ❌ Missing name - starting with name collection")
            print("🔍 OnboardingFlow: ======= STEP DECISION: .nameCollection =======")
            return .nameCollection
        } else if !hasCurrency {
            print("🎯 OnboardingFlow: ❌ Missing currency - starting with currency selection")
            print("🔍 OnboardingFlow: ======= STEP DECISION: .currencySelection =======")
            return .currencySelection
        } else if !hasGoal {
            print("🎯 OnboardingFlow: ❌ Missing goal - starting with goal selection")
            print("🔍 OnboardingFlow: ======= STEP DECISION: .goalSelection =======")
            return .goalSelection
        } else {
            // Check transaction gate
            let hasTransaction = OnboardingStateManager.shared.checkTransactionGate()
            if !hasTransaction {
                print("🎯 OnboardingFlow: ❌ Missing transaction - starting with transaction addition")
                print("🔍 OnboardingFlow: ======= STEP DECISION: .transactionAddition =======")
                return .transactionAddition
            } else {
                print("🎯 OnboardingFlow: ✅ All data complete - Google sign-in user with complete profile")
                print("🔍 OnboardingFlow: ======= STEP DECISION: Complete onboarding immediately =======")
                
                // For new registrations with complete data (e.g., Google sign-in), 
                // complete onboarding immediately to trigger welcome toast
                if isNewRegistration {
                    print("🎉 OnboardingFlow: ======= GOOGLE SIGN-IN COMPLETE DATA DETECTED =======")
                    print("🎉 OnboardingFlow: New user with complete data - completing onboarding for welcome toast")
                    print("🎉 OnboardingFlow: isNewRegistration: \(isNewRegistration)")
                    print("🎉 OnboardingFlow: userEmail: \(userEmail ?? "nil")")
                    if let currentUser = AuthenticationManager.shared.currentUser {
                        print("🎉 OnboardingFlow: currentUser.name: '\(currentUser.name)'")
                        print("🎉 OnboardingFlow: currentUser.email: '\(currentUser.email)'")
                    }
                    print("🎉 OnboardingFlow: About to call completeOnboarding() asynchronously...")
                    DispatchQueue.main.async {
                        print("🎉 OnboardingFlow: ======= CALLING completeOnboarding() FOR GOOGLE USER =======")
                        self.completeOnboarding()
                    }
                } else {
                    print("🎉 OnboardingFlow: All data complete but NOT a new registration - skipping immediate completion")
                    print("🎉 OnboardingFlow: isNewRegistration: \(isNewRegistration)")
                }
                
                return .transactionAddition // Fallback - won't be used if completing immediately
            }
        }
    }
    
    // Helper function to check if user has complete name (strict validation)
    private func checkUserHasCompleteName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameComponents = trimmedName.components(separatedBy: " ").filter { !$0.isEmpty }
        let hasMultipleWords = nameComponents.count >= 2
        let hasContent = !trimmedName.isEmpty && trimmedName.count >= 1 // Changed from >= 2 to >= 1
        
        // Simplified validation - accept any reasonable name input
        let isMeaningfulSingleName = nameComponents.count == 1 && 
                                   trimmedName.count >= 1 && // Accept any single character or longer
                                   !trimmedName.contains("@") && // Only reject obvious email patterns
                                   !trimmedName.contains("+") // Only reject obvious email patterns
        
        let hasValidLocalName = hasContent && (hasMultipleWords || isMeaningfulSingleName)
        
        // ENHANCED: Also check Firebase displayName for Gmail signups
        let hasFirebaseName = checkFirebaseUserHasCompleteName()
        
        print("🔍 OnboardingFlow: Name validation:")
        print("   - Local name: '\(name)' → \(hasValidLocalName ? "✅ (valid name)" : "❌ (invalid/incomplete name)")")
        print("   - Has content: \(hasContent), Has multiple words: \(hasMultipleWords), Is meaningful single: \(isMeaningfulSingleName)")
        print("   - Firebase name: \(hasFirebaseName ? "✅" : "❌")")
        
        return hasValidLocalName || hasFirebaseName
    }
    
    // Helper function to check if user has currency selected during onboarding
    private func checkUserHasCurrency() -> Bool {
        let hasSetPrimaryCurrency = UserDefaults.standard.bool(forKey: "hasSetPrimaryCurrency")
        let hasCompletedCurrencySelection = UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection")
        let hasPrimaryCurrency = !CurrencyPreferences.shared.primaryCurrency.rawValue.isEmpty
        
        // Use consistent validation logic: requires BOTH flag AND actual currency
        let isComplete = (hasSetPrimaryCurrency || hasCompletedCurrencySelection) && hasPrimaryCurrency
        
        print("🔍 OnboardingFlow: Currency validation:")
        print("   - HasSetPrimaryCurrency: \(hasSetPrimaryCurrency)")
        print("   - HasCompletedCurrencySelection: \(hasCompletedCurrencySelection)")
        print("   - HasPrimaryCurrency: \(hasPrimaryCurrency) (\(CurrencyPreferences.shared.primaryCurrency.rawValue))")
        print("   - Currency validation result: \(isComplete)")
        
        return isComplete
    }
    
    // Helper function to check if user has selected a goal during onboarding
    private func checkUserHasGoal() -> Bool {
        let hasCompletedGoalSelection = UserDefaults.standard.bool(forKey: "hasCompletedGoalSelection")
        
        // Check both old single goal format and new multiple goals format for backward compatibility
        let selectedGoal = UserDefaults.standard.string(forKey: "selectedPrimaryGoal")
        let selectedGoals = UserDefaults.standard.string(forKey: "selectedPrimaryGoals")
        
        let hasSelectedGoal = (selectedGoal != nil && !selectedGoal!.isEmpty) || 
                             (selectedGoals != nil && !selectedGoals!.isEmpty)
        
        print("🔍 OnboardingFlow: Goal validation:")
        print("   - Goal selection completed flag: \(hasCompletedGoalSelection)")
        print("   - Has selected single goal: \(selectedGoal != nil && !selectedGoal!.isEmpty)")
        print("   - Has selected multiple goals: \(selectedGoals != nil && !selectedGoals!.isEmpty)")
        print("   - Single goal value: '\(selectedGoal ?? "nil")'")
        print("   - Multiple goals value: '\(selectedGoals ?? "nil")'")
        
        // Both flags must be true - user must have completed the goal selection process
        // AND actually selected a valid goal
        let goalCompleted = hasCompletedGoalSelection && hasSelectedGoal
        
        if !goalCompleted {
            print("🎯 OnboardingFlow: Goal incomplete - user will be directed to goal selection")
            if !hasCompletedGoalSelection {
                print("   - Reason: Goal selection process not completed")
            }
            if !hasSelectedGoal {
                print("   - Reason: No valid goal selected")
            }
        } else {
            print("🎯 OnboardingFlow: Goal requirements satisfied ✅")
        }
        
        return goalCompleted
    }
    
    // Helper function to check if user's email is verified
    private func checkEmailVerification() -> Bool {
        // Check persistent flag first (for app resume scenarios)
        let hasCompletedEmailVerification = UserDefaults.standard.bool(forKey: "hasCompletedEmailVerification")
        
        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            let isVerified = currentUser.isEmailVerified
            let isGoogleSignIn = currentUser.providerData.contains { $0.providerID == "google.com" }
            
            print("🔍 OnboardingFlow: Email verification status:")
            print("   - Firebase verified: \(isVerified)")
            print("   - Persistent flag: \(hasCompletedEmailVerification)")
            print("   - Google sign-in: \(isGoogleSignIn)")
            print("   - Provider data: \(currentUser.providerData.map { $0.providerID })")
            
            // ENHANCED: Gmail signups are typically auto-verified
            if isGoogleSignIn {
                print("🔍 OnboardingFlow: Google sign-in detected - treating as verified")
                return true
            }
            
            // If either Firebase says verified OR we have persistent completion flag, consider verified
            let finalResult = isVerified || hasCompletedEmailVerification
            print("🔍 OnboardingFlow: Final verification result: \(finalResult)")
            return finalResult
        } else {
            print("🔍 OnboardingFlow: No Firebase user found - assuming unverified")
            return false
        }
        #else
        print("🔍 OnboardingFlow: Firebase not available - simulating verified email")
        return true // Allow progression when Firebase isn't available
        #endif
    }
    
    // Check if Firebase user has complete name (with strict validation)
    private func checkFirebaseUserHasCompleteName() -> Bool {
        #if canImport(FirebaseAuth)
        if let firebaseUser = Auth.auth().currentUser,
           let displayName = firebaseUser.displayName {
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameComponents = trimmedName.components(separatedBy: " ").filter { !$0.isEmpty }
            let hasMultipleWords = nameComponents.count >= 2
            let hasContent = !trimmedName.isEmpty && trimmedName.count >= 1 // Changed from >= 2 to >= 1
            
            // Simplified validation - accept any reasonable name input
            let isMeaningfulSingleName = nameComponents.count == 1 && 
                                       trimmedName.count >= 1 && // Accept any single character or longer
                                       !trimmedName.contains("@") && // Only reject obvious email patterns
                                       !trimmedName.contains("+") // Only reject obvious email patterns
            
            let hasValidFirebaseName = hasContent && (hasMultipleWords || isMeaningfulSingleName)
            
            print("🔥 OnboardingFlow: Firebase displayName: '\(displayName)' → \(hasValidFirebaseName ? "✅ (valid)" : "❌ (invalid/email-like)")")
            print("🔥 OnboardingFlow: Firebase validation - Has content: \(hasContent), Has multiple words: \(hasMultipleWords), Is meaningful single: \(isMeaningfulSingleName)")
            
            return hasValidFirebaseName
        }
        #endif
        print("🔥 OnboardingFlow: No Firebase displayName found")
        return false
    }
    
    // Determine next step after name collection
    private func determineNextStepAfterName() -> OnboardingStep {
        let hasCurrency = checkUserHasCurrency()
        let hasGoal = checkUserHasGoal()
        let hasTransaction = OnboardingStateManager.shared.checkTransactionGate()
        
        if !hasCurrency {
            print("🎯 OnboardingFlow: Name complete, missing currency - proceeding to currency selection")
            return .currencySelection
        } else if !hasGoal {
            print("🎯 OnboardingFlow: Name complete, currency set, missing goal - proceeding to goal selection")
            return .goalSelection
        } else if !hasTransaction {
            print("🎯 OnboardingFlow: Name complete, currency and goal set, missing transaction - proceeding to transaction addition")
            return .transactionAddition
        } else {
            print("🎯 OnboardingFlow: Name complete, all steps already set - completing onboarding")
            // Complete onboarding since everything is set
            DispatchQueue.main.async {
                self.completeOnboarding()
            }
            return .transactionAddition // This won't be used since we're completing
        }
    }
    
    // Determine next step after currency selection
    private func determineNextStepAfterCurrency() -> OnboardingStep {
        let hasGoal = checkUserHasGoal()
        
        if !hasGoal {
            print("🎯 OnboardingFlow: Currency complete, missing goal - proceeding to goal selection")
            return .goalSelection
        } else {
            print("🎯 OnboardingFlow: Currency complete, goal already set - proceeding to transaction step")
            return .transactionAddition
        }
    }
    
    // Determine next step after goal selection
    private func determineNextStepAfterGoals() -> OnboardingStep {
        let hasTransaction = OnboardingStateManager.shared.checkTransactionGate()
        
        if !hasTransaction {
            print("🎯 OnboardingFlow: Goals complete, no transaction yet - proceeding to transaction addition")
            return .transactionAddition
        } else {
            print("🎯 OnboardingFlow: Goals complete, transaction already exists - completing onboarding")
            // Complete onboarding since everything is set
            DispatchQueue.main.async {
                self.completeOnboarding()
            }
            return .transactionAddition // This won't be used since we're completing
        }
    }
    
    private func completeOnboarding() {
        print("🏁 OnboardingFlow: ======= COMPLETING ONBOARDING =======")
        print("🏁 OnboardingFlow: Completing onboarding process...")
        print("🏁 OnboardingFlow: Called from thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        print("💰 OnboardingFlow: Final currency selection: \(selectedCurrency.rawValue) (\(selectedCurrency.displayName))")
        
        // GOOGLE DEBUG: Check if this is called for Google users
        if let currentUser = AuthenticationManager.shared.currentUser {
            print("🏁 OnboardingFlow: GOOGLE DEBUG - Completing for user: '\(currentUser.name)' (\(currentUser.email))")
        }
        
        // Save the selected currency to the user's account
        let userManager = UserManager.shared
        print("💰 OnboardingFlow: Updating primary currency in UserManager...")
        userManager.updatePrimaryCurrency(selectedCurrency)
        
        // Sync with centralized currency preferences
        print("💰 OnboardingFlow: Syncing with CurrencyPreferences...")
        CurrencyPreferences.shared.setPrimaryCurrency(selectedCurrency)
        
        // Also update rate manager to clear cached rates and initialize properly
        CurrencyRateManager.shared.setPrimaryCurrency(selectedCurrency)
        
        // CRITICAL: Mark onboarding as complete in the state manager FIRST
        print("🎯 OnboardingFlow: Marking onboarding as complete in state manager...")
        onboardingStateManager.markAsComplete()
        
        // Legacy flag support (the state manager also sets these, but we'll be explicit)
        print("💾 OnboardingFlow: Saving completion flags to UserDefaults...")
        UserDefaults.standard.set(true, forKey: "hasCompletedCurrencySelection")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(true, forKey: "hasSetPrimaryCurrency")  // 🔧 CRITICAL FIX: Add missing flag
        print("💾 OnboardingFlow: Currency selection and onboarding completion saved to UserDefaults")
        
        // Verify the flags were saved
        let currencyCompleted = UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection")
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasSetPrimary = UserDefaults.standard.bool(forKey: "hasSetPrimaryCurrency")
        print("💾 OnboardingFlow: Verification - Currency completed: \(currencyCompleted)")
        print("💾 OnboardingFlow: Verification - Onboarding completed: \(onboardingCompleted)")
        print("💾 OnboardingFlow: Verification - Primary currency set: \(hasSetPrimary)")
        print("🎯 OnboardingFlow: State manager state: \(onboardingStateManager.currentState)")
        
        print("🎯 OnboardingFlow: Onboarding completed successfully!")
        print("🎉 OnboardingFlow: Welcome to CashMonki!")
        print("🏁 OnboardingFlow: ======= STARTING SLIDE DOWN DISMISSAL =======")
        
        // CRITICAL: Call completion IMMEDIATELY to show dashboard behind slide down
        print("🏁 OnboardingFlow: ======= CALLING onComplete() BEFORE SLIDE DOWN =======")
        
        // GOOGLE DEBUG: Final step before calling main app callback
        if let currentUser = AuthenticationManager.shared.currentUser {
            print("🏁 OnboardingFlow: GOOGLE DEBUG - About to call onComplete() for: '\(currentUser.name)'")
            print("🏁 OnboardingFlow: GOOGLE DEBUG - About to call onComplete callback")
        }
        
        onComplete() // Dashboard appears immediately behind the slide down
        
        // Start slide down animation AFTER showing dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🏁 OnboardingFlow: ======= STARTING SLIDE ANIMATION =======")
            withAnimation(.easeInOut(duration: 0.35)) {
                isDismissing = true
            }
        }
    }
}




// MARK: - Preview

#Preview {
    OnboardingFlow(
        isPresented: Binding.constant(true),
        onComplete: {
            print("Onboarding completed")
        },
        onBack: {
            print("Back to registration")
        },
        userEmail: "user@example.com",
        isNewRegistration: true,
        forceStartStep: nil as OnboardingStep?
    )
}