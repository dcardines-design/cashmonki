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

enum Tab: Hashable { case home, transactions, settings }

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var primaryCurrency: Currency = .php
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var onboardingStateManager = OnboardingStateManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                HomePage(selectedTab: $selectedTab, primaryCurrency: $primaryCurrency)
                    .tabItem {
                        AppIcon(assetName: "home-line", fallbackSystemName: "house")
                    }
                    .tag(Tab.home)

                ReceiptsPage()
                    .tabItem {
                        AppIcon(assetName: "receipt-check", fallbackSystemName: "rectangle.on.rectangle")
                    }
                    .tag(Tab.transactions)

                SettingsPage(primaryCurrency: $primaryCurrency)
                    .tabItem {
                        AppIcon(assetName: "settings-01", fallbackSystemName: "gearshape")
                    }
                    .tag(Tab.settings)
            }
            .tint(AppColors.primary)
        }
        .onAppear {
            Config.initializeAPIKey()
            
            // Initialize currency from user's account settings
            initializePrimaryCurrency()
            
            // Check onboarding status using state manager
            print("🔍 ContentView: onAppear - checking onboarding with state manager")
            checkOnboardingWithStateManager()
            
            // Listen for welcome toast notification - Set up observer immediately
            print("🎉 ContentView: ======= SETTING UP WELCOME TOAST OBSERVER =======")
            print("🎉 ContentView: ToastManager initialized")
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowWelcomeToast"),
                object: nil,
                queue: .main
            ) { notification in
                print("🎉 ContentView: ======= WELCOME TOAST NOTIFICATION RECEIVED =======")
                print("🎉 ContentView: Notification observer triggered")
                print("🎉 ContentView: Notification name: \(notification.name.rawValue)")
                print("🎉 ContentView: Notification object type: \(type(of: notification.object))")
                if let firstName = notification.object as? String {
                    print("🎉 ContentView: ✅ Successfully extracted firstName: '\(firstName)'")
                    print("🎉 ContentView: 🔧 FIXED: Using environment ToastManager: \(self.toastManager)")
                    print("🎉 ContentView: 🔧 FIXED: ToastManager object ID: \(ObjectIdentifier(self.toastManager))")
                    print("🎉 ContentView: About to call self.toastManager.showWelcome('\(firstName)')...")
                    self.toastManager.showWelcome(firstName)
                    print("🎉 ContentView: ✅ Called self.toastManager.showWelcome() successfully!")
                } else {
                    print("⚠️ ContentView: ❌ Failed to extract firstName from notification")
                    print("⚠️ ContentView: notification.object: \(notification.object ?? "nil")")
                }
            }
            print("🎉 ContentView: ✅ Welcome toast observer set up successfully!")
            
#if canImport(UIKit)
            UITabBar.appearance().backgroundColor = UIColor.systemBackground
#endif
        }
        .onDisappear {
            // Clean up notification observer
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowWelcomeToast"), object: nil)
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
}

