//
//  CashMonkiApp.swift
//  CashMonki
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI
import SwiftData
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@main
struct CashMonkiApp: App {
    @State private var showingOnboarding = false
    @State private var isNewUser = false
    @State private var showingWelcome = true
    @StateObject private var authManager = AuthenticationManager.shared
    
    @State private var sharedModelContainer: ModelContainer = {
        // Create a minimal in-memory container for immediate startup
        let schema = Schema([Item.self])
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            fatalError("Could not create temporary ModelContainer: \(error)")
        }
    }()
    
    private func createPersistentModelContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Only show main content after welcome screen is dismissed
                if !showingWelcome {
                    Group {
                        if authManager.isAuthenticated {
                            if showingOnboarding {
                                OnboardingFlow(
                                    isPresented: $showingOnboarding,
                                    onComplete: {
                                        print("🎉 CashMonkiApp: ======= ONBOARDING COMPLETION CALLBACK =======")
                                        print("🎉 CashMonkiApp: BEFORE completion - isNewRegistration: \(authManager.isNewRegistration)")
                                        print("🎉 CashMonkiApp: BEFORE completion - showingOnboarding: \(showingOnboarding)")
                                        print("🎉 CashMonkiApp: BEFORE completion - isNewUser: \(isNewUser)")
                                        
                                        showingOnboarding = false
                                        isNewUser = false
                                        
                                        // CRITICAL FIX: Reset isNewRegistration flag to prevent flag clearing on next launch
                                        authManager.isNewRegistration = false
                                        
                                        print("🎉 CashMonkiApp: AFTER completion - isNewRegistration: \(authManager.isNewRegistration)")
                                        print("🎉 CashMonkiApp: AFTER completion - showingOnboarding: \(showingOnboarding)")
                                        print("🎉 CashMonkiApp: AFTER completion - isNewUser: \(isNewUser)")
                                        print("🔄 CashMonkiApp: Reset authManager.isNewRegistration to false after onboarding completion")
                                        
                                        // Show welcome toast with user's first name (SINGLE TIME ONLY)
                                        if let currentUser = authManager.currentUser {
                                            let firstName = currentUser.name.components(separatedBy: " ").first ?? "there"
                                            print("🎉 CashMonkiApp: ======= NEW USER ONBOARDING COMPLETION =======")
                                            print("🎉 CashMonkiApp: Onboarding completed, preparing welcome toast for: \(firstName)")
                                            print("🎉 CashMonkiApp: Current user name: '\(currentUser.name)'")
                                            print("🎉 CashMonkiApp: Current user email: '\(currentUser.email)'")
                                            print("🎉 CashMonkiApp: Extracted firstName: '\(firstName)'")
                                            
                                            // Check if we already showed welcome toast for this session
                                            let hasShownWelcomeKey = "hasShownWelcomeToast_\(currentUser.firebaseUID)"
                                            if !UserDefaults.standard.bool(forKey: hasShownWelcomeKey) {
                                                // Mark as shown BEFORE posting to prevent duplicates
                                                UserDefaults.standard.set(true, forKey: hasShownWelcomeKey)
                                                
                                                // Post notification with delay to allow ContentView to initialize properly
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    print("🎉 CashMonkiApp: ======= POSTING WELCOME TOAST NOTIFICATION (DELAYED) =======")
                                                    print("🎉 CashMonkiApp: Posting welcome toast notification for: \(firstName)")
                                                    print("🎉 CashMonkiApp: Notification name: 'ShowWelcomeToast'")
                                                    print("🎉 CashMonkiApp: Notification object: '\(firstName)'")
                                                    NotificationCenter.default.post(
                                                        name: NSNotification.Name("ShowWelcomeToast"),
                                                        object: firstName
                                                    )
                                                    print("🎉 CashMonkiApp: ✅ Welcome toast notification posted successfully!")
                                                }
                                            } else {
                                                print("🎉 CashMonkiApp: ⏭️ Welcome toast already shown for this user session - skipping")
                                            }
                                        } else {
                                            print("🎉 CashMonkiApp: ❌ No current user found - cannot show welcome toast")
                                        }
                                    },
                                    onBack: {
                                        // Go back to login by logging out
                                        authManager.logout()
                                        showingOnboarding = false
                                        isNewUser = false
                                    },
                                    userEmail: authManager.currentUser?.email,
                                    isNewRegistration: authManager.isNewRegistration,
                                    forceStartStep: nil
                                )
                                .withToast()
                            } else {
                                ContentView()
                                    .withToast()
                                    .preferredColorScheme(.light) // Force light mode - never change colors for dark mode
                            }
                        } else {
                            AuthenticationView()
                                .preferredColorScheme(.light) // Force light mode - never change colors for dark mode
                                .onAppear {
                                    print("🔐 CashMonkiApp: Showing AuthenticationView - login first approach")
                                    print("🔐 CashMonkiApp: User authenticated: \(authManager.isAuthenticated)")
                                    print("👤 CashMonkiApp: Current user: \(authManager.currentUser?.email ?? "none")")
                                }
                        }
                    }
                    .transition(.opacity)
                }
                
                // Welcome screen overlay
                if showingWelcome {
                    WelcomeScreen(isPresented: $showingWelcome)
                        .zIndex(1000)
                        .transition(.opacity)
                }
            }
                .preferredColorScheme(.light) // Force light mode globally - never change colors for dark mode
                .onAppear {
                    print("🚀 CashMonkiApp: APP STARTUP")
                    print("🎬 CashMonkiApp: Welcome screen showing: \(showingWelcome)")
                    
                    // Add crash breadcrumbs for TestFlight debugging
                    print("🔍 TESTFLIGHT DEBUG: App launch started")
                    print("🔍 TESTFLIGHT DEBUG: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
                    print("🔍 TESTFLIGHT DEBUG: App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
                    print("🔍 TESTFLIGHT DEBUG: Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")")
                    print("🔍 TESTFLIGHT DEBUG: Device: \(UIDevice.current.model) \(UIDevice.current.systemVersion)")
                    
                    do {
                        // Security check for production builds
                        print("🔐 CashMonkiApp: Running security check...")
                        print("🔍 TESTFLIGHT DEBUG: About to call SecureAPIProvider.clearInfoPlistKeysForProduction()")
                        SecureAPIProvider.clearInfoPlistKeysForProduction()
                        print("✅ Security check completed")
                        print("🔍 TESTFLIGHT DEBUG: SecureAPIProvider completed successfully")
                        
                        // Load environment variables first (safe for TestFlight)
                        print("🌍 CashMonkiApp: Loading environment variables...")
                        print("🔍 TESTFLIGHT DEBUG: About to call EnvironmentLoader.initialize()")
                        EnvironmentLoader.initialize()
                        print("✅ Environment variables loaded")
                        print("🔍 TESTFLIGHT DEBUG: EnvironmentLoader completed successfully")
                        
                        // Initialize API keys with error handling
                        print("🔐 CashMonkiApp: Initializing API keys...")
                        print("🔍 TESTFLIGHT DEBUG: About to call Config.initializeAPIKeys()")
                        Config.initializeAPIKeys()
                        print("✅ API keys initialized")
                        print("🔍 TESTFLIGHT DEBUG: Config.initializeAPIKeys() completed successfully")
                        
                        // Skip force refresh for TestFlight to prevent crashes
                        if !isTestFlightBuild() {
                            print("🔄 CashMonkiApp: Force refreshing API keys (Debug mode)...")
                            print("🔍 TESTFLIGHT DEBUG: Not TestFlight - refreshing API keys")
                            Config.forceRefreshOpenRouterKey()
                            Config.forceRefreshRevenueCatKey()
                            print("✅ API keys refreshed")
                        } else {
                            print("✅ TestFlight build detected - skipping API key refresh")
                            print("🔍 TESTFLIGHT DEBUG: TestFlight build - skipping dangerous operations")
                        }
                        
                        // Initialize RevenueCat with error handling
                        print("🔄 CashMonkiApp: Configuring RevenueCat...")
                        print("🔍 TESTFLIGHT DEBUG: About to configure RevenueCat")
                        #if canImport(RevenueCat)
                        RevenueCatManager.shared.configure()
                        print("✅ RevenueCat configured")
                        print("🔍 TESTFLIGHT DEBUG: RevenueCat configured successfully")
                        #endif
                        print("🔍 TESTFLIGHT DEBUG: All initialization steps completed successfully!")
                    } catch {
                        print("💥 CashMonkiApp: CRASH PREVENTED during initialization: \(error)")
                        print("💥 CashMonkiApp: Error details: \(error.localizedDescription)")
                        print("💥 TESTFLIGHT DEBUG: Caught error during initialization - app will continue")
                        print("💥 TESTFLIGHT DEBUG: Error type: \(type(of: error))")
                        print("💥 TESTFLIGHT DEBUG: Error: \(String(describing: error))")
                        print("🔄 CashMonkiApp: Continuing with app launch...")
                        // Don't crash the app - continue with partial initialization
                    }
                    
                    // Switch to persistent storage asynchronously after startup
                    DispatchQueue.global(qos: .background).async {
                        let persistentContainer = createPersistentModelContainer()
                        
                        DispatchQueue.main.async {
                            sharedModelContainer = persistentContainer
                        }
                    }
                    
                    // Debug: Check if custom fonts are loaded
                    #if DEBUG
                    AppFonts.debugAvailableFonts()
                    #endif
                }
                .onChange(of: showingWelcome) { oldValue, newValue in
                    print("🎬 CashMonkiApp: Welcome screen state changed from \(oldValue) to \(newValue)")
                    
                    // Initialize Firebase and RevenueCat after welcome screen is dismissed
                    if !newValue && oldValue {
                        print("🔥 CashMonkiApp: Welcome screen dismissed - initializing services...")
                        initializeFirebase()
                        initializeRevenueCat()
                    }
                }
                .onChange(of: authManager.isAuthenticated) { oldValue, isAuthenticated in
                    print("🔄 CashMonkiApp: Authentication changed from \(oldValue) to \(isAuthenticated)")
                    
                    // Prevent unnecessary onboarding checks for existing authenticated users
                    if oldValue == true && isAuthenticated == true {
                        print("🔄 CashMonkiApp: Auth state refresh detected (user still authenticated) - skipping onboarding check")
                        return
                    }
                    
                    print("🔄 CashMonkiApp: Current user details:")
                    print("   - Email: \(authManager.currentUser?.email ?? "none")")
                    print("   - Name: '\(authManager.currentUser?.name ?? "none")'")
                    print("   - Firebase UID: \(authManager.currentUser?.firebaseUID ?? "none")")
                    print("   - Is new registration: \(authManager.isNewRegistration)")
                    
                    if isAuthenticated {
                        // Refresh UserManager with the authenticated user
                        print("🔄 CashMonkiApp: User authenticated, refreshing UserManager...")
                        UserManager.shared.refreshWithAuthenticatedUser()
                        
                        // Migrate orphaned transactions after user authentication
                        print("🔄 CashMonkiApp: Running account migration...")
                        AccountManager.shared.migrateOrphanedTransactionsAtStartup()
                        
                        // Initialize currency preferences from user account only if no preference exists
                        print("💰 CashMonkiApp: Checking currency preferences...")
                        if UserDefaults.standard.string(forKey: "userPrimaryCurrency") == nil {
                            print("💰 CashMonkiApp: No saved currency preference - initializing from user account...")
                            CurrencyPreferences.shared.initializeFromUserAccount()
                        } else {
                            print("💰 CashMonkiApp: Found saved currency preference - preserving user's choice")
                        }
                        
                        // Sync secondary currency with rate manager if not set
                        if CurrencyPreferences.shared.secondaryCurrency == nil {
                            print("💱 CashMonkiApp: No secondary currency set, using default USD")
                            CurrencyPreferences.shared.setSecondaryCurrency(.usd)
                        }
                        
                        // Check if this is a new user who needs onboarding
                        print("🔄 CashMonkiApp: Checking for onboarding...")
                        print("🔍 CashMonkiApp: About to call checkForOnboarding() with:")
                        print("   - Current showingOnboarding: \(showingOnboarding)")
                        print("   - Current isNewUser: \(isNewUser)")
                        
                        // Clear onboarding flags for new registrations to ensure they go through onboarding
                        print("🔍 CashMonkiApp: CRITICAL DEBUG - Checking isNewRegistration flag")
                        print("🔍 CashMonkiApp: authManager.isNewRegistration = \(authManager.isNewRegistration)")
                        
                        if authManager.isNewRegistration {
                            print("🆕 CashMonkiApp: NEW REGISTRATION - Clearing onboarding completion flags")
                            print("🧹 CashMonkiApp: BEFORE clearing - hasCompletedCurrencySelection: \(UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection"))")
                            print("🧹 CashMonkiApp: BEFORE clearing - hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                            
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                            UserDefaults.standard.set(false, forKey: "hasCompletedCurrencySelection")
                            
                            // CRITICAL: Reset OnboardingStateManager for new registrations
                            OnboardingStateManager.shared.resetOnboardingState()
                            print("🔄 CashMonkiApp: Reset OnboardingStateManager for new registration")
                            
                            print("🧹 CashMonkiApp: AFTER clearing - hasCompletedCurrencySelection: \(UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection"))")
                            print("🧹 CashMonkiApp: AFTER clearing - hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                        } else {
                            print("✅ CashMonkiApp: NOT a new registration - preserving existing flags")
                            print("📄 CashMonkiApp: Current hasCompletedCurrencySelection: \(UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection"))")
                            print("📄 CashMonkiApp: Current hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
                        }
                        
                        // CRITICAL: Check if this is a previously deleted account with no data
                        let userManager = UserManager.shared
                        let hasAnyUserData = !userManager.currentUser.transactions.isEmpty || 
                                           userManager.currentUser.accounts.count > 1 || // More than just default account
                                           !CurrencyPreferences.shared.primaryCurrency.rawValue.isEmpty
                        
                        if !authManager.isNewRegistration && !hasAnyUserData {
                            print("🔄 CashMonkiApp: DELETED ACCOUNT DETECTED - User has auth but no data, treating as new user")
                            print("🧹 CashMonkiApp: Resetting ALL local settings for deleted account restoration")
                            resetAllLocalSettingsForDeletedAccount()
                        }
                        
                        checkOnboardingWithStateManager()
                        print("🔍 CashMonkiApp: After state manager check:")
                        print("   - Updated showingOnboarding: \(showingOnboarding)")
                        print("   - Updated isNewUser: \(isNewUser)")
                        
                        // Identify user to RevenueCat
                        #if canImport(RevenueCat)
                        if let userId = authManager.currentUser?.id.uuidString {
                            RevenueCatManager.shared.identifyUser(userId: userId)
                        }
                        #endif
                    } else {
                        print("🔄 CashMonkiApp: User logged out")
                        #if canImport(RevenueCat)
                        RevenueCatManager.shared.logoutUser()
                        #endif
                        showingOnboarding = false
                        isNewUser = false
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Firebase Initialization
    
    private func initializeFirebase() {
        print("🔥 App startup: Initializing Firebase...")
#if canImport(FirebaseCore)
        print("✅ FirebaseCore is available")
        if FirebaseApp.app() == nil {
            print("🔥 Configuring Firebase...")
            FirebaseApp.configure()
            print("✅ Firebase configured successfully")
            
            // Now that Firebase is configured, check authentication
            authManager.checkAuthenticationStatus()
            print("🔐 App startup: Auth status - isAuthenticated: \(authManager.isAuthenticated)")
            print("🔐 App startup: Current user: \(authManager.currentUser?.email ?? "none")")
            
            // Now it's safe to restore user session since Firebase is configured
            print("🏗️ App startup: Firebase ready - restoring user session...")
            UserManager.shared.restoreUserSession()
        } else {
            print("✅ Firebase was already configured")
            print("🔐 App startup: Auth status - isAuthenticated: \(authManager.isAuthenticated)")
            print("🔐 App startup: Current user: \(authManager.currentUser?.email ?? "none")")
            
            // Firebase was already configured, safe to restore user session
            print("🏗️ App startup: Firebase already ready - restoring user session...")
            UserManager.shared.restoreUserSession()
        }
        
        // Verify GoogleService-Info.plist exists
        if let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") {
            print("✅ GoogleService-Info.plist found at: \(url.path)")
            
            // Debug: Print Firebase project configuration
            if let plistData = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                if let projectId = plist["PROJECT_ID"] as? String {
                    print("🔥 Firebase Project ID: \(projectId)")
                }
                if let appId = plist["GOOGLE_APP_ID"] as? String {
                    print("🔥 Firebase App ID: \(appId.prefix(20))...")
                }
            }
        } else {
            print("❌ GoogleService-Info.plist NOT FOUND! This will cause Firebase to fail.")
        }
        
        // Add Firebase connection monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🌐 Testing Firebase connectivity...")
            let userManager = UserManager.shared
            userManager.testFirebaseConnection()
        }
#else
        print("❌ FirebaseCore not available - Firebase packages not installed")
        print("🔧 Add Firebase packages via Xcode Package Manager")
#endif
    }
    
    // MARK: - RevenueCat Initialization
    
    private func initializeRevenueCat() {
        print("💰 CashMonkiApp: Initializing RevenueCat...")
        #if canImport(RevenueCat)
        RevenueCatManager.shared.configure()
        print("✅ CashMonkiApp: RevenueCat initialized")
        #else
        print("❌ RevenueCat not available - skipping initialization")
        #endif
    }
    
    // MARK: - Onboarding State Management
    
    private func checkOnboardingWithStateManager() {
        print("🎯 CashMonkiApp: ======= USING ONBOARDING STATE MANAGER =======")
        
        let onboardingStateManager = OnboardingStateManager.shared
        print("🎯 CashMonkiApp: Current state: \(onboardingStateManager.currentState)")
        
        let shouldShowOnboarding = onboardingStateManager.shouldShowOnboardingOnResume()
        
        print("🎯 CashMonkiApp: State manager decision: shouldShow = \(shouldShowOnboarding)")
        
        if shouldShowOnboarding {
            print("🎯 CashMonkiApp: Showing onboarding based on state manager")
            showingOnboarding = true
            isNewUser = authManager.isNewRegistration
        } else {
            print("✅ CashMonkiApp: No onboarding needed - user is complete or within grace period")
            showingOnboarding = false
            isNewUser = false
        }
        
        // Print debug info for troubleshooting
        print(onboardingStateManager.getDebugInfo())
        print("🎯 CashMonkiApp: Final state: showingOnboarding=\(showingOnboarding), isNewUser=\(isNewUser)")
    }
    
    // MARK: - Deleted Account Recovery
    
    /// Reset all local settings and preferences for a deleted account that's signing back in
    private func resetAllLocalSettingsForDeletedAccount() {
        print("🧹 CashMonkiApp: COMPREHENSIVE LOCAL RESET for deleted account restoration")
        
        // Clear all onboarding completion flags
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "hasCompletedCurrencySelection")
        
        // Reset OnboardingStateManager for deleted account restoration
        OnboardingStateManager.shared.resetOnboardingState()
        print("🔄 CashMonkiApp: Reset OnboardingStateManager for deleted account")
        
        // Clear any other app-specific settings that might interfere
        UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        UserDefaults.standard.removeObject(forKey: "hasSeenWelcome")
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        UserDefaults.standard.removeObject(forKey: "firebaseSyncEnabled")
        
        // Reset currency preferences to defaults
        CurrencyPreferences.shared.setPrimaryCurrency(.usd)
        CurrencyPreferences.shared.setSecondaryCurrency(nil)
        
        // Force synchronize UserDefaults
        UserDefaults.standard.synchronize()
        
        print("🧹 CashMonkiApp: Local reset completed:")
        print("   ✅ Onboarding flags cleared")
        print("   ✅ Language preferences reset")
        print("   ✅ Currency preferences reset to USD")
        print("   ✅ Firebase sync settings cleared")
        print("   🎯 User will now go through complete onboarding flow")
    }
    
    // MARK: - TestFlight Detection
    
    /// Detect if this is a TestFlight build
    private func isTestFlightBuild() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.path.contains("sandboxReceipt")
    }
}
