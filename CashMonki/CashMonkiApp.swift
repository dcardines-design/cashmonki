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
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
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

    init() {
        #if DEBUG
        // TEMPORARY recovery tool (2026-07-08 data-loss incident). READ-ONLY:
        // reads UserDefaults user-storage keys, copies raw bytes to new
        // Documents/RECOVERY_*.json files, prints them. Writes nothing over
        // existing data. Runs at the earliest launch point, before any load/save.
        // Remove after recovery.
        // Disabled: one-off 2026-07-08 recovery tools. They re-ran every launch, dumped ~530KB to
        // the console (drowning real logs), and are no longer needed.
        // CashMonkiApp.dumpUserStorageForRecovery()
        // CashMonkiApp.restoreDanteData()
        #endif
    }

    #if DEBUG
    // TEMPORARY one-shot restore (2026-07-08 incident). Copies Dante's intact
    // blob into the currently-active guest key so the app loads it. Runs ONCE
    // (guarded by a flag). Source blob left untouched as a safety copy; current
    // guest key backed up before overwrite. Remove after recovery confirmed.
    private static func restoreDanteData() {
        let d = UserDefaults.standard
        let doneFlag = "didRestoreDante_v2_20260713"
        if d.bool(forKey: doneFlag) {
            print("🧯 RESTORE v2: already ran, skipping")
            return
        }
        // NON-DESTRUCTIVE. The real data blob still exists in UserDefaults; the app
        // just loads the wrong (empty guest) key because last_authenticated_firebase_uid
        // points at it. Auto-detect the real blob = the LARGEST currentUser_firebase_*
        // blob (Dante's ~1.5MB vs empty guests ~1.3KB) and repoint the session pointer
        // at it. Writes NO user blob — nothing is overwritten, fully reversible.
        let prefix = "currentUser_firebase_"
        let keys = d.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(prefix) && !$0.hasSuffix("_preRestoreBackup")
        }
        var bestKey: String?
        var bestSize = 0
        for k in keys {
            if let data = d.data(forKey: k), data.count > bestSize {
                bestSize = data.count
                bestKey = k
            }
        }
        guard let sourceKey = bestKey else {
            print("🧯 RESTORE v2: no user blobs found — ABORT, nothing changed")
            return
        }
        let sourceUID = String(sourceKey.dropFirst(prefix.count))
        let currentPointer = d.string(forKey: "last_authenticated_firebase_uid")
        print("🧯 RESTORE v2: real-data blob = \(sourceKey) (\(bestSize) bytes)")
        print("🧯 RESTORE v2: current pointer last_authenticated_firebase_uid = \(String(describing: currentPointer))")
        if currentPointer == sourceUID {
            print("🧯 RESTORE v2: pointer already at real blob — nothing to do")
            d.set(true, forKey: doneFlag)
            return
        }
        // Repoint session at the real blob. Guest mode sets no currentUser, so the
        // load path keys off last_authenticated_firebase_uid.
        d.set(sourceUID, forKey: "last_authenticated_firebase_uid")
        d.set(true, forKey: doneFlag)
        print("🧯 RESTORE v2: repointed last_authenticated_firebase_uid = \(sourceUID). Source untouched. Relaunch to load real data.")
    }

    private static func dumpUserStorageForRecovery() {
        let defaults = UserDefaults.standard
        let all = defaults.dictionaryRepresentation()
        let keys = all.keys.filter {
            $0.hasPrefix("currentUser") || $0 == "userData" || $0.hasPrefix("user_")
        }.sorted()
        print("🧯 RECOVERY DUMP START — \(keys.count) candidate storage keys")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for k in keys {
            if let data = defaults.data(forKey: k) {
                let str = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
                print("🧯 KEY \(k) — \(data.count) bytes:\n\(str)\n🧯 END \(k)")
                let safe = k.replacingOccurrences(of: "/", with: "_")
                try? data.write(to: docs.appendingPathComponent("RECOVERY_\(safe).json"))
            } else {
                print("🧯 KEY \(k) — non-data value: \(String(describing: all[k]))")
            }
        }
        for p in ["currentUserId", "currentUserName", "currentUserEmail", "last_authenticated_firebase_uid"] {
            print("🧯 SESSION \(p) = \(String(describing: defaults.object(forKey: p)))")
        }
        print("🧯 RECOVERY DUMP COMPLETE — files saved to Documents/RECOVERY_*.json")
    }
    #endif

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
                        // Auth-first flow: require login OR an explicit "continue as guest".
                        // Anonymous sessions alone do NOT pass (see AuthenticationManager) - the
                        // gate shows the login screen until the user signs in or taps guest.
                        // Guest keeps the app usable without an account (App Store 5.1.1(v)).
                        if authManager.isAuthenticated || authManager.isGuestMode {
                            ContentView()
                                .environmentObject(toastManager)
                                .preferredColorScheme(.light)
                                .fullScreenCover(isPresented: $showingOnboarding) {
                                    OnboardingFlow(
                                        isPresented: $showingOnboarding,
                                        onComplete: {
                                            print("🎉 CashMonkiApp: ======= ONBOARDING COMPLETION CALLBACK =======")
                                            // Paywall is shown directly from OnboardingFlow
                                            showingOnboarding = false
                                            isNewUser = false
                                            authManager.isNewRegistration = false
                                            print("✅ CashMonkiApp: Onboarding dismissed")
                                        },
                                        onBack: {
                                            // Back on onboarding = log out, return to login screen.
                                            authManager.logout()
                                            showingOnboarding = false
                                            isNewUser = false
                                        },
                                        userEmail: authManager.currentUser?.email,
                                        isNewRegistration: authManager.isNewRegistration,
                                        forceStartStep: nil
                                    )
                                    .environmentObject(toastManager)
                                }
                                .onAppear {
                                    // Check if onboarding needs to be shown. Local-first restore
                                    // usually has the real progress here already.
                                    if !OnboardingStateManager.shared.isOnboardingComplete() {
                                        showingOnboarding = true
                                    }
                                }
                                .onReceive(NotificationCenter.default.publisher(
                                    for: NSNotification.Name("UserManagerFirebaseLoadComplete"))
                                ) { _ in
                                    // Restore finished (local or async cloud). If the logged-in user
                                    // already completed onboarding, dismiss it. Fixes returning users
                                    // seeing onboarding again because onAppear ran before their saved
                                    // progress loaded.
                                    if OnboardingStateManager.shared.isOnboardingComplete() {
                                        showingOnboarding = false
                                    }
                                }
                        } else {
                            AuthenticationView()
                                .preferredColorScheme(.light)
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
                        
                        // Identify user to RevenueCat and PostHog.
                        // MUST use the stable Firebase UID — currentUser.id is a fresh random
                        // UUID each launch, which made RevenueCat mint a new anonymous user
                        // daily and drop the user's entitlement (subscription "reset" every day).
                        if let userId = authManager.currentUser?.firebaseUID, !userId.isEmpty {
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
            #if canImport(FirebaseAppCheck)
            // App Check (App Attest) — must be set BEFORE configure().
            // Requires the FirebaseAppCheck package product on the target and
            // the app registered under Firebase console → App Check.
            AppCheck.setAppCheckProviderFactory(CashMonkiAppCheckProviderFactory())
            #endif
            FirebaseApp.configure()
            print("✅ Firebase configured successfully")

            // Firestore offline persistence (source-of-truth migration). GATED behind the feature
            // flag so the DEFAULT build behaves exactly as before — no Firestore behavior change,
            // no launch-path risk — until we explicitly opt in. Only when the flag is on do we
            // configure persistence + register the read layer.
            #if canImport(FirebaseFirestore)
            if FeatureFlags.firestoreSourceOfTruth {
                let fsSettings = FirestoreSettings()
                fsSettings.cacheSettings = PersistentCacheSettings(sizeBytes: FirestoreCacheSizeUnlimited as NSNumber)
                Firestore.firestore().settings = fsSettings
                _ = FirestoreStore.shared
                print("✅ Firestore offline persistence enabled (unlimited cache)")
            }
            #endif

            #if canImport(FirebaseAuth)
            // Anonymous session so Firestore rules can require request.auth.
            // Upgraded in place if the user later signs in properly.
            if Auth.auth().currentUser == nil {
                Auth.auth().signInAnonymously { result, error in
                    if let error {
                        print("🔐 Anonymous sign-in failed: \(error.localizedDescription)")
                    } else {
                        print("🔐 Anonymous session ready: \(result?.user.uid.prefix(8) ?? "")")
                    }
                }
            }
            #endif

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


#if canImport(FirebaseAppCheck)
/// App Attest on device, debug provider in the simulator.
final class CashMonkiAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
#endif
