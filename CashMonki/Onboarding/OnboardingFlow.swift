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
    
    @State private var currentStep: OnboardingStep = .emailConfirmation // Will be updated immediately in init
    @State private var collectedName: String = ""
    @State private var selectedCurrency: Currency = .php
    @State private var isNavigatingForward: Bool = true // Track navigation direction
    @State private var isDismissing: Bool = false // Track slide down dismissal
    @State private var showingPaywall: Bool = false // Show paywall at end of onboarding

    // State manager integration
    @ObservedObject private var onboardingStateManager = OnboardingStateManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    
    init(isPresented: Binding<Bool>, onComplete: @escaping () -> Void, onBack: (() -> Void)?, userEmail: String?, isNewRegistration: Bool, forceStartStep: OnboardingStep?) {
        self._isPresented = isPresented
        self.onComplete = onComplete
        self.onBack = onBack
        self.userEmail = userEmail
        self.isNewRegistration = isNewRegistration
        self.forceStartStep = forceStartStep
        
        // CRITICAL FIX: Determine correct starting step BEFORE view appears
        // This prevents the currency screen flash for Gmail users
        let initialStep: OnboardingStep
        if let forcedStep = forceStartStep {
            initialStep = forcedStep
            print("🐛 OnboardingFlow.init: DEBUG MODE - Forcing start step: \(forcedStep)")
        } else {
            initialStep = OnboardingStateManager.shared.getCurrentOnboardingStep()
            print("🔢 OnboardingFlow.init: Determined initial step: \(initialStep)")
        }
        
        // Set the initial step immediately to prevent screen flashing
        self._currentStep = State(initialValue: initialStep)
        print("✅ OnboardingFlow.init: Set initial step to \(initialStep) - no screen flash")
    }
    
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

            // Track step completion when moving forward
            if isNavigatingForward {
                AnalyticsManager.shared.trackOnboardingStep(oldValue.rawValue, stepNumber: oldValue.stepNumber)
            }
        }
        .onAppear {
            print("🎆 OnboardingFlow: ======= ONBOARDING FLOW START =======")
            print("🎆 OnboardingFlow: Starting progressive onboarding process")
            print("🔄 OnboardingFlow: Starting with step: \(currentStep) (set in init)")
            
            // Mark this as an active onboarding session for stricter gate validation
            UserDefaults.standard.set(true, forKey: "isActiveOnboardingSession")
            print("🎆 OnboardingFlow: Marked as active onboarding session for strict validation")
            print("📧 OnboardingFlow: User email: \(userEmail ?? "No email provided")")
            print("👤 OnboardingFlow: Is new registration: \(isNewRegistration)")
            
            // GOOGLE DEBUG: Check if this is a Google user
            if let currentUser = AuthenticationManager.shared.currentUser {
                print("🎆 OnboardingFlow: GOOGLE DEBUG - User details:")
                print("   - Name: '\(currentUser.name)'")
                print("   - Email: '\(currentUser.email)'")
                print("   - Firebase UID: '\(currentUser.firebaseUID)'")
                
                // FUTURE: Uncomment when re-enabling authentication
                // #if canImport(FirebaseAuth)
                // if let firebaseUser = Auth.auth().currentUser {
                //     let isGoogleSignIn = firebaseUser.providerData.contains { $0.providerID == "google.com" }
                //     print("   - Is Google sign-in: \(isGoogleSignIn)")
                // }
                // #endif
            }
            
            print("🎆 OnboardingFlow: ======= ONBOARDING FLOW READY =======")

            // Track onboarding started
            AnalyticsManager.shared.track(.onboardingStarted, properties: [
                "is_new_registration": isNewRegistration,
                "starting_step": currentStep.rawValue
            ])
        }
        .fullScreenCover(isPresented: $showingPaywall, onDismiss: {
            // When paywall is dismissed, complete onboarding and show welcome
            print("💰 OnboardingFlow: Paywall dismissed - finishing onboarding")
            finishOnboardingAfterPaywall()
        }) {
            OneTimePaywallSheet(isPresented: $showingPaywall)
                .environmentObject(toastManager)
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        ZStack {
            switch currentStep {
            // MARK: - FUTURE: Email confirmation step (commented out for no-auth flow)
            case .emailConfirmation:
                // Currently skipped - uncomment when re-enabling authentication
                EmptyView()
                /*
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
                            .move(edge: .trailing).combined(with: .opacity) :
                            .move(edge: .leading).combined(with: .opacity),
                        removal: isNavigatingForward ?
                            .move(edge: .leading).combined(with: .opacity) :
                            .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    Text("Email confirmation step error - contact support")
                        .foregroundColor(AppColors.accentRed)
                }
                */

            case .valueFeature1:
                ValueFeature1OnboardingView(
                    isPresented: $isPresented,
                    onContinue: {
                        print("✨ OnboardingFlow: Value Feature 1 completed")

                        // Set progression to 1 (VF1 completed)
                        onboardingStateManager.setOnboardingProgress(to: 1)

                        // Navigate to value feature 2
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature2
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ?
                        .move(edge: .trailing).combined(with: .opacity) :
                        .move(edge: .leading).combined(with: .opacity),
                    removal: isNavigatingForward ?
                        .move(edge: .leading).combined(with: .opacity) :
                        .move(edge: .trailing).combined(with: .opacity)
                ))

            case .valueFeature2:
                ValueFeature2OnboardingView(
                    isPresented: $isPresented,
                    onContinue: {
                        print("✨ OnboardingFlow: Value Feature 2 completed")
                        onboardingStateManager.setOnboardingProgress(to: 2)
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature3
                        }
                    },
                    onBack: {
                        isNavigatingForward = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature1
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ?
                        .move(edge: .trailing).combined(with: .opacity) :
                        .move(edge: .leading).combined(with: .opacity),
                    removal: isNavigatingForward ?
                        .move(edge: .leading).combined(with: .opacity) :
                        .move(edge: .trailing).combined(with: .opacity)
                ))

            case .valueFeature3:
                ValueFeature3OnboardingView(
                    isPresented: $isPresented,
                    onContinue: {
                        print("✨ OnboardingFlow: Value Feature 3 completed")
                        onboardingStateManager.setOnboardingProgress(to: 3)
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature4
                        }
                    },
                    onBack: {
                        isNavigatingForward = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature2
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ?
                        .move(edge: .trailing).combined(with: .opacity) :
                        .move(edge: .leading).combined(with: .opacity),
                    removal: isNavigatingForward ?
                        .move(edge: .leading).combined(with: .opacity) :
                        .move(edge: .trailing).combined(with: .opacity)
                ))

            case .valueFeature4:
                ValueFeature4OnboardingView(
                    isPresented: $isPresented,
                    onContinue: {
                        print("✨ OnboardingFlow: Value Feature 4 completed - proceeding to name collection")
                        onboardingStateManager.setOnboardingProgress(to: 4)
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .nameCollection
                        }
                    },
                    onBack: {
                        isNavigatingForward = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature3
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ?
                        .move(edge: .trailing).combined(with: .opacity) :
                        .move(edge: .leading).combined(with: .opacity),
                    removal: isNavigatingForward ?
                        .move(edge: .leading).combined(with: .opacity) :
                        .move(edge: .trailing).combined(with: .opacity)
                ))

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

                        // Set progression to 5 (name completed)
                        onboardingStateManager.setOnboardingProgress(to: 5)

                        // Navigate explicitly to currency selection (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Name completed, navigating to currency selection")
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .currencySelection
                        }
                    },
                    // Back to value feature 4
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from name collection to value feature 4")
                        isNavigatingForward = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .valueFeature4
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
                        
                        // Set progression to 6 (currency completed)
                        onboardingStateManager.setOnboardingProgress(to: 6)

                        // Navigate explicitly to goal selection (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Currency completed, navigating to goal selection")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .goalSelection
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
                            print("🎯 OnboardingFlow: Goals saved, proceeding to stress selection...")

                            // Set progression to 7 (goals completed)
                            onboardingStateManager.setOnboardingProgress(to: 7)

                            // Navigate explicitly to stress selection (don't rely on getCurrentOnboardingStep)
                            print("🔢 OnboardingFlow: Goals completed, navigating to stress selection")
                            isNavigatingForward = true // Forward navigation
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                                currentStep = .stressSelection
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

            case .stressSelection:
                StressesOnboardingView(
                    isPresented: $isPresented,
                    onStressSelected: { stress in
                        print("😫 OnboardingFlow: ======= STRESS SELECTED =======")
                        print("😫 OnboardingFlow: Stress selected: \(stress)")
                        print("😫 OnboardingFlow: Proceeding to overspent realization...")

                        // Set progression to 8 (stress completed)
                        onboardingStateManager.setOnboardingProgress(to: 8)

                        // Navigate explicitly to overspent realization (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Stress completed, navigating to overspent realization")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .overspentRealization
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from stress selection to goal selection")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .goalSelection
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

            case .overspentRealization:
                OverspentOnboardingView(
                    isPresented: $isPresented,
                    onOverspentSelected: { overspents in
                        print("🙈 OnboardingFlow: ======= OVERSPENT SELECTIONS COMPLETED =======")
                        print("🙈 OnboardingFlow: Overspent selected: \(overspents.joined(separator: ", "))")
                        print("🙈 OnboardingFlow: Proceeding to tracking difficulty...")

                        // Set progression to 9 (overspent completed)
                        onboardingStateManager.setOnboardingProgress(to: 9)

                        // Navigate explicitly to tracking difficulty (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Overspent completed, navigating to tracking difficulty")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .trackingDifficulty
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from overspent realization to stress selection")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .stressSelection
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

            case .trackingDifficulty:
                TrackingDifficultyOnboardingView(
                    isPresented: $isPresented,
                    onDifficultySelected: { difficulties in
                        print("😣 OnboardingFlow: ======= TRACKING DIFFICULTIES SELECTED =======")
                        print("😣 OnboardingFlow: Tracking difficulties selected: \(difficulties.joined(separator: ", "))")
                        print("😣 OnboardingFlow: Proceeding to ideal outcome...")

                        // Set progression to 10 (tracking difficulty completed)
                        onboardingStateManager.setOnboardingProgress(to: 10)

                        // Navigate explicitly to ideal outcome (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Tracking difficulty completed, navigating to ideal outcome")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .idealOutcome
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from tracking difficulty to overspent realization")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .overspentRealization
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

            case .idealOutcome:
                IdealOutcomeOnboardingView(
                    isPresented: $isPresented,
                    onOutcomeSelected: { outcomes in
                        print("🥳 OnboardingFlow: ======= IDEAL OUTCOMES SELECTED =======")
                        print("🥳 OnboardingFlow: Ideal outcomes selected: \(outcomes.joined(separator: ", "))")
                        print("🥳 OnboardingFlow: Proceeding to tracking frequency...")

                        // Set progression to 11 (ideal outcome completed)
                        onboardingStateManager.setOnboardingProgress(to: 11)

                        // Navigate explicitly to tracking frequency (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Ideal outcome completed, navigating to tracking frequency")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .trackingFrequency
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from ideal outcome to tracking difficulty")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .trackingDifficulty
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

            case .trackingFrequency:
                TrackingFrequencyOnboardingView(
                    isPresented: $isPresented,
                    onFrequencySelected: { frequencies in
                        print("🕐 OnboardingFlow: ======= TRACKING FREQUENCIES SELECTED =======")
                        print("🕐 OnboardingFlow: Tracking frequencies selected: \(frequencies.joined(separator: ", "))")
                        print("🕐 OnboardingFlow: Proceeding to tracking method...")

                        // Set progression to 12 (tracking frequency completed)
                        onboardingStateManager.setOnboardingProgress(to: 12)

                        // Navigate explicitly to tracking method (don't rely on getCurrentOnboardingStep)
                        print("🔢 OnboardingFlow: Tracking frequency completed, navigating to tracking method")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .trackingMethod
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from tracking frequency to ideal outcome")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .idealOutcome
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

            case .trackingMethod:
                TrackingMethodOnboardingView(
                    isPresented: $isPresented,
                    onMethodSelected: { methods in
                        print("📝 OnboardingFlow: ======= TRACKING METHODS SELECTED =======")
                        print("📝 OnboardingFlow: Tracking methods selected: \(methods.joined(separator: ", "))")
                        print("📝 OnboardingFlow: Proceeding to social proof...")

                        // Set progression to 13 (tracking method completed)
                        onboardingStateManager.setOnboardingProgress(to: 13)

                        // Navigate explicitly to social proof
                        print("🔢 OnboardingFlow: Tracking method completed, navigating to social proof")
                        isNavigatingForward = true // Forward navigation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .socialProof
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from tracking method to tracking frequency")
                        print("🔄 OnboardingFlow: Setting isNavigatingForward = false BEFORE back animation")
                        isNavigatingForward = false // Set direction BEFORE animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .trackingFrequency
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

            case .socialProof:
                SocialProofOnboardingView(
                    isPresented: $isPresented,
                    onContinue: {
                        print("⭐ OnboardingFlow: ======= SOCIAL PROOF COMPLETED =======")
                        print("⭐ OnboardingFlow: Proceeding to transaction addition...")

                        // Mark social proof as complete
                        UserDefaults.standard.set(true, forKey: "hasCompletedSocialProof")

                        // Set progression to 14 (social proof completed)
                        onboardingStateManager.setOnboardingProgress(to: 14)

                        // Navigate to transaction addition
                        print("🔢 OnboardingFlow: Social proof completed, navigating to transaction addition")
                        isNavigatingForward = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .transactionAddition
                        }
                    },
                    onBack: {
                        print("⬅️ OnboardingFlow: Back from social proof to tracking method")
                        isNavigatingForward = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .trackingMethod
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: isNavigatingForward ?
                        .move(edge: .trailing).combined(with: .opacity) :
                        .move(edge: .leading).combined(with: .opacity),
                    removal: isNavigatingForward ?
                        .move(edge: .leading).combined(with: .opacity) :
                        .move(edge: .trailing).combined(with: .opacity)
                ))

            case .transactionAddition:
                OnboardingTransactionView(
                    isPresented: $isPresented,
                    onComplete: {
                        print("💰 OnboardingFlow: ======= TRANSACTION STEP COMPLETED =======")
                        print("💰 OnboardingFlow: Transaction onboarding completed, finishing overall onboarding...")
                        // Set progression to 16 (onboarding complete)
                        onboardingStateManager.setOnboardingProgress(to: 16)
                        completeOnboarding()
                    },
                    onBack: {
                        print("🔥 TRANSITION DEBUG: ======= ONBOARDING FLOW BACK TRANSITION =======")
                        print("🔥 TRANSITION DEBUG: Current step before: \(currentStep)")
                        print("🔥 TRANSITION DEBUG: isNavigatingForward before: \(isNavigatingForward)")
                        print("🔥 TRANSITION DEBUG: Setting isNavigatingForward = false")
                        isNavigatingForward = false
                        print("🔥 TRANSITION DEBUG: Setting currentStep = .socialProof with animation")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.05)) {
                            currentStep = .socialProof
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
    
    /// Unified progressive gate system - determines next incomplete step
    private func determineInitialStep() -> OnboardingStep {
        print("🔍 OnboardingFlow: ======= UNIFIED PROGRESSIVE GATE CHECK =======")
        
        // Use the same OnboardingStateManager gate system for consistency
        let stateManager = OnboardingStateManager.shared
        let gateResults = stateManager.validateAllGates()
        
        print("🔍 OnboardingFlow: Gate validation results:")
        for (gate, passed) in gateResults {
            print("   \(gate.displayName): \(passed ? "✅" : "❌")")
        }
        
        // Check gates in logical order - return first incomplete step
        let orderedGates: [(OnboardingGate, OnboardingStep)] = [
            (.emailVerification, .emailConfirmation),
            (.nameCollection, .nameCollection),  
            (.currencySelection, .currencySelection),
            (.goalSelection, .goalSelection)
        ]
        
        // Find first incomplete gate
        for (gate, step) in orderedGates {
            if gateResults[gate] == false {
                print("🎯 OnboardingFlow: ❌ \(gate.displayName) incomplete - starting with \(step)")
                print("🔍 OnboardingFlow: ======= STEP DECISION: .\(step) =======")
                return step
            }
        }
        
        // All main gates complete - check transaction gate
        let hasTransaction = stateManager.checkTransactionGate()
        if !hasTransaction {
            print("🎯 OnboardingFlow: ❌ Transaction incomplete - starting with transaction addition")
            print("🔍 OnboardingFlow: ======= STEP DECISION: .transactionAddition =======")
            return .transactionAddition
        }
        
        // Everything complete
        print("🎯 OnboardingFlow: ✅ All gates complete - onboarding should be finished")
        
        // For new registrations, show welcome and complete
        if isNewRegistration {
            print("🎉 OnboardingFlow: New user with complete data - completing for welcome toast")
            DispatchQueue.main.async {
                self.completeOnboarding()
            }
        }
        
        return .transactionAddition // Fallback
    }
    
    /// Unified: Determine next incomplete step after a given step using progressive gates
    private func determineNextIncompleteStep(after currentStep: OnboardingStep) -> OnboardingStep {
        print("🔄 OnboardingFlow: Finding next incomplete step after \(currentStep)")
        
        // Use same gate validation as initial step determination
        let stateManager = OnboardingStateManager.shared
        let gateResults = stateManager.validateAllGates()
        
        // Define step order
        let orderedSteps: [OnboardingStep] = [
            .valueFeature1,
            .valueFeature2,
            .valueFeature3,
            .valueFeature4,
            .nameCollection,
            .currencySelection,
            .goalSelection,
            .stressSelection,
            .overspentRealization,
            .trackingDifficulty,
            .idealOutcome,
            .trackingFrequency,
            .trackingMethod,
            .socialProof,
            .transactionAddition
        ]
        
        // Find current step index
        guard let currentIndex = orderedSteps.firstIndex(of: currentStep) else {
            print("⚠️ OnboardingFlow: Unknown step \(currentStep), defaulting to emailConfirmation")
            return .emailConfirmation
        }
        
        // Check subsequent steps for first incomplete one
        for i in (currentIndex + 1)..<orderedSteps.count {
            let nextStep = orderedSteps[i]
            
            switch nextStep {
            case .valueFeature1, .valueFeature2, .valueFeature3, .valueFeature4:
                // Value features don't have gates, just proceed through them
                print("🎯 OnboardingFlow: Next step: \(nextStep)")
                return nextStep
            case .emailConfirmation:
                if gateResults[.emailVerification] == false {
                    print("🎯 OnboardingFlow: Next incomplete step: \(nextStep)")
                    return nextStep
                }
            case .nameCollection:
                if gateResults[.nameCollection] == false {
                    print("🎯 OnboardingFlow: Next incomplete step: \(nextStep)")
                    return nextStep
                }
            case .currencySelection:
                if gateResults[.currencySelection] == false {
                    print("🎯 OnboardingFlow: Next incomplete step: \(nextStep)")
                    return nextStep
                }
            case .goalSelection:
                if gateResults[.goalSelection] == false {
                    print("🎯 OnboardingFlow: Next incomplete step: \(nextStep)")
                    return nextStep
                }
            case .stressSelection:
                // Stress selection doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: stress selection")
                return nextStep
            case .overspentRealization:
                // Overspent realization doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: overspent realization")
                return nextStep
            case .trackingDifficulty:
                // Tracking difficulty doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: tracking difficulty")
                return nextStep
            case .idealOutcome:
                // Ideal outcome doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: ideal outcome")
                return nextStep
            case .trackingFrequency:
                // Tracking frequency doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: tracking frequency")
                return nextStep
            case .trackingMethod:
                // Tracking method doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: tracking method")
                return nextStep
            case .socialProof:
                // Social proof doesn't have a gate, just proceed through it
                print("🎯 OnboardingFlow: Next step: social proof")
                return nextStep
            case .transactionAddition:
                let transactionGateComplete = stateManager.checkTransactionGate()
                if !transactionGateComplete {
                    print("🎯 OnboardingFlow: Next incomplete step: \(nextStep)")
                    return nextStep
                } else {
                    print("⚠️ OnboardingFlow: Transaction gate marked complete - may be skipping transaction step")
                    print("   This could be due to previous test completion flags")
                }
            }
        }
        
        // All subsequent steps complete - finish onboarding
        print("🎉 OnboardingFlow: All remaining steps complete - finishing onboarding")
        DispatchQueue.main.async {
            self.completeOnboarding()
        }
        
        return .transactionAddition // Fallback
    }
    
    // Helper function to check if user has complete name (strict validation)
    private func checkUserHasCompleteName(_ name: String) -> Bool {
        print("🔍 OnboardingFlow: ======= GMAIL NAME VALIDATION DEBUG =======")
        print("🔍 OnboardingFlow: Input name parameter: '\(name)'")
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameComponents = trimmedName.components(separatedBy: " ").filter { !$0.isEmpty }
        let hasMultipleWords = nameComponents.count >= 2
        let hasContent = !trimmedName.isEmpty && trimmedName.count >= 1 // Changed from >= 2 to >= 1
        
        print("🔍 OnboardingFlow: Local name analysis:")
        print("   - Trimmed name: '\(trimmedName)'")
        print("   - Name components: \(nameComponents)")
        print("   - Has content: \(hasContent)")
        print("   - Has multiple words: \(hasMultipleWords)")
        
        // Simplified validation - accept any reasonable name input
        let isMeaningfulSingleName = nameComponents.count == 1 && 
                                   trimmedName.count >= 1 && // Accept any single character or longer
                                   !trimmedName.contains("@") && // Only reject obvious email patterns
                                   !trimmedName.contains("+") // Only reject obvious email patterns
        
        let hasValidLocalName = hasContent && (hasMultipleWords || isMeaningfulSingleName)
        print("🔍 OnboardingFlow: Local name validation: \(hasValidLocalName ? "✅" : "❌")")
        
        // CURRENT: No-auth flow - skip Firebase displayName check
        var hasValidFirebaseName = false
        // FUTURE: Uncomment when re-enabling authentication
        /*
        #if canImport(FirebaseAuth)
        if let firebaseUser = Auth.auth().currentUser,
           let displayName = firebaseUser.displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

            let isGoogleSignIn = firebaseUser.providerData.contains { $0.providerID == "google.com" }
            let isAppleSignIn = firebaseUser.providerData.contains { $0.providerID == "apple.com" }
            let isSocialSignIn = isGoogleSignIn || isAppleSignIn

            print("🔍 OnboardingFlow: Firebase user found:")
            print("   - Display name: '\(displayName)'")
            print("   - Is Google sign-in: \(isGoogleSignIn)")
            print("   - Is Apple sign-in: \(isAppleSignIn)")
            print("   - Is social sign-in: \(isSocialSignIn)")

            if isSocialSignIn {
                let firebaseNameComponents = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: " ").filter { !$0.isEmpty }
                hasValidFirebaseName = firebaseNameComponents.count >= 1 && firebaseNameComponents[0].count >= 1

                let signInType = isGoogleSignIn ? "Google" : "Apple"
                print("🔍 OnboardingFlow: \(signInType) user Firebase name check:")
                print("   - Firebase displayName: '\(displayName)' → \(hasValidFirebaseName ? "✅" : "❌")")
                print("   - Name components: \(firebaseNameComponents)")
            } else {
                print("🔍 OnboardingFlow: Not a social sign-in, skipping Firebase name check")
            }
        } else {
            print("🔍 OnboardingFlow: No Firebase user or displayName found")
        }
        #endif
        */
        
        let finalResult = hasValidLocalName || hasValidFirebaseName
        
        print("🔍 OnboardingFlow: ======= FINAL NAME VALIDATION RESULT =======")
        print("   - Local name valid: \(hasValidLocalName)")
        print("   - Firebase name valid: \(hasValidFirebaseName)")
        print("   - Final result: \(finalResult ? "✅ (name available - should skip name collection)" : "❌ (name required - should show name collection)")")
        print("🔍 OnboardingFlow: ======= END NAME VALIDATION DEBUG =======")
        
        return finalResult
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
    /// CURRENT: Always true in no-auth flow
    private func checkEmailVerification() -> Bool {
        // CURRENT: No-auth flow - always return true (email not required)
        print("🔍 OnboardingFlow: No-auth flow - email verification bypassed")
        return true

        // FUTURE: Uncomment when re-enabling authentication
        /*
        // Check persistent flag first (for app resume scenarios)
        let hasCompletedEmailVerification = UserDefaults.standard.bool(forKey: "hasCompletedEmailVerification")

        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            let isVerified = currentUser.isEmailVerified
            let isGoogleSignIn = currentUser.providerData.contains { $0.providerID == "google.com" }
            let isAppleSignIn = currentUser.providerData.contains { $0.providerID == "apple.com" }
            let isSocialSignIn = isGoogleSignIn || isAppleSignIn

            print("🔍 OnboardingFlow: Email verification status:")
            print("   - Firebase verified: \(isVerified)")
            print("   - Persistent flag: \(hasCompletedEmailVerification)")
            print("   - Google sign-in: \(isGoogleSignIn)")
            print("   - Apple sign-in: \(isAppleSignIn)")
            print("   - Social sign-in: \(isSocialSignIn)")
            print("   - Provider data: \(currentUser.providerData.map { $0.providerID })")

            // ENHANCED: Social signups (Google/Apple) are typically auto-verified
            if isSocialSignIn {
                let signInType = isGoogleSignIn ? "Google" : "Apple"
                print("🔍 OnboardingFlow: \(signInType) sign-in detected - treating as verified")
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
        */
    }
    
    /// Unified: Determine next step after name collection using progressive gates
    private func determineNextStepAfterName() -> OnboardingStep {
        print("👤 OnboardingFlow: Determining next step after name...")
        
        // Check if currency gate is complete
        let currencyComplete = OnboardingStateManager.shared.checkCurrencySelectionGate()
        print("🔍 OnboardingFlow: Currency gate complete: \(currencyComplete)")
        
        if !currencyComplete {
            print("➡️ OnboardingFlow: Next step: currency selection")
            return .currencySelection
        }
        
        // Check if goals gate is complete
        let goalsComplete = OnboardingStateManager.shared.checkGoalSelectionGate()
        print("🔍 OnboardingFlow: Goals gate complete: \(goalsComplete)")
        
        if !goalsComplete {
            print("➡️ OnboardingFlow: Next step: goal selection")
            return .goalSelection
        }
        
        // Check if transaction gate is complete
        let transactionComplete = OnboardingStateManager.shared.checkTransactionGate()
        print("🔍 OnboardingFlow: Transaction gate complete: \(transactionComplete)")
        
        if !transactionComplete {
            print("➡️ OnboardingFlow: Next step: transaction addition")
            return .transactionAddition
        }
        
        // All steps complete - shouldn't happen but fallback to transaction
        print("⚠️ OnboardingFlow: All steps complete, fallback to transaction")
        return .transactionAddition
    }
    
    /// Unified: Determine next step after currency selection using progressive gates
    private func determineNextStepAfterCurrency() -> OnboardingStep {
        print("💰 OnboardingFlow: Determining next step after currency...")
        
        // Check if goals gate is complete
        let goalsComplete = OnboardingStateManager.shared.checkGoalSelectionGate()
        print("🔍 OnboardingFlow: Goals gate complete: \(goalsComplete)")
        
        if !goalsComplete {
            print("➡️ OnboardingFlow: Next step: goal selection")
            return .goalSelection
        }
        
        // Check if transaction gate is complete
        let transactionComplete = OnboardingStateManager.shared.checkTransactionGate()
        print("🔍 OnboardingFlow: Transaction gate complete: \(transactionComplete)")
        
        if !transactionComplete {
            print("➡️ OnboardingFlow: Next step: transaction addition")
            return .transactionAddition
        }
        
        // All steps complete - shouldn't happen but fallback to transaction
        print("⚠️ OnboardingFlow: All steps complete, fallback to transaction")
        return .transactionAddition
    }
    
    /// Unified: Determine next step after goal selection using progressive gates
    private func determineNextStepAfterGoals() -> OnboardingStep {
        print("🎯 OnboardingFlow: Determining next step after goals...")
        
        // Check if transaction gate is complete
        let transactionComplete = OnboardingStateManager.shared.checkTransactionGate()
        print("🔍 OnboardingFlow: Transaction gate complete: \(transactionComplete)")
        
        if !transactionComplete {
            print("➡️ OnboardingFlow: Next step: transaction addition")
            return .transactionAddition
        }
        
        // All steps complete - shouldn't happen but fallback to transaction
        print("⚠️ OnboardingFlow: All steps complete, fallback to transaction")
        return .transactionAddition
    }
    
    private func completeOnboarding() {
        print("🏁 OnboardingFlow: ======= COMPLETING ONBOARDING =======")
        print("🏁 OnboardingFlow: Completing onboarding process...")
        print("🏁 OnboardingFlow: Called from thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

        // Clear active onboarding session flag
        UserDefaults.standard.set(false, forKey: "isActiveOnboardingSession")
        print("🏁 OnboardingFlow: Cleared active onboarding session flag")
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

        print("🎯 OnboardingFlow: Onboarding data saved!")
        print("💰 OnboardingFlow: ======= SHOWING TRIAL PAYWALL =======")

        // Show paywall immediately - no delay!
        showingPaywall = true
    }

    /// Called after paywall is dismissed to finish onboarding and show welcome
    private func finishOnboardingAfterPaywall() {
        print("🏁 OnboardingFlow: ======= FINISHING AFTER PAYWALL =======")

        // Check if user subscribed
        let isProUser = RevenueCatManager.shared.isProUser
        print("🏁 OnboardingFlow: User is Pro: \(isProUser)")

        // Track onboarding completed
        AnalyticsManager.shared.track(.onboardingCompleted, properties: [
            "subscribed": isProUser,
            "currency": selectedCurrency.rawValue
        ])

        // Call onComplete to dismiss onboarding and transition to main app
        print("🏁 OnboardingFlow: Calling onComplete callback...")
        onComplete()

        // Start slide down animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🏁 OnboardingFlow: ======= STARTING SLIDE ANIMATION =======")
            withAnimation(.easeInOut(duration: 0.35)) {
                isDismissing = true
            }
        }

        // Show welcome toast after a brief delay (if user didn't subscribe, subscription toast is handled by notification)
        if !isProUser {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let userName = UserManager.shared.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let firstName = userName.components(separatedBy: " ").first ?? ""

                print("👋 OnboardingFlow: Showing welcome toast")
                if firstName.isEmpty {
                    toastManager.showWelcome()
                } else {
                    toastManager.showWelcome(firstName)
                }
            }
        }
    }
    
    // MARK: - Progress Bar System
    
    /// Calculate dynamic progress based on user type and current step
    private func calculateProgress() -> (current: Int, total: Int, percentage: Double) {
        // Determine which steps this user actually needs
        var userSteps: [OnboardingStep] = []

        // Always start with value features
        userSteps.append(.valueFeature1)
        userSteps.append(.valueFeature2)
        userSteps.append(.valueFeature3)
        userSteps.append(.valueFeature4)

        // Check if user needs name collection
        if shouldShowNameCollection() {
            userSteps.append(.nameCollection)
        }

        // Always need currency, goals, stress selection, overspent realization, tracking difficulty, ideal outcome, tracking frequency, tracking method, and transaction
        userSteps.append(.currencySelection)
        userSteps.append(.goalSelection)
        userSteps.append(.stressSelection)
        userSteps.append(.overspentRealization)
        userSteps.append(.trackingDifficulty)
        userSteps.append(.idealOutcome)
        userSteps.append(.trackingFrequency)
        userSteps.append(.trackingMethod)
        userSteps.append(.transactionAddition)
        
        // Find current step position
        guard let currentIndex = userSteps.firstIndex(of: currentStep) else {
            return (current: 1, total: userSteps.count, percentage: 0.0)
        }
        
        let currentStepNumber = currentIndex + 1
        let totalSteps = userSteps.count
        let percentage = Double(currentStepNumber) / Double(totalSteps)
        
        print("🔍 OnboardingFlow: Progress calculation:")
        print("   - User steps: \(userSteps.map { "\($0)" })")
        print("   - Current step: \(currentStep) (position \(currentStepNumber))")
        print("   - Total steps: \(totalSteps)")
        print("   - Progress: \(String(format: "%.1f", percentage * 100))%")
        
        return (current: currentStepNumber, total: totalSteps, percentage: percentage)
    }
    
    /// Check if this user should see name collection step
    /// CURRENT: Always true in no-auth flow
    private func shouldShowNameCollection() -> Bool {
        // CURRENT: No-auth flow - always show name collection
        return true

        // FUTURE: Uncomment when re-enabling authentication
        /*
        #if canImport(FirebaseAuth)
        // For social users (Google/Apple) with complete Firebase displayName, skip name collection
        if let currentUser = Auth.auth().currentUser,
           let displayName = currentUser.displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let components = displayName.components(separatedBy: " ")
            let hasValidFirebaseName = components.count >= 2 && components.allSatisfy { !$0.isEmpty }

            let isGoogleSignIn = currentUser.providerData.contains { $0.providerID == "google.com" }
            let isAppleSignIn = currentUser.providerData.contains { $0.providerID == "apple.com" }
            let isSocialSignIn = isGoogleSignIn || isAppleSignIn

            if hasValidFirebaseName && isSocialSignIn {
                let signInType = isGoogleSignIn ? "Google" : "Apple"
                print("🔍 OnboardingFlow: \(signInType) user with valid displayName - skipping name collection")
                return false
            }
        }
        #endif

        // Regular users or social users without complete names need name collection
        return true
        */
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
        forceStartStep: nil
    )
}