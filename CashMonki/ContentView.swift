//
//  ContentView.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum Tab: Hashable { case home, transactions, settings }

struct NavbarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var primaryCurrency: Currency = .php
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var onboardingStateManager = OnboardingStateManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingOnboarding = false
    @State private var observersSetUp = false

    var body: some View {
        ZStack {
            // Main content area
            VStack(spacing: 0) {
                // Main content area
                ZStack {
                    switch selectedTab {
                    case .home:
                        HomePage(selectedTab: $selectedTab, primaryCurrency: $primaryCurrency)
                    case .transactions:
                        ReceiptsPage()
                    case .settings:
                        SettingsPage(primaryCurrency: $primaryCurrency)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Custom navigation bar
                customNavigationBar
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .preferredColorScheme(.light) // Force light mode - never change colors for dark mode
        .onAppear {
            Config.initializeAPIKey()
            
            // Initialize currency from user's account settings
            initializePrimaryCurrency()
            
            // Check onboarding status using state manager
            print("🔍 ContentView: onAppear - checking onboarding with state manager")
            checkOnboardingWithStateManager()
            
            // Set up notification observers only once to prevent duplicate toasts
            if !observersSetUp {
                observersSetUp = true

                // Listen for welcome toast notification
                print("🎉 ContentView: Setting up notification observers (first time only)")
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowWelcomeToast"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let firstName = notification.object as? String {
                        self.toastManager.showWelcome(firstName)
                    }
                }

                // Set up subscription success notification observer
                NotificationCenter.default.addObserver(
                    forName: .subscriptionSucceeded,
                    object: nil,
                    queue: .main
                ) { notification in
                    print("🎯 ContentView: Received subscription success notification")
                    self.toastManager.showSubscriptionSuccess()
                }

                // Set up subscription error notification observer
                NotificationCenter.default.addObserver(
                    forName: .subscriptionFailed,
                    object: nil,
                    queue: .main
                ) { notification in
                    let errorMessage = notification.userInfo?["errorMessage"] as? String ?? "Subscription failed"
                    self.toastManager.showSubscriptionError(message: errorMessage)
                }
                print("🎯 ContentView: ✅ All notification observers set up successfully!")
            }
            
#if canImport(UIKit)
            UITabBar.appearance().backgroundColor = UIColor.systemBackground
#endif
        }
        .onDisappear {
            // Clean up notification observers
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowWelcomeToast"), object: nil)
            NotificationCenter.default.removeObserver(self, name: .subscriptionSucceeded, object: nil)
            NotificationCenter.default.removeObserver(self, name: .subscriptionFailed, object: nil)
        }
        .onChange(of: userManager.currentUser.accounts) { _, _ in
            // Update currency when user's accounts change (e.g., after onboarding)
            initializePrimaryCurrency()
        }
        .onChange(of: scenePhase) { _, newPhase in
            print("🔍 ContentView: Scene phase changed to: \(newPhase)")
            print("🔍 ContentView: Authentication status: \(AuthenticationManager.shared.isAuthenticated)")
            
            // Use smart resume logic when app becomes active
            if newPhase == .active {
                print("🔍 ContentView: Scene became active - using smart resume")
                if AuthenticationManager.shared.isAuthenticated {
                    print("🔍 ContentView: User authenticated - checking with state manager")
                    checkOnboardingWithStateManager()
                } else {
                    print("⚠️ ContentView: User not authenticated - skipping onboarding check")
                }
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingFlow(
                isPresented: $showingOnboarding,
                onComplete: {
                    print("🎯 ContentView: Onboarding completed - updating state manager")
                    onboardingStateManager.markAsComplete()
                    showingOnboarding = false
                },
                onBack: {
                    print("🎯 ContentView: Onboarding cancelled from app resume")
                    showingOnboarding = false
                },
                userEmail: AuthenticationManager.shared.currentUser?.email,
                isNewRegistration: false,
                forceStartStep: nil
            )
            .environmentObject(toastManager)
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializePrimaryCurrency() {
        // Priority 1: Use CurrencyPreferences (user's latest choice from settings)
        let preferencesCurrency = CurrencyPreferences.shared.primaryCurrency
        print("💰 ContentView: CurrencyPreferences primary currency: \(preferencesCurrency.rawValue)")
        
        // Priority 2: Use user's default account currency (onboarding choice)  
        let accountCurrency = userManager.currentUser.accounts.first(where: { $0.isDefault })?.currency
            ?? userManager.currentUser.accounts.first?.currency
        
        if let accountCurrency = accountCurrency {
            print("💰 ContentView: Account primary currency: \(accountCurrency.rawValue)")
        }
        
        // Use CurrencyPreferences as the authoritative source (user's latest setting)
        print("💰 ContentView: Initializing primary currency from CurrencyPreferences: \(preferencesCurrency.rawValue) (\(preferencesCurrency.displayName))")
        primaryCurrency = preferencesCurrency
        
        print("✅ ContentView: Primary currency initialized to: \(primaryCurrency.rawValue)")
    }
    
    // MARK: - New State Manager Integration
    
    private func checkOnboardingWithStateManager() {
        print("🎯 ContentView: ======= USING ONBOARDING STATE MANAGER =======")
        print("🎯 ContentView: Current state: \(onboardingStateManager.currentState)")
        
        #if canImport(FirebaseAuth)
        // CRITICAL FIX: Ensure Firebase auth state is loaded before checking onboarding
        if Auth.auth().currentUser != nil {
            print("🔐 ContentView: Firebase auth is loaded, proceeding with onboarding check")
        } else {
            print("⏳ ContentView: Firebase auth not ready yet, delaying onboarding check...")
            // Delay onboarding check to allow Firebase auth to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkOnboardingWithStateManager()
            }
            return
        }
        #endif
        
        let shouldShowOnboarding = onboardingStateManager.shouldShowOnboardingOnResume()
        
        print("🎯 ContentView: State manager decision: shouldShow = \(shouldShowOnboarding)")
        
        if shouldShowOnboarding {
            print("🎯 ContentView: Showing onboarding based on state manager")
            showingOnboarding = true
        } else {
            print("✅ ContentView: No onboarding needed - user is complete or within grace period")
        }
        
        // Print debug info for troubleshooting
        print(onboardingStateManager.getDebugInfo())
    }
    
    // MARK: - Custom Navigation Bar
    
    private var customNavigationBar: some View {
        HStack(spacing: 0) {
            // Home tab
            Button(action: { selectedTab = .home }) {
                VStack(spacing: 2) {
                    Image("home-line")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedTab == .home ? AppColors.primary : AppColors.foregroundTertiary)
                    Text("Home")
                        .font(
                            Font.custom("Overused Grotesk", size: 11)
                                .weight(.semibold)
                        )
                        .foregroundColor(selectedTab == .home ? AppColors.primary : AppColors.foregroundTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PlainButtonStyle())
            .animation(nil, value: selectedTab)
            
            // Transactions tab
            Button(action: { selectedTab = .transactions }) {
                VStack(spacing: 2) {
                    Image("receipt-check")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedTab == .transactions ? AppColors.primary : AppColors.foregroundTertiary)
                    Text("Transactions")
                        .font(
                            Font.custom("Overused Grotesk", size: 11)
                                .weight(.semibold)
                        )
                        .foregroundColor(selectedTab == .transactions ? AppColors.primary : AppColors.foregroundTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PlainButtonStyle())
            .animation(nil, value: selectedTab)
            
            // Profile tab
            Button(action: { selectedTab = .settings }) {
                VStack(spacing: 2) {
                    Image("user-02")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedTab == .settings ? AppColors.primary : AppColors.foregroundTertiary)
                    Text("Profile")
                        .font(
                            Font.custom("Overused Grotesk", size: 11)
                                .weight(.semibold)
                        )
                        .foregroundColor(selectedTab == .settings ? AppColors.primary : AppColors.foregroundTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PlainButtonStyle())
            .animation(nil, value: selectedTab)
        }
        .padding(.horizontal, 14)
        .padding(.top, NavigationConstants.navbarTopPadding)
        .padding(.bottom, NavigationConstants.navbarBottomPadding)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(red: 0.95, green: 0.96, blue: 0.97))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.line1stLine),
            alignment: .top
        )
    }
}
