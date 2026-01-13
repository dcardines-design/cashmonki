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

enum Tab: Hashable { case home, transactions, budgets, settings }

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
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingOnboarding = false
    @State private var observersSetUp = false
    @State private var hasShownTrialEndedToast = false
    @State private var showingTrialEndedPaywall = false

    // Receipt confirmation state (moved here so sheet shows on any tab)
    @State private var showingReceiptConfirmation = false
    @State private var pendingReceiptImage: UIImage?
    @State private var pendingReceiptAnalysis: ReceiptAnalysis?

    // Roast My Receipt feature (moved here so it works from any tab)
    @AppStorage("isRoastReceiptEnabled") private var isRoastReceiptEnabled: Bool = false
    @State private var roastSheetMessage: RoastMessage? = nil

    var body: some View {
        ZStack {
            // Main content area
            VStack(spacing: 0) {
                // Main content area
                ZStack {
                    switch selectedTab {
                    case .home:
                        HomePage(
                            selectedTab: $selectedTab,
                            primaryCurrency: $primaryCurrency,
                            showingReceiptConfirmation: $showingReceiptConfirmation,
                            pendingReceiptImage: $pendingReceiptImage,
                            pendingReceiptAnalysis: $pendingReceiptAnalysis
                        )
                    case .transactions:
                        ReceiptsPage()
                    case .budgets:
                        BudgetsPage()
                    case .settings:
                        SettingsPage(primaryCurrency: $primaryCurrency, selectedTab: $selectedTab)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Custom navigation bar
                customNavigationBar
            }

            // Blur overlay for roast sheet
            if roastSheetMessage != nil {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.05))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: roastSheetMessage != nil)
        .ignoresSafeArea(.container, edges: .bottom)
        .preferredColorScheme(.light) // Force light mode - never change colors for dark mode
        .onAppear {
            Config.initializeAPIKey()
            
            // Initialize currency from user's account settings
            initializePrimaryCurrency()
            
            // Check onboarding status using state manager
            print("🔍 ContentView: onAppear - checking onboarding with state manager")
            checkOnboardingWithStateManager()

            // COMMENTED OUT FOR APP STORE SUBMISSION - TODO: Uncomment later
            // Start recurring transaction timer on initial appear
            // (onChange won't fire on launch since scenePhase is already .active)
            // RecurringTransactionManager.shared.startGenerationTimer()

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
                    print("🎫 ======= SUBSCRIPTION SUCCESS NOTIFICATION =======")
                    print("🎫 SUCCESS: Before - showingTrialEndedPaywall=\(self.showingTrialEndedPaywall), hasShownTrialEndedToast=\(self.hasShownTrialEndedToast)")
                    // Ensure paywall is dismissed and stays dismissed
                    self.showingTrialEndedPaywall = false
                    self.hasShownTrialEndedToast = true // Prevent re-showing
                    print("🎫 SUCCESS: After - showingTrialEndedPaywall=\(self.showingTrialEndedPaywall), hasShownTrialEndedToast=\(self.hasShownTrialEndedToast)")
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

                // Process subscriptions and schedule reminders when app becomes active
                SubscriptionManager.shared.onAppActive()

                // Only check for lapsed paywall if user is NOT a pro subscriber
                // This prevents re-showing paywall when returning from App Store purchase
                print("🎫 SCENE ACTIVE: isProUser=\(revenueCatManager.isProUser), hasShownTrialEndedToast=\(hasShownTrialEndedToast)")
                if !revenueCatManager.isProUser {
                    print("🎫 SCENE ACTIVE: Triggering paywall check...")
                    checkAndShowLapsedUserPaywall()
                } else {
                    print("🎫 SCENE ACTIVE: Skipping - user is Pro")
                }

                // COMMENTED OUT FOR APP STORE SUBMISSION - TODO: Uncomment later
                // Start recurring transaction timer when app becomes active
                // RecurringTransactionManager.shared.startGenerationTimer()
            } else {
                // COMMENTED OUT FOR APP STORE SUBMISSION - TODO: Uncomment later
                // Stop timer when app goes to background
                // RecurringTransactionManager.shared.stopGenerationTimer()
            }
        }
        .onChange(of: revenueCatManager.customerInfo) { oldValue, newValue in
            // When RevenueCat finishes loading customer info, check for lapsed trial
            // Only check on initial load (nil -> non-nil) and only if not already a pro user
            print("🎫 CUSTOMER INFO CHANGED: old=\(oldValue != nil ? "loaded" : "nil"), new=\(newValue != nil ? "loaded" : "nil")")
            print("🎫 CUSTOMER INFO CHANGED: isProUser=\(revenueCatManager.isProUser), hasShownTrialEndedToast=\(hasShownTrialEndedToast)")
            if oldValue == nil && newValue != nil && !revenueCatManager.isProUser {
                print("🎫 CUSTOMER INFO: Triggering paywall check (initial load, not pro)...")
                checkAndShowLapsedUserPaywall()
            } else if oldValue == nil && newValue != nil && revenueCatManager.isProUser {
                print("🎫 CUSTOMER INFO: Skipping - user is now Pro")
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
        .fullScreenCover(isPresented: $showingTrialEndedPaywall) {
            CustomPaywallSheet(isPresented: $showingTrialEndedPaywall)
                .environmentObject(toastManager)
        }
        .sheet(isPresented: $showingReceiptConfirmation) {
            if let image = pendingReceiptImage, let analysis = pendingReceiptAnalysis {
                ReceiptConfirmationSheet(
                    originalImage: image,
                    analysis: analysis,
                    primaryCurrency: primaryCurrency,
                    onConfirm: { confirmedAnalysis, note, isRecurring, recurringFrequency in
                        // DEBUG: Log the date being used for the transaction
                        print("🔴🔴🔴 RECEIPT CONFIRMATION DEBUG 🔴🔴🔴")
                        print("🔴 RECEIPT DATE: Transaction date from receipt: \(confirmedAnalysis.date)")
                        print("🔴 RECEIPT DATE: Today's date: \(Date())")
                        let calendar = Calendar.current
                        let receiptMonth = calendar.component(.month, from: confirmedAnalysis.date)
                        let receiptYear = calendar.component(.year, from: confirmedAnalysis.date)
                        let todayMonth = calendar.component(.month, from: Date())
                        let todayYear = calendar.component(.year, from: Date())
                        print("🔴 RECEIPT DATE: Receipt is from \(receiptMonth)/\(receiptYear), Today is \(todayMonth)/\(todayYear)")
                        if receiptYear != todayYear || receiptMonth != todayMonth {
                            print("⚠️⚠️⚠️ WARNING: Receipt date is NOT in the current month! ⚠️⚠️⚠️")
                            print("⚠️ Transaction will appear in \(receiptMonth)/\(receiptYear), NOT current month!")
                        }

                        // Create transaction from confirmed analysis with currency conversion
                        let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: confirmedAnalysis.category)
                        let categoryId = categoryResult.category?.id ?? categoryResult.subcategory?.id

                        // Determine if this is income based on category type
                        let isIncome = categoryResult.category?.type == .income || categoryResult.subcategory?.type == .income

                        // Use selected wallet, fallback to default account, then first account
                        let walletID = AccountManager.shared.selectedSubAccountId
                            ?? userManager.currentUser.defaultSubAccount?.id
                            ?? userManager.currentUser.subAccounts.first?.id

                        print("📸 Receipt: Using walletID: \(walletID?.uuidString.prefix(8) ?? "NIL - WILL CAUSE DISPLAY ISSUE")")

                        let baseTransaction = CurrencyRateManager.shared.createTransaction(
                            accountID: userManager.currentUser.id,
                            walletID: walletID,
                            category: confirmedAnalysis.category,
                            categoryId: categoryId,
                            originalAmount: confirmedAnalysis.totalAmount,
                            originalCurrency: confirmedAnalysis.currency,
                            date: confirmedAnalysis.date,
                            merchantName: confirmedAnalysis.merchantName,
                            note: note,
                            items: confirmedAnalysis.items,
                            isIncome: isIncome,
                            receiptImage: image
                        )

                        // Create final transaction with recurring fields
                        let confirmedTransaction = Txn(
                            txID: baseTransaction.txID,
                            accountID: baseTransaction.accountID,
                            walletID: baseTransaction.walletID,
                            category: baseTransaction.category,
                            categoryId: baseTransaction.categoryId,
                            amount: baseTransaction.amount,
                            date: baseTransaction.date,
                            createdAt: baseTransaction.createdAt,
                            receiptImage: baseTransaction.receiptImage,
                            hasReceiptImage: baseTransaction.hasReceiptImage,
                            merchantName: baseTransaction.merchantName,
                            paymentMethod: baseTransaction.paymentMethod,
                            receiptNumber: baseTransaction.receiptNumber,
                            invoiceNumber: baseTransaction.invoiceNumber,
                            items: baseTransaction.items,
                            note: baseTransaction.note,
                            originalAmount: baseTransaction.originalAmount,
                            originalCurrency: baseTransaction.originalCurrency,
                            primaryCurrency: baseTransaction.primaryCurrency,
                            secondaryCurrency: baseTransaction.secondaryCurrency,
                            exchangeRate: baseTransaction.exchangeRate,
                            secondaryAmount: baseTransaction.secondaryAmount,
                            secondaryExchangeRate: baseTransaction.secondaryExchangeRate,
                            userEnteredAmount: baseTransaction.userEnteredAmount,
                            userEnteredCurrency: baseTransaction.userEnteredCurrency,
                            // Recurring fields
                            isRecurring: isRecurring,
                            recurringFrequency: recurringFrequency,
                            recurringTemplateId: nil,
                            lastGeneratedDate: nil,
                            isRecurringActive: isRecurring
                        )

                        // Add transaction
                        userManager.addTransaction(confirmedTransaction)

                        // Migrate any orphaned transactions immediately (fixes nil walletID issues)
                        AccountManager.shared.migrateOrphanedTransactionsAtStartup()

                        // Cancel today's reminder since user tracked
                        NotificationManager.shared.onTransactionAdded()

                        // Show success toast
                        toastManager.showSuccess("Transaction added!")

                        // Prepare roast data before clearing
                        let shouldShowRoast = isRoastReceiptEnabled
                        let roastAmount = CurrencyPreferences.shared.formatPrimaryAmount(abs(confirmedTransaction.amount))
                        let roastMerchant = confirmedAnalysis.merchantName
                        let roastCategory = confirmedAnalysis.category
                        let roastNotes = confirmedTransaction.note
                        let roastUserName = UserManager.shared.currentUser.name
                        let roastLineItems: [[String: Any]] = confirmedAnalysis.items.map { item in
                            ["description": item.description, "quantity": item.quantity]
                        }

                        // Clear pending data
                        pendingReceiptImage = nil
                        pendingReceiptAnalysis = nil
                        showingReceiptConfirmation = false

                        // Trigger roast if enabled
                        if shouldShowRoast {
                            Task {
                                do {
                                    let aiRoast = try await BackendAPIService.shared.generateRoast(
                                        amount: roastAmount,
                                        merchant: roastMerchant,
                                        category: roastCategory,
                                        notes: roastNotes,
                                        lineItems: roastLineItems,
                                        userName: roastUserName,
                                        currency: CurrencyPreferences.shared.primaryCurrency.rawValue
                                    )
                                    await MainActor.run {
                                        roastSheetMessage = RoastMessage(message: aiRoast)
                                        // Track roast message triggered
                                        AnalyticsManager.shared.track(.roastMessageTriggered, properties: [
                                            "merchant": roastMerchant,
                                            "category": roastCategory,
                                            "currency": CurrencyPreferences.shared.primaryCurrency.rawValue,
                                            "success": true
                                        ])
                                    }
                                } catch let backendError as BackendAPIError {
                                    print("❌ ROAST FAILED - BackendAPIError: \(backendError.localizedDescription)")
                                    switch backendError {
                                    case .unauthorized:
                                        print("   → Auth issue: Firebase token may be missing or invalid")
                                    case .rateLimited:
                                        print("   → Rate limited: Too many requests")
                                    case .serverError:
                                        print("   → Server error: Backend returned 500+")
                                    case .invalidResponse:
                                        print("   → Invalid response: Could not parse backend response")
                                    case .unexpectedError(let code):
                                        print("   → Unexpected HTTP status: \(code)")
                                    default:
                                        print("   → Other backend error: \(backendError)")
                                    }
                                    await MainActor.run {
                                        roastSheetMessage = RoastMessage(message: "Spent \(roastAmount) at \(roastMerchant)? Bold choice. 💸")
                                    }
                                } catch {
                                    print("❌ ROAST FAILED - Unknown error: \(error)")
                                    print("   → Error type: \(type(of: error))")
                                    print("   → Description: \(error.localizedDescription)")
                                    await MainActor.run {
                                        roastSheetMessage = RoastMessage(message: "Spent \(roastAmount) at \(roastMerchant)? Bold choice. 💸")
                                    }
                                }
                            }
                        }
                    },
                    onCancel: {
                        pendingReceiptImage = nil
                        pendingReceiptAnalysis = nil
                        showingReceiptConfirmation = false
                    }
                )
                .presentationDetents([.fraction(0.98)])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.hidden)
                .environmentObject(toastManager)
            }
        }
        .sheet(item: $roastSheetMessage) { roast in
            RoastReceiptSheet(isPresented: Binding(
                get: { roastSheetMessage != nil },
                set: { if !$0 { roastSheetMessage = nil } }
            ), roastMessage: roast.message)
                // Start at 75%, can expand to 98%
                .presentationDetents([.fraction(0.75), .fraction(0.98)], selection: .constant(.fraction(0.75)))
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
                .presentationBackgroundInteraction(.disabled)
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

        // CURRENT: No-auth flow - skip Firebase auth check
        // FUTURE: Uncomment when re-enabling authentication
        /*
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
        */

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

    // MARK: - Lapsed User Paywall

    private func checkAndShowLapsedUserPaywall() {
        print("🎫 ======= checkAndShowLapsedUserPaywall CALLED =======")
        print("🎫 CHECK: hasShownTrialEndedToast=\(hasShownTrialEndedToast)")
        print("🎫 CHECK: showingTrialEndedPaywall=\(showingTrialEndedPaywall)")
        print("🎫 CHECK: isProUser=\(revenueCatManager.isProUser)")
        print("🎫 CHECK: hasUsedTrialBefore=\(revenueCatManager.hasUsedTrialBefore)")
        print("🎫 CHECK: isPurchaseInProgress=\(revenueCatManager.isPurchaseInProgress)")

        // Multiple guards to prevent re-showing paywall after subscription
        guard !hasShownTrialEndedToast else {
            print("🎫 ContentView: ❌ Skipping - already shown this session")
            return
        }

        // Don't show if paywall is already showing
        guard !showingTrialEndedPaywall else {
            print("🎫 ContentView: ❌ Skipping - paywall already visible")
            return
        }

        // CRITICAL: Don't show paywall while a purchase is in progress
        guard !revenueCatManager.isPurchaseInProgress else {
            print("🎫 ContentView: ❌ Skipping - purchase in progress")
            return
        }

        // CRITICAL: Check isProUser immediately - don't show paywall to subscribers
        guard !revenueCatManager.isProUser else {
            print("🎫 ContentView: ❌ Skipping - user is Pro")
            hasShownTrialEndedToast = true // Prevent future checks this session
            return
        }

        print("🎫 CHECK: All guards passed, running background check...")

        // Run check in background to avoid blocking UI
        Task {
            // Small delay to ensure RevenueCat has loaded
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            await MainActor.run {
                print("🎫 ASYNC CHECK: hasShownTrialEndedToast=\(hasShownTrialEndedToast)")
                print("🎫 ASYNC CHECK: showingTrialEndedPaywall=\(showingTrialEndedPaywall)")
                print("🎫 ASYNC CHECK: isProUser=\(revenueCatManager.isProUser)")
                print("🎫 ASYNC CHECK: isPurchaseInProgress=\(revenueCatManager.isPurchaseInProgress)")

                // Double-check guards after delay (state may have changed)
                guard !hasShownTrialEndedToast else {
                    print("🎫 ASYNC: ❌ Skipping - already shown")
                    return
                }
                guard !showingTrialEndedPaywall else {
                    print("🎫 ASYNC: ❌ Skipping - already visible")
                    return
                }
                guard !revenueCatManager.isPurchaseInProgress else {
                    print("🎫 ASYNC: ❌ Skipping - purchase in progress")
                    return
                }
                guard !revenueCatManager.isProUser else {
                    print("🎫 ASYNC: ❌ Skipping - user became Pro")
                    hasShownTrialEndedToast = true
                    return
                }

                let hasUsedTrial = RevenueCatManager.shared.hasUsedTrialBefore
                print("🎫 ASYNC CHECK: hasUsedTrial=\(hasUsedTrial)")

                if hasUsedTrial {
                    print("🎫 ContentView: ✅ SHOWING PAYWALL - lapsed trial user")
                    hasShownTrialEndedToast = true
                    showingTrialEndedPaywall = true
                } else {
                    print("🎫 ContentView: ❌ Not showing - user hasn't used trial")
                }
            }
        }
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

            // Budgets tab
            Button(action: { selectedTab = .budgets }) {
                VStack(spacing: 2) {
                    Image("horizontal-bar-chart-03")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(selectedTab == .budgets ? AppColors.primary : AppColors.foregroundTertiary)
                    Text("Budgets")
                        .font(
                            Font.custom("Overused Grotesk", size: 11)
                                .weight(.semibold)
                        )
                        .foregroundColor(selectedTab == .budgets ? AppColors.primary : AppColors.foregroundTertiary)
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
