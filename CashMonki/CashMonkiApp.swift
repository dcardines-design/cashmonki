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
#if canImport(PostHog)
import PostHog
#endif
#if canImport(FacebookCore)
import FacebookCore
#endif
#if canImport(Mixpanel)
import Mixpanel
#endif

@main
struct CashMonkiApp: App {
    @State private var showingOnboarding = false
    @State private var isNewUser = false
    @State private var showingWelcome = true
    // Note: showingPaywallAfterOnboarding removed - paywall now shown directly from OnboardingFlow
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var toastManager = ToastManager()
    
    private var sharedModelContainer: ModelContainer = CashMonkiApp.createModelContainer()

    /// Create ModelContainer as a static function to ensure consistent initialization
    /// across all build configurations (Debug, Release, Archive)
    private static func createModelContainer() -> ModelContainer {
        let schema = Schema([Item.self])
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
                        // CURRENT: No-auth flow - use showingOnboarding as primary control
                        // ContentView is always the base, onboarding shows as fullScreenCover
                        ContentView()
                            .environmentObject(toastManager)
                            .preferredColorScheme(.light)
                            .fullScreenCover(isPresented: $showingOnboarding) {
                                OnboardingFlow(
                                    isPresented: $showingOnboarding,
                                    onComplete: {
                                        print("🎉 CashMonkiApp: ======= ONBOARDING COMPLETION CALLBACK =======")
                                        // Paywall is now shown directly from OnboardingFlow
                                        // Just dismiss onboarding - welcome toast is also handled by OnboardingFlow
                                        showingOnboarding = false
                                        isNewUser = false
                                        print("✅ CashMonkiApp: Onboarding dismissed")
                                    },
                                    onBack: nil, // No back button needed - no login to go back to
                                    userEmail: nil, // No email yet - collected during onboarding
                                    isNewRegistration: true, // Treat all first-time users as new
                                    forceStartStep: nil
                                )
                                .environmentObject(toastManager)
                            }
                            // Note: Paywall after onboarding is now shown directly from OnboardingFlow
                            // This eliminates the 2-second delay between onboarding and paywall
                            .onAppear {
                                // Check if onboarding needs to be shown
                                if !OnboardingStateManager.shared.isOnboardingComplete() {
                                    showingOnboarding = true
                                }
                            }

                        // MARK: - FUTURE: Auth-first flow (commented out for future use)
                        /*
                        if authManager.isAuthenticated {
                            if showingOnboarding {
                                OnboardingFlow(
                                    isPresented: $showingOnboarding,
                                    onComplete: {
                                        print("🎉 CashMonkiApp: ======= ONBOARDING COMPLETION CALLBACK =======")
                                        showingOnboarding = false
                                        isNewUser = false
                                        authManager.isNewRegistration = false

                                        // Show welcome toast with user's first name
                                        if let currentUser = authManager.currentUser {
                                            let firstName = currentUser.name.components(separatedBy: " ").first ?? "there"
                                            let hasShownWelcomeKey = "hasShownWelcomeToast_\(currentUser.firebaseUID)"
                                            if !UserDefaults.standard.bool(forKey: hasShownWelcomeKey) {
                                                UserDefaults.standard.set(true, forKey: hasShownWelcomeKey)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                    NotificationCenter.default.post(
                                                        name: NSNotification.Name("ShowWelcomeToast"),
                                                        object: firstName
                                                    )
                                                }
                                            }
                                        }
                                    },
                                    onBack: {
                                        authManager.logout()
                                        showingOnboarding = false
                                        isNewUser = false
                                    },
                                    userEmail: authManager.currentUser?.email,
                                    isNewRegistration: authManager.isNewRegistration,
                                    forceStartStep: nil
                                )
                                .environmentObject(toastManager)
                            } else {
                                ContentView()
                                    .environmentObject(toastManager)
                                    .preferredColorScheme(.light)
                            }
                        } else {
                            AuthenticationView()
                                .preferredColorScheme(.light)
                        }
                        */
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
                    
                    // Security check for production builds
                    print("🔐 CashMonkiApp: Running security check...")
                    SecureAPIProvider.clearInfoPlistKeysForProduction()
                    print("✅ Security check completed")

                    // Load environment variables first (safe for TestFlight)
                    print("🌍 CashMonkiApp: Loading environment variables...")
                    EnvironmentLoader.initialize()
                    print("✅ Environment variables loaded")

                    // Initialize API keys with error handling
                    print("🔐 CashMonkiApp: Initializing API keys...")
                    Config.initializeAPIKeys()
                    print("✅ API keys initialized")

                    // Skip force refresh for TestFlight to prevent crashes
                    if !isTestFlightBuild() {
                        print("🔄 CashMonkiApp: Force refreshing API keys (Debug mode)...")
                        Config.forceRefreshOpenRouterKey()
                        Config.forceRefreshRevenueCatKey()
                        print("✅ API keys refreshed")
                    } else {
                        print("✅ TestFlight build detected - skipping API key refresh")
                    }
                    
                    // Pre-initialize RevenueCat early so offerings are ready by the time paywall is needed
                    // This runs during welcome screen, giving plenty of time to load
                    print("💰 CashMonkiApp: Pre-initializing RevenueCat during welcome screen...")
                    initializeRevenueCat()

                    // Initialize PostHog analytics synchronously
                    initializePostHog()

                    // Initialize Mixpanel analytics
                    initializeMixpanel()

                    // Initialize Facebook SDK
                    initializeFacebook()

                    // Debug: Check if custom fonts are loaded
                    #if DEBUG
                    AppFonts.debugAvailableFonts()
                    #endif

                    // Clear notification badge on app launch
                    NotificationManager.shared.clearBadge()

                    // Schedule notifications if toggle is enabled (defaults to true if not set)
                    // Using object(forKey:) to check if explicitly set, otherwise default to true
                    let isRemindEnabled = UserDefaults.standard.object(forKey: "isRemindToTrackEnabled") as? Bool ?? true
                    if isRemindEnabled {
                        NotificationManager.shared.scheduleDailyReminder()
                    }
                }
                .onChange(of: showingWelcome) { oldValue, newValue in
                    print("🎬 CashMonkiApp: Welcome screen state changed from \(oldValue) to \(newValue)")

                    // Initialize Firebase after welcome screen is dismissed
                    // Note: RevenueCat is pre-initialized in onAppear for faster loading
                    if !newValue && oldValue {
                        print("🔥 CashMonkiApp: Welcome screen dismissed - initializing Firebase...")
                        initializeFirebase()

                        // Check for app updates (shows native iOS alert if update required)
                        AppUpdateManager.shared.checkForUpdate()
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
                        
                        // Identify user to RevenueCat and PostHog
                        if let userId = authManager.currentUser?.id.uuidString {
                            Task {
                                await RevenueCatManager.shared.identifyUser(userId: userId)
                            }

                            // Identify user across all analytics services
                            AnalyticsManager.shared.identify(
                                userId: userId,
                                email: authManager.currentUser?.email,
                                name: authManager.currentUser?.name
                            )
                        }
                    } else {
                        print("🔄 CashMonkiApp: User logged out")
                        Task {
                            await RevenueCatManager.shared.logoutUser()
                        }
                        // Reset analytics sessions on logout
                        AnalyticsManager.shared.reset()
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
        print("💰 CashMonkiApp: Initializing RevenueCat in background...")
        // Fire-and-forget - don't block the UI
        Task.detached(priority: .utility) {
            await RevenueCatManager.shared.configureAsync()
            print("✅ CashMonkiApp: RevenueCat initialization complete (background)")
        }
    }

        
    // MARK: - PostHog Initialization

    private func initializePostHog() {
        print("📊 CashMonkiApp: Initializing PostHog...")

        let POSTHOG_API_KEY = "phc_YmNi6WRjwuuMWO1Ghu9tXQZiGdD43Pv9wmcnjSTFvj8"
        let POSTHOG_HOST = "https://us.i.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true

        #if DEBUG
        config.debug = true
        #endif

        PostHogSDK.shared.setup(config)

        // Capture test event and flush immediately
        PostHogSDK.shared.capture("app_launched")
        PostHogSDK.shared.capture("test_event")
        PostHogSDK.shared.flush()

        print("✅ CashMonkiApp: PostHog initialized and test events sent!")
    }

    // MARK: - Facebook SDK Initialization

    private func initializeFacebook() {
        print("📘 CashMonkiApp: Initializing Facebook SDK...")
#if canImport(FacebookCore)
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )

        // Enable automatic app event logging
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true

        // Log a test event to verify connection
        AppEvents.shared.logEvent(AppEvents.Name("app_launched_cashmonki"))
        print("✅ CashMonkiApp: Facebook SDK initialized and test event logged")
#else
        print("⚠️ CashMonkiApp: FacebookCore not available - Facebook SDK not installed")
#endif
    }

    // MARK: - Mixpanel Initialization

    private func initializeMixpanel() {
        print("📊 CashMonkiApp: Initializing Mixpanel...")

        let MIXPANEL_TOKEN = "18a760e415af02efa8e5965fc9831e03"

#if canImport(Mixpanel)
        MixpanelManager.shared.configure(token: MIXPANEL_TOKEN)

        // Track app launch to both PostHog and Mixpanel
        AnalyticsManager.shared.track(.appLaunched)
        AnalyticsManager.shared.flush()

        print("✅ CashMonkiApp: Mixpanel initialized and app_launched tracked!")
#else
        print("⚠️ CashMonkiApp: Mixpanel SDK not available - add Mixpanel package via SPM")
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
    @available(iOS, deprecated: 18.0, message: "Uses legacy receipt URL check")
    private func isTestFlightBuild() -> Bool {
        // Note: appStoreReceiptURL is deprecated in iOS 18 but still functional
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.path.contains("sandboxReceipt")
    }
}
