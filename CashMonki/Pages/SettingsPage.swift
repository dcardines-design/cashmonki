//
//  SettingsPage.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI
import StoreKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsPage: View {
    @Binding var primaryCurrency: Currency
    @Binding var selectedTab: Tab
    // COMMENTED OUT: Language picker (localization not yet implemented)
    // @State private var selectedLanguage: Language = .english
    // @State private var showingLanguagePicker = false
    @State private var showingCurrencyPicker = false
    @State private var showingSecondaryCurrencyPicker = false
    @State private var showingResetCategoriesConfirmation = false
    @State private var showingEditNameSheet = false
    @State private var showingEditCategoriesSheet = false
    @State private var showingNativePaywall = false
    @State private var showingEntitlementPaywall = false
    @State private var showingCustomPaywall = false
    @ObservedObject private var rateManager = CurrencyRateManager.shared
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @ObservedObject private var categoriesManager = CategoriesManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @ObservedObject private var dailyUsageManager = DailyUsageManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    
    // Button state tracking
    @State private var pressedButton: String? = nil
    
    // Tab state tracking
    @State private var selectedSingleTab = 0
    @State private var selectedGroupTab = 1
    @State private var selectedPeriodTab = 2
    
    // Input field state tracking
    @State private var sampleText = ""
    @State private var sampleAmount = ""
    @State private var sampleMerchant = ""
    @State private var sampleSearch = ""
    @State private var sampleDate = Date()
    @State private var sampleCurrency = CurrencyPreferences.shared.primarySymbol
    
    // API testing state
    @State private var isTestingAPI = false
    @State private var apiTestResult: String?
    
    // Environment testing state
    @State private var isTestingEnvironment = false
    @State private var environmentTestResult: String?
    
    // Firebase pull data state
    @State private var isPullingData = false
    @State private var pullDataResult: String?
    @State private var showingPullDataConfirmation = false
    
    // Firebase delete data state
    @State private var isDeletingAllTransactions = false
    @State private var showingDeleteAllConfirmation = false
    @State private var deleteAllResult: String?
    
    // Logout confirmation state
    @State private var showingLogoutConfirmation = false

    // Delete account state
    @State private var showingDeleteAccountSheet = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var accountDeletionError: String?
    @State private var showingReauthenticationAlert = false
    
    // Onboarding debug state
    @State private var showingDebugOnboarding = false
    @State private var debugOnboardingStartStep: OnboardingStep = .emailConfirmation
    @State private var showingGoalsOnboarding = false
    @State private var showingTransactionOnboarding = false
    
    // Billing management state
    @State private var showingManageBilling = false
    
    // Currency change confirmation state
    @State private var showingCurrencyChangeConfirmation = false
    @State private var showingSupportOptions = false
    @State private var pendingCurrencyChange: Currency?
    
    // Roast My Receipt feature toggle (shared via AppStorage)
    @AppStorage("isRoastReceiptEnabled") private var isRoastReceiptEnabled = false

    // Secret version tap state (7 taps = toggle internal device mode)
    @State private var versionTapCount = 0
    @State private var versionTapTimer: Timer?
    @State private var isInternalDevice = AnalyticsManager.shared.isInternalDevice

    // Computed bindings to fix type checker issues
    private var primaryCurrencyBinding: Binding<Currency> {
        Binding(
            get: { primaryCurrency },
            set: { newCurrency in
                handlePrimaryCurrencyChange(newCurrency)
            }
        )
    }
    
    private func handleSecondaryCurrencyChange(_ newCurrency: Currency?) {
        if let currency = newCurrency {
            print("💱 SettingsPage: Updating secondary currency to: \(currency.rawValue)")
        } else {
            print("💱 SettingsPage: Removing secondary currency (set to none)")
        }
        currencyPrefs.setSecondaryCurrency(newCurrency)
        rateManager.setSecondaryCurrency(newCurrency)
    }

    // MARK: - Secret Version Tap Handler

    private func handleVersionTap() {
        // Cancel existing timer
        versionTapTimer?.invalidate()

        // Increment tap count
        versionTapCount += 1
        print("🔧 Version tap: \(versionTapCount)/7")

        // Check if we hit 7 taps
        if versionTapCount >= 7 {
            // Toggle internal device mode
            if isInternalDevice {
                AnalyticsManager.shared.unmarkAsInternalDevice()
                isInternalDevice = false
                print("🔧 Internal device mode: DISABLED")
            } else {
                AnalyticsManager.shared.markAsInternalDevice()
                isInternalDevice = true
                print("🔧 Internal device mode: ENABLED")
            }

            // Reset counter
            versionTapCount = 0

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            // Light haptic for each tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Reset counter after 2 seconds of no taps
            versionTapTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.versionTapCount = 0
                }
            }
        }
    }

    private var secondaryCurrencyOptionalBinding: Binding<Currency?> {
        Binding(
            get: { currencyPrefs.secondaryCurrency },
            set: { newCurrency in
                handleSecondaryCurrencyChange(newCurrency)
            }
        )
    }
    

    var body: some View {
        ZStack {
            contentWithSheets
            
            // Background blur with fade in/out animation
            Rectangle()
                .foregroundColor(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.97))
                .blur(radius: 25)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(0)
                .animation(.easeOut(duration: 0.3), value: false)
        }
    }
    
    private var baseViewWithSheets: some View {
        settingsMainView
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerSheet(
                    primaryCurrency: primaryCurrencyBinding,
                    isPresented: $showingCurrencyPicker
                )
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showingSecondaryCurrencyPicker) {
                SecondaryCurrencyPickerSheet(
                    secondaryCurrency: secondaryCurrencyOptionalBinding,
                    isPresented: $showingSecondaryCurrencyPicker
                )
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
            }
            // COMMENTED OUT: Language picker (localization not yet implemented)
            // .sheet(isPresented: $showingLanguagePicker) {
            //     LanguagePickerSheet(
            //         selectedLanguage: $selectedLanguage,
            //         isPresented: $showingLanguagePicker
            //     )
            //     .presentationDetents([.fraction(0.98)])
            //     .presentationDragIndicator(.hidden)
            // }
            .sheet(isPresented: $showingEditNameSheet) {
                EditNameSheet(isPresented: $showingEditNameSheet)
                    .environmentObject(toastManager)
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showingEditCategoriesSheet) {
                EditCategoriesSheet(isPresented: $showingEditCategoriesSheet)
                .presentationDetents([.fraction(0.98)])
                .presentationDragIndicator(.hidden)
            }
            .alert("Delete Everything?", isPresented: $showingDeleteAccountSheet) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    .autocapitalization(.allCharacters)
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button("Delete", role: .destructive) {
                    if deleteConfirmationText.uppercased() == "DELETE" {
                        deleteConfirmationText = ""
                        deleteAccount()
                    }
                }
                .disabled(deleteConfirmationText.uppercased() != "DELETE")
            } message: {
                Text("This will permanently delete all your data. Type DELETE to confirm.\n\nNote: This does not cancel your subscription. To cancel, go to Settings → Manage Billing → Manage Subscription.")
            }
            .confirmationDialog("Customer Support", isPresented: $showingSupportOptions, titleVisibility: .visible) {
                Button("Send Email") {
                    openSupportEmail()
                }
                Button("Chat in X (Twitter)") {
                    openTwitterSupport()
                }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showingCustomPaywall) {
                CustomPaywallSheet(isPresented: $showingCustomPaywall)
                    .environmentObject(toastManager)
            }
            .fullScreenCover(isPresented: $showingManageBilling) {
                ManageBillingSheet(isPresented: $showingManageBilling)
                    .environmentObject(toastManager)
            }
            .fullScreenCover(isPresented: $showingNativePaywall) {
                #if canImport(RevenueCatUI)
                Group {
                    let _ = print("✅ PAYWALL DEBUG: RevenueCatUI is available")
                    if let targetOffering = revenueCatManager.targetOffering {
                        // Use YOUR RevenueCat dashboard paywall with target offering
                        PaywallView(offering: targetOffering)
                            .environmentObject(toastManager)
                            .onPurchaseCompleted { customerInfo in
                                print("🎉 PAYWALL: Purchase completed successfully!")
                                showingNativePaywall = false
                                
                                // Show success toast
                                DispatchQueue.main.async {
                                    toastManager.showDone("Done analyzing!")
                                }
                                
                                // Update RevenueCat manager
                                revenueCatManager.customerInfo = customerInfo
                            }
                            .onRestoreCompleted { customerInfo in
                                print("🔄 PAYWALL: Purchases restored successfully!")
                                showingNativePaywall = false
                                
                                // Show restore success toast
                                DispatchQueue.main.async {
                                    toastManager.showSuccess("✅ Purchases restored successfully!")
                                }
                                
                                // Update RevenueCat manager
                                revenueCatManager.customerInfo = customerInfo
                            }
                            .onPurchaseFailure { error in
                                print("❌ PAYWALL: Purchase failed: \(error.localizedDescription)")
                                print("🚨 SUBSCRIPTION ERROR DEBUG: Target offering paywall failure triggered")
                                print("🚨 ERROR DETAILS: \(error)")
                                print("🚨 ERROR CODE: \((error as NSError).code)")
                                print("🚨 ERROR DOMAIN: \((error as NSError).domain)")
                                // Don't dismiss paywall on failure, let user retry
                                
                                // Show error toast
                                DispatchQueue.main.async {
                                    print("🍞 TOAST DEBUG: About to show subscription error toast (Target Offering)")
                                    toastManager.showFailed("Try again later maybe!")
                                    print("🍞 TOAST DEBUG: Subscription error toast command sent successfully")
                                }
                            }
                            .onAppear {
                                print("✅ PAYWALL: Using target offering '\(targetOffering.identifier)'")
                                print("🛡️ PAYWALL DEBUG: Target offering paywall appeared - ready for subscription attempts")
                            }
                    } else if let offerings = revenueCatManager.offerings, let firstOffering = offerings.all.first?.value {
                        // Fallback to first available offering
                        PaywallView(offering: firstOffering)
                            .environmentObject(toastManager)
                            .onPurchaseCompleted { customerInfo in
                                print("🎉 PAYWALL: Purchase completed successfully!")
                                showingNativePaywall = false
                                
                                // Show success toast
                                DispatchQueue.main.async {
                                    toastManager.showDone("Done analyzing!")
                                }
                                
                                // Update RevenueCat manager
                                revenueCatManager.customerInfo = customerInfo
                            }
                            .onRestoreCompleted { customerInfo in
                                print("🔄 PAYWALL: Purchases restored successfully!")
                                showingNativePaywall = false
                                
                                // Show restore success toast
                                DispatchQueue.main.async {
                                    toastManager.showSuccess("✅ Purchases restored successfully!")
                                }
                                
                                // Update RevenueCat manager
                                revenueCatManager.customerInfo = customerInfo
                            }
                            .onPurchaseFailure { error in
                                print("❌ PAYWALL: Purchase failed: \(error.localizedDescription)")
                                // Don't dismiss paywall on failure, let user retry
                                
                                // Show error toast
                                DispatchQueue.main.async {
                                    print("🍞 DEBUG: About to show error toast for purchase failure")
                                    toastManager.showFailed("Try again later maybe!")
                                    print("🍞 DEBUG: Error toast command sent")
                                }
                            }
                            .onAppear {
                                print("⚠️ PAYWALL FALLBACK: Using first available offering '\(firstOffering.identifier)' instead of target")
                            }
                    } else if let offerings = revenueCatManager.offerings, let currentOffering = offerings.current {
                        // Fallback to current offering
                        PaywallView(offering: currentOffering)
                            .environmentObject(toastManager)
                            .onPurchaseCompleted { customerInfo in
                                print("🎉 PAYWALL: Purchase completed successfully!")
                                showingNativePaywall = false
                                
                                // Show success toast
                                DispatchQueue.main.async {
                                    toastManager.showDone("Done analyzing!")
                                }
                                
                                // Update RevenueCat manager
                                revenueCatManager.customerInfo = customerInfo
                            }
                            .onRestoreCompleted { customerInfo in
                                print("🔄 PAYWALL: Purchases restored successfully!")
                                showingNativePaywall = false
                                
                                // Show restore success toast
                                DispatchQueue.main.async {
                                    toastManager.showSuccess("✅ Purchases restored successfully!")
                                }
                                
                                // Update RevenueCat manager
                                revenueCatManager.customerInfo = customerInfo
                            }
                            .onPurchaseFailure { error in
                                print("❌ PAYWALL: Purchase failed: \(error.localizedDescription)")
                                // Don't dismiss paywall on failure, let user retry
                                
                                // Show error toast
                                DispatchQueue.main.async {
                                    print("🍞 DEBUG: About to show error toast for purchase failure")
                                    toastManager.showFailed("Try again later maybe!")
                                    print("🍞 DEBUG: Error toast command sent")
                                }
                            }
                            .onAppear {
                                print("⚠️ PAYWALL FALLBACK: Using current offering '\(currentOffering.identifier)' instead of target")
                            }
                    } else {
                        // Show error only if absolutely no offerings are available
                        VStack(spacing: 20) {
                            Text("❌ Paywall Error")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text("Unable to load subscription options")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Debug Info:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("• Offerings count: \(revenueCatManager.offerings?.all.count ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• Available IDs: \(revenueCatManager.debugAvailableOfferingIds.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            Button("Retry Loading") {
                                Task {
                                    await revenueCatManager.loadOfferings()
                                }
                            }
                            .foregroundColor(.blue)
                            
                            Button("Cancel") {
                                showingNativePaywall = false
                            }
                            .foregroundColor(.red)
                        }
                        .padding()
                    }
                }
                .onPurchaseCompleted { customerInfo in
                    print("✅ PAYWALL: Purchase completed: \(customerInfo.entitlements)")
                    showingNativePaywall = false
                    
                    // Show success toast
                    DispatchQueue.main.async {
                        toastManager.showDone("Done analyzing!")
                    }
                    
                    // Update RevenueCat manager
                    revenueCatManager.customerInfo = customerInfo
                }
                .onPurchaseFailure { error in
                    print("❌ PAYWALL: Purchase failed: \(error.localizedDescription)")
                    print("🚨 SUBSCRIPTION ERROR DEBUG: MAIN PAYWALL failure triggered - THIS IS THE LIKELY HANDLER!")
                    print("🚨 ERROR DETAILS: \(error)")
                    print("🚨 ERROR CODE: \((error as NSError).code)")
                    print("🚨 ERROR DOMAIN: \((error as NSError).domain)")
                    print("🚨 ERROR USER INFO: \((error as NSError).userInfo)")
                    // Don't dismiss paywall on failure, let user retry
                    
                    // Show error toast
                    DispatchQueue.main.async {
                        print("🍞 TOAST DEBUG: About to show subscription error toast (MAIN PAYWALL - MOST LIKELY TO FIRE)")
                        toastManager.showError("Something went wrong")
                        print("🍞 TOAST DEBUG: Subscription error toast command sent successfully (MAIN)")
                        
                        // Additional verification
                        print("🍞 TOAST VERIFICATION: Toast manager type: \(type(of: toastManager))")
                        print("🍞 TOAST VERIFICATION: Currently on main thread: \(Thread.isMainThread)")
                    }
                }
                .onRestoreCompleted { customerInfo in
                    print("✅ PAYWALL: Purchases restored: \(customerInfo.entitlements)")
                    showingNativePaywall = false
                }
                .onRequestedDismissal {
                    print("👋 PAYWALL: User dismissed paywall")
                    showingNativePaywall = false
                }
                .environmentObject(toastManager)
                #else
                let _ = print("❌ PAYWALL DEBUG: RevenueCatUI NOT AVAILABLE - This is why you see 'not available'")
                Text("RevenueCat Paywall Not Available")
                    .foregroundColor(.red)
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresentNativePaywall"))) { _ in
                showingNativePaywall = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowRevenueCatError"))) { notification in
                if let errorMessage = notification.object as? String {
                    print("❌ SETTINGS: RevenueCat error received: \(errorMessage)")
                    // Show error to user via existing toast system
                    DispatchQueue.main.async {
                        // Use the existing toast notification system
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowErrorToast"),
                            object: "Premium Features Unavailable: \(errorMessage)"
                        )
                    }
                }
            }
            // Removed presentPaywallIfNeeded due to API compatibility issues
            .onChange(of: showingEntitlementPaywall) { oldValue, newValue in
                print("🔍 PAYWALL DEBUG: showingEntitlementPaywall changed to: \(newValue)")
                if newValue {
                    print("🔍 PAYWALL DEBUG: Checking if user has 'cashmonki-subs' entitlement...")
                    print("🔍 PAYWALL DEBUG: Current subscription status: \(revenueCatManager.isSubscriptionActive)")
                    if let customerInfo = revenueCatManager.customerInfo {
                        print("🔍 PAYWALL DEBUG: Available entitlements: \(customerInfo.entitlements.all.keys)")
                        if let entitlement = customerInfo.entitlements["cashmonki-subs"] {
                            print("🔍 PAYWALL DEBUG: 'cashmonki-subs' entitlement found - active: \(entitlement.isActive)")
                        } else {
                            print("🔍 PAYWALL DEBUG: 'cashmonki-subs' entitlement NOT found - paywall should appear")
                        }
                    } else {
                        print("🔍 PAYWALL DEBUG: No customer info available")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingDebugOnboarding) {
                OnboardingFlow(
                    isPresented: $showingDebugOnboarding,
                    onComplete: debugOnboardingComplete,
                    onBack: debugOnboardingCancel,
                    userEmail: authManager.currentUser?.email,
                    isNewRegistration: false,
                    forceStartStep: debugOnboardingStartStep
                )
            }
            .fullScreenCover(isPresented: $showingGoalsOnboarding) {
                GoalsOnboardingView(
                    isPresented: $showingGoalsOnboarding,
                    onGoalSelected: { goal in
                        print("🎯 Settings Preview: Goal selected: \(goal)")
                        showingGoalsOnboarding = false
                    },
                    onBack: {
                        showingGoalsOnboarding = false
                    }
                )
            }
            .slideInSheet(isPresented: $showingTransactionOnboarding) {
                OnboardingTransactionSheet(
                    isPresented: $showingTransactionOnboarding,
                    onComplete: {
                        print("💰 Settings: Transaction onboarding completed")
                        showingTransactionOnboarding = false
                    },
                    onBack: {
                        print("💰 Settings: Transaction onboarding dismissed via back button")
                        showingTransactionOnboarding = false
                    }
                )
                .environmentObject(toastManager)
            }
    }
    
    private func debugOnboardingComplete() {
        showingDebugOnboarding = false
        print("🐛 Debug: Onboarding flow completed")
    }
    
    private func debugOnboardingCancel() {
        showingDebugOnboarding = false
        print("🐛 Debug: Onboarding flow cancelled")
    }
    
    private func handlePrimaryCurrencyChange(_ newCurrency: Currency) {
        // Don't show confirmation if it's the same currency
        if newCurrency == primaryCurrency {
            return
        }
        
        // Store the pending change and show confirmation dialog
        pendingCurrencyChange = newCurrency
        showingCurrencyChangeConfirmation = true
    }
    
    private func confirmCurrencyChange() {
        guard let newCurrency = pendingCurrencyChange else { return }
        
        // Proceed with the currency change
        updatePrimaryCurrency(to: newCurrency)
        
        // Clear pending state
        pendingCurrencyChange = nil
        showingCurrencyChangeConfirmation = false
    }
    
    private func cancelCurrencyChange() {
        // Reset to current currency (this will update the UI)
        primaryCurrency = currencyPrefs.primaryCurrency
        
        // Clear pending state
        pendingCurrencyChange = nil
        showingCurrencyChangeConfirmation = false
    }
    
    private var contentWithAlerts: some View {
        baseViewWithSheets
    }
    
    
    private var contentWithActionAlerts: some View {
        contentWithAlerts
            .appAlert(
                title: "Delete Account",
                isPresented: .constant(false), // Disabled - using sheet instead
                message: "",
                primaryAction: .destructive("Delete Account") { }
            )
            .appAlert(
                title: "Delete All Transactions",
                isPresented: $showingDeleteAllConfirmation,
                message: "Are you sure you want to delete all transactions? This will permanently remove all transaction data from Firebase. This action cannot be undone.",
                primaryAction: .destructive("Delete All") {
                    deleteAllTransactionsFromFirebase()
                }
            )
            .appAlert(
                title: "Pull Data from Cloud",
                isPresented: $showingPullDataConfirmation,
                message: "This will download and merge data from Firebase with your local data. Any local changes will be overwritten. Continue?",
                primaryAction: .primary("Pull Data") {
                    pullDataFromFirebase()
                }
            )
            .appInfoAlert(
                title: "Authentication Required",
                isPresented: $showingReauthenticationAlert,
                message: accountDeletionError ?? "Authentication is required to complete this action.",
                onDismiss: {
                    accountDeletionError = nil
                }
            )
            .appAlert(
                title: "Sign Out",
                isPresented: $showingLogoutConfirmation,
                message: "Are you sure you want to sign out?",
                primaryAction: .destructive("Sign Out") {
                    authManager.logout()
                }
            )
            .appAlert(
                title: "Change Primary Currency",
                isPresented: $showingCurrencyChangeConfirmation,
                message: {
                    if let newCurrency = pendingCurrencyChange {
                        return "Changing your primary currency to \(newCurrency.displayName) will convert all existing transactions using historical exchange rates. This action cannot be undone. Continue?"
                    } else {
                        return "This will convert all existing transactions to the new currency. Continue?"
                    }
                }(),
                primaryAction: .destructive("Change Currency") {
                    confirmCurrencyChange()
                },
                secondaryAction: .cancel("Cancel") {
                    cancelCurrencyChange()
                }
            )
    }
    
    private var contentWithSheets: some View {
        contentWithActionAlerts
            .onAppear {
                rateManager.setPrimaryCurrency(primaryCurrency)
                rateManager.setSecondaryCurrency(currencyPrefs.secondaryCurrency)
            }
            .onChange(of: currencyPrefs.primaryCurrency) { oldValue, newValue in
                sampleCurrency = newValue.symbol
            }
            .onChange(of: currencyPrefs.secondaryCurrency) { oldValue, newValue in
                rateManager.setSecondaryCurrency(newValue)
                print("💱 SettingsPage: Secondary currency changed to: \(newValue?.rawValue ?? "none")")
            }
    }
    
    // MARK: - Settings Main View
    
    var settingsMainView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                profileSection
                settingsSectionsContainer
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 20)
            }
            .background(AppColors.surfacePrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surfacePrimary)
        .onAppear {
            print("⚙️ SETTINGS: ========== SETTINGS PAGE APPEARED ==========")
            print("⚙️ SETTINGS: Checking RevenueCat offerings state...")
            print("⚙️ SETTINGS: Current offerings count: \(revenueCatManager.offerings?.all.count ?? 0)")
            print("⚙️ SETTINGS: Target offering: \(revenueCatManager.targetOffering?.identifier ?? "nil")")
            
            // Ensure offerings are loaded when settings page appears
            if revenueCatManager.offerings == nil {
                print("🔄 SETTINGS: No offerings loaded - loading now...")
                Task {
                    await revenueCatManager.loadOfferings()
                    print("✅ SETTINGS: Offerings loaded on page appearance")
                }
            } else {
                print("✅ SETTINGS: Offerings already available")
            }
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(spacing: 16) {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(AppColors.blue500)
                    .frame(width: 120, height: 120)

                Text(getUserInitials())
                    .font(.custom("OverusedGrotesk-SemiBold", size: 50))
                    .foregroundColor(.white)
            }

            // User Name (or "CashMonki User" if empty)
            let userName = userManager.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(userName.isEmpty ? "Cashmonki User" : userName)
                .font(AppFonts.overusedGroteskSemiBold(size: 24))
                .foregroundColor(AppColors.foregroundPrimary)

            // Email hidden - no auth in current flow
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    // MARK: - Settings Sections Container
    
    private var settingsMainSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            // HIDDEN: Account section commented out for now
            // accountSection
            preferencesSection
            featureUsageSection
        }
    }
    
    private var settingsDataSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            // COMMENTED OUT: Data section - might use in the future
            // dataSection
            supportSection
            legalSection

            // Debug section only visible in debug builds
            #if DEBUG
            debugSection
            #endif

            // Footer
            VStack(spacing: 8) {
                Text("Made with ☕️ & ♥️ by")
                    .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(AppColors.foregroundSecondary)

                Text("Rosebud Studio")
                    .font(Font.custom("Overused Grotesk", size: 14).weight(.semibold))
                    .foregroundColor(AppColors.foregroundPrimary)

                // Version number (tap 7 times to toggle internal device mode)
                HStack(spacing: 4) {
                    Text("Ver \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    if versionTapCount > 0 {
                        Text("(\(versionTapCount))")
                            .foregroundColor(versionTapCount >= 7 ? .green : AppColors.foregroundTertiary)
                    }
                    if isInternalDevice {
                        Text("🔧")
                    }
                }
                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundSecondary)
                .padding(.top, 24) // 32px total (8px VStack spacing + 24px)
                .onTapGesture {
                    handleVersionTap()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            // HIDDEN: Account Debug section
            // duplicateAccountDebugSection // DEBUG: Temporary for duplicate account issue
        }
    }
    
    private var settingsSectionsContainer: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsMainSections
            settingsDataSections
        }
    }
    
    // MARK: - Individual Sections
    
    private var accountSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Account")
            
            VStack(spacing: 0) {
                // Subscription testing toggle
                #if DEBUG
                HStack {
                    HStack(spacing: 12) {
                        Text("🧪")
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Subscription Testing")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text("Toggle premium features for testing")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { RevenueCatManager.shared.isProUser },
                        set: { isOn in
                            if isOn {
                                RevenueCatManager.shared.enableTestPremium()
                            } else {
                                RevenueCatManager.shared.disableTestPremium()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 52)
                #endif
                
                settingsRow(
                    title: "Name",
                    subtitle: userManager.currentUser.name,
                    icon: "👤"
                ) {
                    showingEditNameSheet = true
                }
                
                // FUTURE: Uncomment when re-enabling authentication
                // Divider()
                //     .padding(.leading, 52)
                //
                // settingsRow(
                //     title: "Logout",
                //     subtitle: "",
                //     icon: "🚪"
                // ) {
                //     showingLogoutConfirmation = true
                // }
            }
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var preferencesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Preferences")
            
            VStack(spacing: 0) {
                // COMMENTED OUT: Reset Daily Analysis
                // settingsRow(
                //     title: "Reset Daily Analysis",
                //     subtitle: "Reset your daily receipt scanning limit (3 scans)",
                //     icon: "🔄"
                // ) {
                //     // Reset daily usage for receipt analysis
                //     dailyUsageManager.resetDailyUsage()
                //
                //     // Show success toast
                //     toastManager.showSuccess("Daily receipt analysis reset! 3 new scans available.")
                // }
                //
                // Divider()
                //     .padding(.leading, 52)

                // Name
                settingsRow(
                    title: "Name",
                    subtitle: userManager.currentUser.name.isEmpty ? "Cashmonki User" : userManager.currentUser.name,
                    icon: "👤"
                ) {
                    showingEditNameSheet = true
                }

                Divider()
                    .padding(.leading, 52)

                // Roast My Receipt Toggle
                HStack {
                    HStack(spacing: 12) {
                        Text("🔥")
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Roast My Receipt")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text("Turn it on, scan a receipt... ;)")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: $isRoastReceiptEnabled)
                        .labelsHidden()
                        .tint(Color(red: 0.33, green: 0.18, blue: 1))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .padding(.leading, 52)

                settingsRow(
                    title: "Categories",
                    subtitle: "Manage transaction categories",
                    icon: "🍎"
                ) {
                    showingEditCategoriesSheet = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // COMMENTED OUT: Welcome toast preview
                // settingsRow(
                //     title: "Show Welcome Toast",
                //     subtitle: "Preview welcome toast animation",
                //     icon: "🎉"
                // ) {
                //     // Show welcome toast preview
                //     toastManager.showWelcome("Preview")
                // }
                //
                // Divider()
                //     .padding(.leading, 52)
                
                // COMMENTED OUT: Goal choices preview
                // settingsRow(
                //     title: "Show Goal Choices",
                //     subtitle: "Preview goals onboarding sheet",
                //     icon: "🎯"
                // ) {
                //     // Show goals onboarding preview
                //     showingGoalsOnboarding = true
                // }
                //
                // Divider()
                //     .padding(.leading, 52)
                
                currencySettingsRows

                Divider()
                    .padding(.leading, 52)

                // Sync to Cloud Toggle (Coming Soon)
                HStack {
                    HStack(spacing: 12) {
                        Text("☁️")
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync to Cloud")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text("Coming soon")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .tint(Color(red: 0.33, green: 0.18, blue: 1))
                        .disabled(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(0.5) // Dim to indicate coming soon

                Divider()
                    .padding(.leading, 52)

                settingsRow(
                    title: "Rate Cashmonki",
                    subtitle: "Make a developer smile today (please)",
                    icon: "🙈"
                ) {
                    requestAppReview()
                }

                // COMMENTED OUT: Add first transaction guide
                // Divider()
                //     .padding(.leading, 52)
                //
                // settingsRow(
                //     title: "Add First Transaction",
                //     subtitle: "Show transaction onboarding guide",
                //     icon: "💳"
                // ) {
                //     showingTransactionOnboarding = true
                // }

                // COMMENTED OUT: Language picker (localization not yet implemented)
                // Divider()
                //     .padding(.leading, 52)
                //
                // settingsRow(
                //     title: "Language",
                //     subtitle: selectedLanguage.displayName,
                //     icon: selectedLanguage.flag
                // ) {
                //     showingLanguagePicker = true
                // }
            }
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var featureUsageSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Feature Usage")
            
            VStack(spacing: 0) {
                // Feature usage header image (outside the white card)
                Button(action: {
                    // TODO: Navigate to detailed feature usage analytics
                    print("🔍 Feature Usage: Opening detailed analytics...")
                }) {
                    Image("feature usage card image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Progress bars and content card (white background)
                featureUsageCard
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var featureUsageCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Receipt Scanned section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("✨ Receipt Scanned")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(AppColors.foregroundPrimary)
                    
                    Spacer()
                    
                    Text(revenueCatManager.isProUser ? "Unlimited" : "\(max(0, 3 - usedScansToday))/3 left today")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                        .animation(.easeInOut(duration: 0.3), value: revenueCatManager.isProUser)
                }
                
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .fill(AppColors.surfacePrimary)
                        .frame(height: 10)
                    
                    // Fill bar
                    Rectangle()
                        .fill(revenueCatManager.isProUser ? AppColors.successForeground : Color(red: 0x4C/255.0, green: 0x3B/255.0, blue: 0xF5/255.0))
                        .frame(width: .infinity, height: 10)
                        .scaleEffect(x: revenueCatManager.isProUser ? 1.0 : Double(usedScansToday)/3.0, anchor: .leading)
                        .opacity(revenueCatManager.isProUser ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: revenueCatManager.isProUser)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            
            // Categories section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🍎 Categories")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(AppColors.foregroundPrimary)
                    
                    Spacer()
                    
                    Text(revenueCatManager.isProUser ? "Go bananas" : "No Custom Categories")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                
                // Progress bar - only show for pro users, or empty bar for free users
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .fill(AppColors.surfacePrimary)
                        .frame(height: 10)
                    
                    // Fill bar - only filled for pro users
                    Rectangle()
                        .fill(revenueCatManager.isProUser ? AppColors.successForeground : AppColors.surfacePrimary)
                        .frame(width: .infinity, height: 10)
                        .scaleEffect(x: revenueCatManager.isProUser ? 1.0 : 0.0, anchor: .leading)
                        .opacity(revenueCatManager.isProUser ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: revenueCatManager.isProUser)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            
            // Wallets section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("💼 Wallets")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(AppColors.foregroundPrimary)
                    
                    Spacer()
                    
                    Text(revenueCatManager.isProUser ? "Let loose" : "\(max(0, 2 - currentWalletCount))/2 wallets left")
                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .fill(AppColors.surfacePrimary)
                        .frame(height: 10)
                    
                    // Fill bar
                    Rectangle()
                        .fill(revenueCatManager.isProUser ? AppColors.successForeground : Color(red: 0x4C/255.0, green: 0x3B/255.0, blue: 0xF5/255.0))
                        .frame(width: .infinity, height: 10)
                        .scaleEffect(x: revenueCatManager.isProUser ? 1.0 : Double(currentWalletCount)/2.0, anchor: .leading)
                        .opacity(revenueCatManager.isProUser ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: revenueCatManager.isProUser)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            
            // Get Cashmonki Pro button / Manage Billing for pro users
            AppButton.secondary(revenueCatManager.isProUser ? "Manage Billing" : "Get Cashmonki Pro ⭐", size: .extraSmall) {
                if revenueCatManager.isProUser {
                    showingManageBilling = true // Show manage billing for pro users
                } else {
                    showingCustomPaywall = true // Show paywall for free users
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white)
        .opacity(1.0)
        .animation(.easeInOut(duration: 0.3), value: revenueCatManager.isProUser)
    }
    
    private var primaryCurrencySubtitle: String {
        formatCurrencySubtitle(primaryCurrency, lastUpdated: rateManager.lastUpdateDate)
    }
    
    private var receiptsScannedToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Count transactions created today from receipt scanning
        let todayTransactions = userManager.currentUser.transactions.filter { transaction in
            let createdDate = transaction.createdAt
            return createdDate >= today && createdDate < tomorrow && transaction.hasReceiptImage
        }
        
        return todayTransactions.count
    }
    
    private var usedScansToday: Int {
        // Use DailyUsageManager to get the actual API usage count
        let maxUsage = 3
        let remaining = dailyUsageManager.getRemainingUsage()
        return maxUsage - remaining
    }
    
    private var currentWalletCount: Int {
        // Count all user wallets (accounts)
        return userManager.currentUser.accounts.count
    }
    
    private var currencySettingsRows: some View {
        Group {
            settingsRow(
                title: "Primary Currency",
                subtitle: primaryCurrencySubtitle,
                icon: primaryCurrency.flag
            ) {
                showingCurrencyPicker = true
            }
            
            // Secondary currency temporarily hidden
            /*
            Divider()
                .padding(.leading, 52)
            
            settingsRow(
                title: "Secondary Currency",
                subtitle: secondaryCurrencySubtitle,
                icon: secondaryCurrencyIcon
            ) {
                showingSecondaryCurrencyPicker = true
            }
            */
        }
    }
    
    private var secondaryCurrencyIcon: String {
        currencyPrefs.secondaryCurrency?.flag ?? "🏳️"
    }
    
    private var secondaryCurrencySubtitle: String {
        if let secondary = currencyPrefs.secondaryCurrency {
            return formatCurrencySubtitle(secondary, lastUpdated: rateManager.lastUpdateDate)
        } else {
            return "None selected"
        }
    }
    
    // COMMENTED OUT: Data section - might use in the future
    // private var dataSection: some View {
    //     VStack(spacing: 0) {
    //         sectionHeader("Data")
    //         
    //         VStack(spacing: 0) {
    //             firebaseSyncToggleRow()
    //             
    //             Divider()
    //                 .padding(.leading, 52)
    //             
    //             pullDataFromCloudRow()
    //             
    //             Divider()
    //                 .padding(.leading, 52)
    //             
    //             settingsRow(
    //                 title: "Delete Data Online",
    //                 subtitle: "Remove all your data from cloud storage",
    //                 icon: "🗑️"
    //             ) {
    //                 showingDeleteAllConfirmation = true
    //             }
    //         }
    //         .background(AppColors.backgroundWhite)
    //         .clipShape(RoundedRectangle(cornerRadius: 16))
    //     }
    // }
    
    private var supportSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Support")
            
            VStack(spacing: 0) {
                settingsRow(
                    title: "Delete Account",
                    subtitle: "Permanently delete your account and all data",
                    icon: "🗑️"
                ) {
                    showingDeleteAccountSheet = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                settingsRow(
                    title: "Need Customer Support?",
                    subtitle: "Get help with your account",
                    icon: "😁"
                ) {
                    showingSupportOptions = true
                }
            }
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var legalSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Legal")

            VStack(spacing: 0) {
                settingsRow(
                    title: "Terms of Use",
                    subtitle: "View our terms and conditions",
                    icon: "📄"
                ) {
                    if let url = URL(string: "https://cashmonki.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }

                Divider()
                    .padding(.leading, 52)

                settingsRow(
                    title: "Privacy Policy",
                    subtitle: "How we handle your data",
                    icon: "🔒"
                ) {
                    if let url = URL(string: "https://cashmonki.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var debugSection: some View {
        DebugSettingsSection(
            showingDeleteAllConfirmation: $showingDeleteAllConfirmation,
            showingDebugOnboarding: $showingDebugOnboarding,
            debugOnboardingStartStep: $debugOnboardingStartStep,
            showingTransactionOnboarding: $showingTransactionOnboarding,
            showingCustomPaywall: $showingCustomPaywall,
            showingCurrencyPicker: $showingCurrencyPicker,
            showingSecondaryCurrencyPicker: $showingSecondaryCurrencyPicker,
            environmentTestResult: $environmentTestResult,
            userManager: userManager
        )
    }
    
    // MARK: - Showcase Sections (Temporarily Disabled)
    // These sections are not currently used in the main UI but may be causing type-checking timeouts
    
    /*
    var buttonShowcaseSection: some View {
        VStack(spacing: 24) {
            Text("Button Components Showcase")
                .font(AppFonts.overusedGroteskSemiBold(size: 20))
                .padding(.top, 8)
            
            // Primary Buttons (1st Hierarchy)
            VStack(spacing: 16) {
                Text("Primary Buttons")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    showcaseButton(
                        hierarchy: .primary,
                        size: .extraSmall,
                        id: "primary-xs"
                    )
                }
            }
            
            // Secondary Buttons (2nd Hierarchy)
            VStack(spacing: 16) {
                Text("Secondary Buttons")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    showcaseButton(
                        hierarchy: .secondary,
                        size: .extraSmall,
                        id: "secondary-xs"
                    )
                }
            }
            
            // Tertiary Buttons (3rd Hierarchy)
            VStack(spacing: 16) {
                Text("Tertiary Buttons")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    showcaseButton(
                        hierarchy: .tertiary,
                        size: .extraSmall,
                        id: "tertiary-xs"
                    )
                }
            }
        }
        .padding(20)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    var tabShowcaseSection: some View {
        VStack(spacing: 24) {
            Text("Tab Components Showcase")
                .font(AppFonts.overusedGroteskSemiBold(size: 20))
                .padding(.top, 8)
            
            // Individual Tabs
            VStack(spacing: 16) {
                Text("Individual Tabs")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        AppTab.selected("Selected") {
                            print("Selected tab tapped")
                        }
                        AppTab.inactive("Inactive") {
                            print("Inactive tab tapped")
                        }
                    }
                    
                    HStack(spacing: 12) {
                        AppTab.selected("With Icons", leftIcon: "star.fill", rightIcon: "chevron.down") {
                            print("Selected with icons tapped")
                        }
                        AppTab.inactive("With Icons", leftIcon: "heart", rightIcon: "arrow.right") {
                            print("Inactive with icons tapped")
                        }
                    }
                }
            }
            
            // Tab Groups
            VStack(spacing: 16) {
                Text("Tab Groups")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 16) {
                    AppTabGroup(
                        tabs: basicTabItems,
                        selectedIndex: $selectedGroupTab
                    )
                    
                    AppTabGroup(
                        tabs: iconTabItems,
                        selectedIndex: $selectedPeriodTab
                    )
                }
            }
        }
        .padding(20)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    var inputComponentsShowcaseSection: some View {
        VStack(spacing: 24) {
            Text("Input Components Showcase")
                .font(AppFonts.overusedGroteskSemiBold(size: 20))
                .padding(.top, 8)
            
            // Text Input Fields
            VStack(spacing: 16) {
                Text("Text Input Fields")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    AppInputField.text(
                        title: "Name",
                        text: $sampleText,
                        placeholder: "Enter your name"
                    )
                    
                    AppInputField.merchant(
                        text: $sampleMerchant
                    )
                    
                    AppInputField.search(
                        text: $sampleSearch,
                        placeholder: "Search transactions..."
                    )
                }
            }
            
            // Amount Input Fields
            VStack(spacing: 16) {
                Text("Amount Input Fields")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    AppInputField.amount(
                        text: $sampleAmount,
                        selectedCurrency: $sampleCurrency
                    )
                    
                    AppInputField.amount(
                        text: $sampleAmount,
                        selectedCurrency: $sampleCurrency
                    )
                }
            }
            
            // Date Input Field
            VStack(spacing: 16) {
                Text("Date Input Field")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 12) {
                    AppInputField.date(
                        title: "Transaction Date",
                        dateValue: $sampleDate
                    )
                }
            }
            
            // Tab Chips Section
            VStack(spacing: 16) {
                Text("Tab/Filter Chips")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 16) {
                    // Tab usage example
                    HStack(spacing: 12) {
                        TabChip.basic(title: "Income", isSelected: true) {
                            print("Income tab selected")
                        }
                        
                        TabChip.basic(title: "Expenses", isSelected: false) {
                            print("Expenses tab selected")
                        }
                        
                        TabChip.basic(title: "All", isSelected: false) {
                            print("All tab selected")
                        }
                    }
                    
                    // Filter chips example
                    HStack(spacing: 12) {
                        TabChip.filter(title: "Food", isActive: true) {
                            print("Food filter toggled")
                        }
                        
                        TabChip.filter(title: "Transport", isActive: false) {
                            print("Transport filter toggled")
                        }
                        
                        TabChip.filter(title: "Shopping", isActive: true) {
                            print("Shopping filter toggled")
                        }
                    }
                    
                    // Design system usage examples
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Design System Usage:")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            CashMonkiDS.Selection.tabChip(title: "Tab", isSelected: true) {
                                print("Design system tab")
                            }
                            
                            CashMonkiDS.Selection.filterChip(title: "Filter", isActive: false) {
                                print("Design system filter")
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    func showcaseButton(hierarchy: ButtonHierarchy, size: ButtonSize, id: String) -> some View {
        let isPressed = pressedButton == id
        let buttonState: ButtonState = isPressed ? .pressed : .active
        
        return AppButton(
            title: "Edit",
            action: { handleShowcaseButtonTap(id: id) },
            hierarchy: hierarchy,
            size: size,
            state: buttonState,
            leftIcon: "arrow.left",
            rightIcon: "arrow.right"
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0.0,
            maximumDistance: .infinity,
            pressing: { pressing in handleShowcaseButtonPress(pressing: pressing, id: id) },
            perform: {
            // This is called when the long press completes
            print("\(id) long press completed")
        })
    }
    */
    
    // MARK: - Essential Functions
    
    private func handleShowcaseButtonTap(id: String) {
        print("\(id) tapped")
        // Brief press animation
        withAnimation(.easeInOut(duration: 0.05)) {
            pressedButton = id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.05)) {
                pressedButton = nil
            }
        }
    }
    
    private func handleShowcaseButtonPress(pressing: Bool, id: String) {
        withAnimation(.easeInOut(duration: 0.05)) {
            pressedButton = pressing ? id : nil
        }
    }
    
    func settingsRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(AppFonts.overusedGroteskMedium(size: 24))
                
                // Conditional layout based on whether subtitle exists
                if subtitle.isEmpty {
                    // Single line - center vertically
                    Text(title)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Two lines - align to top
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.0001))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func syncSettingsRow() -> some View {
        VStack(spacing: 0) {
            Button(action: {
                // Check if Firebase sync is enabled first
                guard userManager.isFirebaseSyncEnabled else {
                    print("🚫 Settings: Firebase sync is disabled - cannot sync")
                    return
                }
                
                // Initialize and start sync manager manually
                print("🔄 Settings: Manual sync requested")
                
                // Always try to initialize sync manager first, then force sync
                print("🔄 Settings: Initializing sync manager and forcing sync")
                userManager.initializeSyncManager()
                
                // Small delay to let sync manager initialize, then force sync
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    userManager.forceSync()
                })
            }) {
                HStack(spacing: 12) {
                    Text("🔄")
                        .font(AppFonts.overusedGroteskMedium(size: 24))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync with Firebase")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(.primary)
                        
                        Text(syncSettingsSubtitle)
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(syncSettingsTextColor)
                    }
                    
                    Spacer()
                    
                    if userManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.0001))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(userManager.isSyncing || !userManager.isFirebaseSyncEnabled)
            .opacity(userManager.isFirebaseSyncEnabled ? 1.0 : 0.6)
        }
    }
    
    func pullDataFromFirebaseRow() -> some View {
        VStack(spacing: 0) {
            Button(action: {
                print("⬇️ Settings: Pull data from Firebase requested")
                isPullingData = true
                pullDataResult = nil
                
                // Force pull data from Firebase, respecting account filters
                print("⬇️ Settings: Pulling Firebase data for current user and sub-accounts")
                
                // Initialize sync manager if needed, then force pull
                userManager.initializeSyncManager()
                
                // Small delay to let sync manager initialize, then force pull
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    pullFirebaseDataToLocal()
                })
            }) {
                HStack(spacing: 12) {
                    Text("⬇️")
                        .font(AppFonts.overusedGroteskMedium(size: 24))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pull Data from Firebase")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(.primary)
                        
                        Text("Fetch latest transactions from cloud storage")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isPullingData {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.0001))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPullingData)
            
            // Show pull data result if available
            if let result = pullDataResult {
                Divider()
                    .padding(.leading, 52)
                
                HStack(spacing: 12) {
                    Text(result.hasPrefix("✅") ? "✅" : "❌")
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pull Data Result")
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(result.hasPrefix("✅") ? (AppColors.successForeground) : .red)
                        
                        Text(result)
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    private func pullFirebaseDataToLocal() {
        print("⬇️ Settings: Starting Firebase data pull")
        
        // Get the current user ID (respects account switching) - USE FIREBASE UID
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? userManager.currentUser.id.uuidString
        let userName = userManager.currentUser.name
        
        print("⬇️ Settings: Pulling data for user: \(userName) (ID: \(userManager.currentUser.id.uuidString))")
        
        // Use FirestoreService to fetch transactions for the current user and their sub-accounts
        FirestoreService.shared.fetchTransactions(userId: firebaseUserID) { result in
            DispatchQueue.main.async {
                
                self.isPullingData = false
                
                switch result {
                case .success(let transactions):
                    print("✅ Settings: Successfully pulled \(transactions.count) transactions from Firebase")
                    
                    // Get current default wallet ID for migration
                    guard let defaultWalletId = self.userManager.currentUser.defaultSubAccount?.id else {
                        print("❌ Settings: No default wallet found")
                        self.pullDataResult = "❌ No default wallet found"
                        return
                    }
                    
                    print("🔧 Settings: Migrating transactions to use current wallet ID: \(defaultWalletId.uuidString.prefix(8))")
                    
                    // Migrate all transactions to use the current default wallet ID
                    let migratedTransactions = transactions.map { transaction in
                        Txn(
                            txID: transaction.txID,
                            accountID: transaction.accountID,
                            walletID: defaultWalletId, // ✅ Set to current wallet
                            category: transaction.category,
                            categoryId: transaction.categoryId,
                            amount: transaction.amount,
                            date: transaction.date,
                            createdAt: transaction.createdAt,
                            receiptImage: transaction.receiptImage,
                            hasReceiptImage: transaction.hasReceiptImage,
                            merchantName: transaction.merchantName,
                            paymentMethod: transaction.paymentMethod,
                            receiptNumber: transaction.receiptNumber,
                            invoiceNumber: transaction.invoiceNumber,
                            items: transaction.items,
                            note: transaction.note,
                            originalAmount: transaction.originalAmount,
                            originalCurrency: transaction.originalCurrency,
                            primaryCurrency: transaction.primaryCurrency,
                            secondaryCurrency: transaction.secondaryCurrency,
                            exchangeRate: transaction.exchangeRate,
                            secondaryAmount: transaction.secondaryAmount,
                            secondaryExchangeRate: transaction.secondaryExchangeRate
                        )
                    }
                    
                    // Load the migrated transactions
                    let beforeCount = self.userManager.currentUser.transactions.count
                    self.userManager.currentUser.transactions = migratedTransactions
                    let afterCount = migratedTransactions.count
                    
                    print("✅ Settings: Migrated \(migratedTransactions.count) transactions to wallet: \(defaultWalletId.uuidString.prefix(8))")
                    
                    // Debug: Show migrated transactions
                    print("🔍 Settings DEBUG: Final transaction count: \(afterCount)")
                    for transaction in migratedTransactions {
                        print("🔍 Settings DEBUG: Transaction \(transaction.txID.uuidString.prefix(8)) - \(transaction.category) - walletID: \(transaction.walletID?.uuidString.prefix(8) ?? "nil"), amount: \(transaction.amount)")
                    }
                    
                    // Trigger UI updates
                    self.userManager.objectWillChange.send()
                    AccountManager.shared.objectWillChange.send()
                    
                    self.pullDataResult = "✅ Successfully pulled and migrated \(transactions.count) transactions to current wallet"
                    print("📊 Settings: Local storage updated - Before: \(beforeCount), After: \(afterCount), Migrated: \(afterCount)")
                    
                case .failure(let error):
                    print("❌ Settings: Failed to pull data from Firebase: \(error)")
                    self.pullDataResult = "❌ Failed to pull data: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func sampleDataRow() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                print("🎯 Settings: Generate Fixed Sample Data button tapped")
                userManager.generateFixedSampleData()
            }) {
                HStack(spacing: 16) {
                    // Icon
                    Circle()
                        .fill(AppColors.surfacePrimary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("🗄️")
                                .font(.system(size: 18))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Sample Data")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(.primary)
                        
                        Text("Creates fixed transactions for October 23")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.0001))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    /// Reset all categories to built-in defaults
    private func resetCategories() {
        print("🔄 Settings: Resetting categories to defaults...")
        categoriesManager.resetAllCategories()
        print("✅ Settings: Categories reset completed")
    }
    
    /// Pull data from Firebase (simplified method for debug section)
    private func pullDataFromFirebase() {
        print("⬇️ Settings: Pull data from Firebase requested")
        isPullingData = true
        pullDataResult = nil
        
        // Force pull data from Firebase, respecting account filters
        print("⬇️ Settings: Pulling Firebase data for current user and sub-accounts")
        
        // Initialize sync manager if needed, then force pull
        userManager.initializeSyncManager()
        
        // Small delay to let sync manager initialize, then force pull
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            pullFirebaseDataToLocal()
        })
    }
    
    /// Delete all transactions from Firebase
    private func deleteAllTransactionsFromFirebase() {
        print("🗑️ Settings: Delete all transactions from Firebase requested")
        isDeletingAllTransactions = true
        deleteAllResult = nil
        
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? userManager.currentUser.id.uuidString
        
        FirestoreService.shared.clearAllTransactions(userId: firebaseUserID) { result in
            DispatchQueue.main.async {
                self.isDeletingAllTransactions = false
                
                switch result {
                case .success():
                    self.deleteAllResult = "✅ Successfully deleted all transactions from Firebase"
                    print("✅ Settings: All transactions deleted successfully")
                    
                    // Also clear local transactions
                    self.userManager.currentUser.transactions.removeAll()
                    self.userManager.objectWillChange.send()
                    
                case .failure(let error):
                    self.deleteAllResult = "❌ Failed to delete transactions: \(error.localizedDescription)"
                    print("❌ Settings: Failed to delete transactions: \(error)")
                }
            }
        }
    }
    
    /// Test Firebase connection
    private func testFirebase() {
        print("🧪 Settings: Testing Firebase connectyon...")
        userManager.testFirebaseConnection()
    }
    
    /// Pull latest data from cloud (overwrites local data)
    private func pullDataFromCloud() {
        print("⬇️ Settings: Pull data from cloud requested")
        
        guard userManager.isFirebaseSyncEnabled else {
            print("🚫 Settings: Cannot pull data - Firebase sync is disabled")
            return
        }
        
        self.isPullingData = true
        self.pullDataResult = nil
        
        // Use the existing refresh functionality
        userManager.refreshFromFirebase { (success: Bool) in
            DispatchQueue.main.async {
                self.isPullingData = false
                
                if success {
                    print("✅ Settings: Data pulled from cloud successfully")
                    self.pullDataResult = "✅ Data updated from cloud"
                    
                    // Show brief success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.pullDataResult = nil
                    }
                } else {
                    print("❌ Settings: Failed to pull data from cloud")
                    self.pullDataResult = "❌ Failed to pull data"
                    
                    // Show error message longer
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.pullDataResult = nil
                    }
                }
            }
        }
    }
    
    /// Test Receipt AI API connection
    private func testReceiptAI() {
        print("🧪 Settings: Testing Receipt AI API connection...")
        isTestingAPI = true
        apiTestResult = nil
        
        AIReceiptAnalyzer.shared.testAPIConnection { result in
            DispatchQueue.main.async {
                isTestingAPI = false
                
                switch result {
                case .success(let response):
                    print("✅ Receipt AI API test passed!")
                    print("📄 Response: \(response)")
                    apiTestResult = "✅ API connection working!"
                case .failure(let error):
                    print("❌ Receipt AI API test failed: \(error)")
                    if let receiptError = error as? ReceiptAIError {
                        switch receiptError {
                        case .missingAPIKey:
                            apiTestResult = "❌ API key not configured"
                        default:
                            apiTestResult = "❌ API test failed: \(receiptError.localizedDescription)"
                        }
                    } else {
                        apiTestResult = "❌ API test failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    
    /// Get user initials from name
    private func getUserInitials() -> String {
        let name = userManager.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "CU" // Cashmonki User
        }
        let nameComponents = name.components(separatedBy: " ")
        let initials = nameComponents.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
    
    /// Check if user has existing transactions
    private func hasExistingTransactions() -> Bool {
        return !userManager.currentUser.transactions.isEmpty
    }
    
    
    /// Format currency subtitle with last updated info
    private func formatCurrencySubtitle(_ currency: Currency, lastUpdated: Date?) -> String {
        let currencyInfo = "\(currency.symbol) \(currency.rawValue)"
        
        guard let lastUpdated = lastUpdated else {
            return "\(currencyInfo) • never updated"
        }
        
        let timeAgo = formatTimeAgo(from: lastUpdated)
        return "\(currencyInfo) • last updated \(timeAgo)"
    }
    
    /// Format time ago string
    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval: Double = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60.0)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600.0)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400.0)
            return "\(days)d ago"
        }
    }
    
    /// Update primary currency in both local state and user account
    private func updatePrimaryCurrency(to newCurrency: Currency) {
        print("💰 SettingsPage: Updating primary currency to: \(newCurrency.rawValue) (\(newCurrency.displayName))")
        
        // Update local state
        primaryCurrency = newCurrency
        
        // Update user's account currency
        userManager.updatePrimaryCurrency(newCurrency)
        
        // Sync with centralized currency preferences
        CurrencyPreferences.shared.setPrimaryCurrency(newCurrency)
        
        // CRITICAL: Also update rate manager to clear cached rates and convert existing transactions
        CurrencyRateManager.shared.setPrimaryCurrency(newCurrency)
        
        // Mark currency selection as completed to prevent onboarding from appearing
        UserDefaults.standard.set(true, forKey: "hasCompletedCurrencySelection")
        
        print("✅ SettingsPage: Primary currency updated successfully with rate manager conversion")
    }
    
    // MARK: - Original Debug Section
    
    var originalDebugSection: some View {
        VStack(spacing: 16) {
            Text("🧪 Debug & Testing")
                .font(AppFonts.overusedGroteskSemiBold(size: 18))
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                // Firebase Test Button
                settingsRow(
                    title: "Test Firebase Connection",
                    subtitle: testFirebaseSubtitle,
                    icon: "☁️"
                ) {
                    testFirebase()
                }
                
                // Receipt AI Test Button
                settingsRow(
                    title: "Test Receipt AI Connection",
                    subtitle: testReceiptAISubtitle,
                    icon: "🤖"
                ) {
                    testReceiptAI()
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Pull Data from Firebase
                settingsRow(
                    title: "Pull Data from Firebase",
                    subtitle: pullDataFromFirebaseSubtitle,
                    icon: "⬇️"
                ) {
                    pullDataFromFirebase()
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Delete All Transactions from Firebase
                settingsRow(
                    title: "Delete All Transactions",
                    subtitle: deleteAllTransactionsSubtitle,
                    icon: "🗑️"
                ) {
                    showingDeleteAllConfirmation = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Logout Button
                settingsRow(
                    title: "Sign Out",
                    subtitle: "Return to login screen",
                    icon: "🚪"
                ) {
                    showingLogoutConfirmation = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Delete Account Button
                settingsRow(
                    title: "Delete Account",
                    subtitle: "Permanently delete your account and all data",
                    icon: "⚠️"
                ) {
                    showingDeleteAccountSheet = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Debug Account Status Button
                settingsRow(
                    title: "Debug Account Status",
                    subtitle: "Check Firebase authentication status",
                    icon: "🔍"
                ) {
                    debugAccountStatus()
                }
                
                firebaseErrorView
                apiTestResultView
                pullDataResultView
                deleteAllResultView
                
            }
            .background(AppColors.backgroundWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Onboarding Reset
    
    private func resetOnboardingGates() {
        print("🔄 Settings: Resetting all onboarding gates after account deletion")
        
        // Reset all onboarding completion flags
        UserDefaults.standard.removeObject(forKey: "hasCompletedGoalSelection")
        UserDefaults.standard.removeObject(forKey: "selectedPrimaryGoal")
        UserDefaults.standard.removeObject(forKey: "selectedPrimaryGoals")
        UserDefaults.standard.removeObject(forKey: "hasSeenWelcome")
        UserDefaults.standard.removeObject(forKey: "userHasCompletedOnboarding")
        
        // Reset currency preferences
        UserDefaults.standard.removeObject(forKey: "userPrimaryCurrency")
        UserDefaults.standard.removeObject(forKey: "hasSetPrimaryCurrency")
        
        // Reset any other onboarding-related flags
        UserDefaults.standard.removeObject(forKey: "hasCompletedNameCollection")
        UserDefaults.standard.removeObject(forKey: "hasVerifiedEmail")
        UserDefaults.standard.removeObject(forKey: "hasCompletedEmailVerification")
        
        // CRITICAL: Clear OnboardingStateManager persisted state 
        UserDefaults.standard.removeObject(forKey: "onboardingState")
        
        // CRITICAL: Clear migration flags to prevent race conditions
        UserDefaults.standard.removeObject(forKey: "hasCompletedNumericalMigration")
        UserDefaults.standard.removeObject(forKey: "migrationInProgress")
        
        print("✅ Settings: All onboarding gates reset - new user will see full onboarding flow")
        print("   - Goal selection: reset")
        print("   - Currency selection: reset") 
        print("   - Name collection: reset")
        print("   - Welcome status: reset")
        print("   - Onboarding completion: reset")
        print("   - OnboardingStateManager state: reset")
    }
    
    private func completeAccountDeletion() {
        print("🎉 Settings: Account deletion process completed - performing COMPLETE data wipe")
        
        // 1. Get current user info before clearing
        let userEmail = userManager.currentUser.email
        let userId = userManager.currentUser.id.uuidString
        let firebaseUID = AuthenticationManager.shared.currentUser?.firebaseUID ?? ""
        
        print("🗑️ Settings: Wiping ALL data for user: \(userEmail)")
        print("🗑️ Settings: Local ID: \(userId), Firebase UID: \(firebaseUID.prefix(8))")
        
        // 2. Clear ALL UserDefaults - complete wipe
        let userDefaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        userDefaults.synchronize()
        print("🧹 Settings: Cleared ALL UserDefaults data")
        
        // 3. Clear UserManager completely and reset to guest
        userManager.signOut() // This resets to guest with onboardingCompleted = 0
        print("🧹 Settings: Reset UserManager to guest state")
        
        // 4. Reset OnboardingStateManager completely 
        OnboardingStateManager.shared.resetOnboardingState()
        print("🧹 Settings: Reset OnboardingStateManager to fresh state")
        
        // 5. Clear currency preferences completely
        CurrencyPreferences.shared.resetToDefault()
        print("🧹 Settings: Reset currency preferences to default")
        
        // 6. Log out from AuthenticationManager (clears auth state)
        AuthenticationManager.shared.logout()
        print("🧹 Settings: Logged out from AuthenticationManager")
        
        // 7. Clear any other managers/caches if needed
        // TODO: Add other manager resets here if we have them

        print("✅ Settings: COMPLETE account deletion and data wipe finished")
        print("🎯 Settings: App is now in fresh state - new user can register")

        // 8. Navigate to home tab and show snippy toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedTab = .home
            self.toastManager.showDeleted("Poof. All gone. Now what?")
        }
    }
    
    private func handleReauthenticationRequired() {
        print("🔐 Settings: Re-authentication required for account deletion")
        print("⏭️ Settings: Skipping Firebase Auth deletion due to re-authentication requirement")
        print("✅ Settings: Data deletion completed - Firebase Auth account will remain but all user data is deleted")
        
        // Still reset onboarding gates since user data was deleted
        resetOnboardingGates()
        
        // Complete the deletion process without Firebase Auth deletion
        completeAccountDeletion()
    }
    
    // MARK: - Delete Account
    
    private func deleteAccount() {
        print("🗑️ Settings: Delete account requested")
        isDeletingAccount = true
        
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? userManager.currentUser.id.uuidString
        
        // 1. Delete ALL user data from Firebase (comprehensive deletion)
        FirestoreService.shared.deleteAllUserData(userId: firebaseUserID) { result in
            switch result {
            case .success():
                print("✅ Settings: ALL user data deleted from Firebase")
                
                // 2. Delete Firebase Auth account
                DispatchQueue.main.async {
                    self.deleteFirebaseAuthAccount()
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isDeletingAccount = false
                    print("❌ Settings: Failed to delete user data: \(error.localizedDescription)")
                    self.accountDeletionError = "Failed to delete all user data: \(error.localizedDescription). Some data may still exist in Firebase."
                    self.showingReauthenticationAlert = true
                }
            }
        }
    }
    
    private func deleteFirebaseAuthAccount() {
        print("🗑️ Settings: Deleting Firebase Authentication account...")
        
        #if canImport(FirebaseAuth)
        // Delete the Firebase Auth account
        if let user = Auth.auth().currentUser {
            let userEmail = user.email ?? "unknown"
            let userUID = user.uid
            
            print("🗑️ Settings: Attempting to delete Firebase account for: \(userEmail) (UID: \(userUID.prefix(8)))")
            
            user.delete { error in
                DispatchQueue.main.async {
                    self.isDeletingAccount = false
                    
                    if let error = error {
                        print("❌ Settings: Failed to delete Firebase Auth account: \(error.localizedDescription)")
                        print("🔍 Settings: Error details: \(error)")
                        
                        // Check if error requires re-authentication
                        if error.localizedDescription.contains("recent authentication") || 
                           error.localizedDescription.contains("requires recent authentication") {
                            print("🔐 Settings: Re-authentication required - account was NOT deleted")
                            self.handleReauthenticationRequired()
                        } else {
                            // Other types of errors - account was NOT deleted
                            print("🚫 Settings: Account deletion failed with error - account still exists")
                            self.accountDeletionError = "Failed to delete account: \(error.localizedDescription). The account still exists and can be used to log in."
                            self.showingReauthenticationAlert = true
                        }
                    } else {
                        print("✅ Settings: Firebase Auth account deleted successfully for \(userEmail)")
                        print("🔥 Settings: Account UID \(userUID.prefix(8)) permanently removed from Firebase")
                        
                        // Reset all onboarding gates for new account
                        self.resetOnboardingGates()
                        
                        // Verify the account is actually deleted
                        self.verifyAccountDeletion(originalEmail: userEmail) {
                            self.completeAccountDeletion()
                        }
                    }
                }
            }
        } else {
            print("⚠️ Settings: No Firebase user found to delete")
            self.isDeletingAccount = false
            self.completeAccountDeletion()
        }
        #else
        print("⚠️ Settings: Firebase Auth not available - simulating account deletion")
        self.isDeletingAccount = false
        self.completeAccountDeletion()
        #endif
    }
    
    
    private func verifyAccountDeletion(originalEmail: String, completion: @escaping () -> Void) {
        print("🔍 Settings: Verifying account deletion...")
        
        #if canImport(FirebaseAuth)
        // Try to get current user - should be nil if account was deleted
        if let currentUser = Auth.auth().currentUser {
            print("⚠️ Settings: WARNING - User still exists after deletion attempt!")
            print("⚠️ Settings: Current user: \(currentUser.email ?? "unknown") (UID: \(currentUser.uid.prefix(8)))")
            
            // Account still exists - this is a problem
            DispatchQueue.main.async {
                self.accountDeletionError = "Account deletion verification failed. The account \(originalEmail) still exists and can be used to log in. Please try again or contact support."
                self.showingReauthenticationAlert = true
            }
        } else {
            print("✅ Settings: Account deletion verified - no current user found")
            completion()
        }
        #else
        print("✅ Settings: Account deletion verification simulated")
        completion()
        #endif
    }
    
    
    private func debugAccountStatus() {
        print("🔍 Settings: DEBUG - Checking account authentication status...")
        
        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            print("🔍 DEBUG: Firebase user EXISTS")
            print("   📧 Email: \(currentUser.email ?? "unknown")")
            print("   🆔 UID: \(currentUser.uid)")
            print("   ✅ Email verified: \(currentUser.isEmailVerified)")
            print("   📅 Created: \(currentUser.metadata.creationDate?.description ?? "unknown")")
            print("   🔐 Last sign in: \(currentUser.metadata.lastSignInDate?.description ?? "unknown")")
            print("   🔄 Token valid: checking...")
            
            // Check if token is still valid
            currentUser.getIDToken { token, error in
                if let error = error {
                    print("🔍 DEBUG: Token error: \(error.localizedDescription)")
                } else if token != nil {
                    print("🔍 DEBUG: ✅ Token is VALID - account can authenticate")
                } else {
                    print("🔍 DEBUG: ❌ No token - account may be invalid")
                }
            }
        } else {
            print("🔍 DEBUG: ❌ No Firebase user found")
        }
        
        print("🔍 DEBUG: AuthenticationManager state:")
        print("   🔐 Is authenticated: \(authManager.isAuthenticated)")
        print("   👤 Current user: \(authManager.currentUser?.email ?? "none")")
        print("   🆔 User ID: \(authManager.currentUser?.id.uuidString ?? "none")")
        print("   🔥 Firebase UID: \(authManager.currentUser?.firebaseUID ?? "none")")
        #else
        print("🔍 DEBUG: Firebase Auth not available")
        #endif
    }
    
    /// Test OpenRouter API connection
    private func testOpenRouterAPI() {
        print("🧪 Testing OpenRouter API connection...")
        isTestingAPI = true
        apiTestResult = nil
        
        // Use AIReceiptAnalyzer to test the connection
        let analyzer = AIReceiptAnalyzer.shared
        
        // Test API connection
        analyzer.testAPIConnection { result in
            DispatchQueue.main.async {
                self.isTestingAPI = false
                switch result {
                case .success(let message):
                    self.apiTestResult = "✅ OpenRouter API connection successful: \(message)"
                    print("✅ OpenRouter API test passed: \(message)")
                case .failure(let error):
                    self.apiTestResult = "❌ OpenRouter API test failed: \(error.localizedDescription)"
                    print("❌ OpenRouter API test failed: \(error)")
                }
            }
        }
    }
    
    /// Test environment variable loading and API key configuration
    private func testEnvironmentAndAPIKeys() {
        isTestingEnvironment = true
        environmentTestResult = "Testing..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Run the comprehensive environment test
            let testResult = EnvironmentTester.testProductionReadiness()
            let securityResult = EnvironmentTester.testInfoPlistSecurity()
            
            DispatchQueue.main.async {
                self.isTestingEnvironment = false
                
                if testResult.isReady && securityResult.isSecure {
                    self.environmentTestResult = "✅ All systems secure and working"
                    print("🧪 Environment Test: ✅ PASSED - Ready for production")
                } else {
                    self.environmentTestResult = "❌ Some issues found"
                    print("🧪 Environment Test: ❌ FAILED")
                }
                
                // Print detailed report to console
                EnvironmentTester.printDiagnosticReport()
                
                // Show toast with result
                if testResult.isReady {
                    self.toastManager.showSuccess("✅ Environment Test Passed")
                } else {
                    self.toastManager.showError("❌ Environment Test Failed")
                }
            }
        }
    }
    
    // MARK: - Section Headers
    
    /// Section header for settings groups
    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(
                    Font.custom("Overused Grotesk", size: 14)
                        .weight(.medium)
                )
                .foregroundColor(AppColors.foregroundSecondary)
            Spacer()
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Firebase Sync Toggle
    
    /// Firebase sync toggle row
    func firebaseSyncToggleRow() -> some View {
        HStack(spacing: 12) {
            Text("☁️")
                .font(AppFonts.overusedGroteskMedium(size: 24))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Data Online")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundStyle(.primary)
                
                Text(firebaseSyncSubtitle)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: firebaseSyncBinding)
                .labelsHidden()
                .tint(AppColors.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    private var firebaseSyncSubtitle: String {
        userManager.isFirebaseSyncEnabled ? "Last synced 24h ago" : "Data is only stored locally on this device"
    }
    
    private var firebaseSyncBinding: Binding<Bool> {
        Binding(
            get: { userManager.isFirebaseSyncEnabled },
            set: { newValue in
                userManager.setFirebaseSyncEnabled(newValue)
            }
        )
    }
    
    private var pullDataSubtitle: String {
        userManager.isFirebaseSyncEnabled ? "Get latest data from cloud (overwrites local changes)" : "Enable cloud sync above to use this feature"
    }
    
    private var pullDataTextColor: some ShapeStyle {
        userManager.isFirebaseSyncEnabled ? .secondary : .tertiary
    }
    
    private var pullDataChevronColor: Color {
        userManager.isFirebaseSyncEnabled ? AppColors.foregroundSecondary : AppColors.foregroundTertiary
    }
    
    private var syncSettingsSubtitle: String {
        userManager.isFirebaseSyncEnabled ? "Manually sync transactions with cloud database" : "Enable cloud sync above to use this feature"
    }
    
    private var syncSettingsTextColor: some ShapeStyle {
        userManager.isFirebaseSyncEnabled ? .secondary : .tertiary
    }
    
    private var testFirebaseSubtitle: String {
        userManager.isLoadingFromFirebase ? "Testing..." : "Verify cloud sync"
    }
    
    private var testReceiptAISubtitle: String {
        isTestingAPI ? "Testing..." : "Verify receipt scanning API"
    }
    
    private var pullDataFromFirebaseSubtitle: String {
        isPullingData ? "Fetching..." : "Fetch latest transactions from cloud"
    }
    
    private var deleteAllTransactionsSubtitle: String {
        isDeletingAllTransactions ? "Deleting..." : "⚠️ Remove all transactions from Firebase"
    }
    
    @ViewBuilder
    private var firebaseErrorView: some View {
        if let error = userManager.firebaseError {
            Divider()
                .padding(.leading, 52)
            
            HStack(spacing: 12) {
                Text("❌")
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Firebase Error")
                        .font(AppFonts.overusedGroteskSemiBold(size: 16))
                        .foregroundColor(AppColors.destructiveForeground)
                    
                    Text(error)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    @ViewBuilder
    private var apiTestResultView: some View {
        if let result = apiTestResult {
            Divider()
                .padding(.leading, 52)
            
            HStack(spacing: 12) {
                Text(result.hasPrefix("✅") ? "✅" : "❌")
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receipt AI Test Result")
                        .font(AppFonts.overusedGroteskSemiBold(size: 16))
                        .foregroundColor(result.hasPrefix("✅") ? (AppColors.successForeground) : .red)
                    
                    Text(result)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    @ViewBuilder
    private var pullDataResultView: some View {
        if let result = pullDataResult {
            Divider()
                .padding(.leading, 52)
            
            HStack(spacing: 12) {
                Text(result.hasPrefix("✅") ? "✅" : "❌")
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Firebase Pull Result")
                        .font(AppFonts.overusedGroteskSemiBold(size: 16))
                        .foregroundColor(result.hasPrefix("✅") ? (AppColors.successForeground) : .red)
                    
                    Text(result)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    @ViewBuilder
    private var deleteAllResultView: some View {
        if let result = deleteAllResult {
            Divider()
                .padding(.leading, 52)
            
            HStack(spacing: 12) {
                Text(result.hasPrefix("✅") ? "✅" : "❌")
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete All Transactions Result")
                        .font(AppFonts.overusedGroteskSemiBold(size: 16))
                        .foregroundColor(result.hasPrefix("✅") ? (AppColors.successForeground) : .red)
                    
                    Text(result)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Tab Item Arrays
    
    private var basicTabItems: [AppTabGroup.TabItem] {
        [
            AppTabGroup.TabItem(title: "Today", action: { print("Today selected") }),
            AppTabGroup.TabItem(title: "Week", action: { print("Week selected") }),
            AppTabGroup.TabItem(title: "Month", action: { print("Month selected") })
        ]
    }
    
    private var iconTabItems: [AppTabGroup.TabItem] {
        [
            AppTabGroup.TabItem(title: "All", leftIcon: "list.bullet"),
            AppTabGroup.TabItem(title: "Starred", leftIcon: "star.fill"),
            AppTabGroup.TabItem(title: "Recent", leftIcon: "clock"),
            AppTabGroup.TabItem(title: "Shared", leftIcon: "person.2")
        ]
    }
    
    // MARK: - Pull Data from Cloud Button
    
    /// Pull data from cloud button row
    func pullDataFromCloudRow() -> some View {
        Button(action: {
            // Show confirmation dialog before pulling data
            self.showingPullDataConfirmation = true
        }) {
            HStack(spacing: 12) {
                Text("⬇️")
                    .font(AppFonts.overusedGroteskMedium(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pull Data from Cloud")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(.primary)
                    
                    Text(pullDataSubtitle)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundStyle(pullDataTextColor)
                }
                
                Spacer()
                
                if isPullingData {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accentBackground))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(pullDataChevronColor)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!userManager.isFirebaseSyncEnabled || isPullingData)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Ultra RevenueCat Debugging
    
    /// Ultra-comprehensive RevenueCat debugging and paywall presentation
    private func showRevenueCatUltraDebug() {
        print("🎯 ULTRA DEBUG: ========== COMPREHENSIVE REVENUECAT ANALYSIS ==========")
        
        // 1. Environment Analysis
        print("🌍 ENVIRONMENT ANALYSIS:")
        print("   🔑 API Key Source: \(Config.revenueCatAPIKey?.prefix(15) ?? "nil")...")
        print("   🧪 Debug Build: \(isDebugBuild)")
        print("   📱 Current Environment: \(isDebugBuild ? "TEST/SANDBOX" : "PRODUCTION")")
        
        // 2. RevenueCat State
        print("💰 REVENUECAT STATE:")
        print("   📊 Offerings Loaded: \(revenueCatManager.offerings != nil)")
        print("   📈 Customer Info: \(revenueCatManager.customerInfo != nil)")
        print("   ✅ Subscription Active: \(revenueCatManager.isSubscriptionActive)")
        
        // 3. Detailed Offerings Analysis
        if let offerings = revenueCatManager.offerings {
            print("📦 DETAILED OFFERINGS ANALYSIS:")
            print("   📊 Total Offerings: \(offerings.all.count)")
            print("   🎯 Current Offering: '\(offerings.current?.identifier ?? "none")'")
            
            // List ALL available offerings with complete details
            for (identifier, offering) in offerings.all {
                print("   📋 OFFERING: '\(identifier)'")
                print("      📦 Packages: \(offering.availablePackages.count)")
                print("      📝 Description: '\(offering.serverDescription)'")
                print("      🏷️ Metadata: \(offering.metadata)")
                
                // List all packages in this offering
                for package in offering.availablePackages {
                    print("         🎁 Package: \(package.storeProduct.localizedTitle)")
                    print("         💰 Price: \(package.storeProduct.localizedPriceString)")
                    print("         🆔 ID: \(package.identifier)")
                    print("         🏪 Store ID: \(package.storeProduct.productIdentifier)")
                }
            }
        } else {
            print("❌ NO OFFERINGS LOADED!")
        }
        
        // 4. Target Offering Analysis
        print("🎯 TARGET OFFERING ANALYSIS:")
        print("   🔍 Looking for: 'Cashmonki'")
        print("   📍 Target found: \(revenueCatManager.targetOffering?.identifier ?? "NOT FOUND")")
        
        // 5. Show User-Friendly Offering Selection
        showOfferingSelectionAlert()
        
        // 6. Force Load and Try Paywall
        print("🔄 FORCE LOADING FRESH OFFERINGS...")
        Task {
            await revenueCatManager.loadOfferings()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.finalizePaywallPresentation()
            }
        }
    }
    
    /// Show offering selection alert for debugging
    private func showOfferingSelectionAlert() {
        guard let offerings = revenueCatManager.offerings else {
            print("⚠️ No offerings available for selection")
            return
        }
        
        print("🎮 OFFERING SELECTION:")
        print("   Available offerings to test:")
        for (index, identifier) in offerings.all.keys.enumerated() {
            print("   \(index + 1). '\(identifier)'")
        }
    }
    
    /// Finalize paywall presentation after all analysis
    private func finalizePaywallPresentation() {
        print("🚀 FINALIZING PAYWALL PRESENTATION:")
        
        if let target = revenueCatManager.targetOffering {
            print("✅ Using target offering: '\(target.identifier)'")
        } else if let first = revenueCatManager.offerings?.all.first?.value {
            print("⚠️ Using fallback offering: '\(first.identifier)'")
        } else {
            print("❌ NO OFFERINGS AVAILABLE AT ALL!")
        }
        
        print("🎬 PRESENTING PAYWALL SHEET...")
        showingNativePaywall = true
        print("🎯 ULTRA DEBUG: ====== END COMPREHENSIVE ANALYSIS ======")
    }
    
    /// Check if this is a debug build
    private var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - DEBUG: Duplicate Account Section

    private var duplicateAccountDebugSection: some View {
        DuplicateAccountDebugSection(authManager: authManager)
    }
    
    // MARK: - Support Functions

    /// Opens the App Store review prompt
    private func requestAppReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            print("⭐ Settings: App review request shown")
        }
    }

    /// Opens the user's default email app with support email pre-filled
    private func openSupportEmail() {
        let email = "dcardinesiii@gmail.com"
        let subject = "CashMonki Support Request"
        let body = "Hi there,\n\nI need help with my CashMonki app.\n\n"
        
        // Create mailto URL with pre-filled content
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        print("📧 Support Email: Attempting to open \(mailtoString)")
        
        if let mailtoURL = URL(string: mailtoString) {
            #if canImport(UIKit)
            // Check if the URL can be opened before attempting
            if UIApplication.shared.canOpenURL(mailtoURL) {
                print("📧 Support Email: Mail app available, opening...")
                UIApplication.shared.open(mailtoURL)
            } else {
                print("❌ Support Email: No mail app configured on device")
                // Fallback: copy email to clipboard
                UIPasteboard.general.string = email
                print("📧 Support Email: Email address copied to clipboard")
            }
            #else
            // For macOS or other platforms
            NSWorkspace.shared.open(mailtoURL)
            #endif
        } else {
            print("❌ Support Email: Failed to create mailto URL")
        }
    }

    /// Opens the user's Twitter/X profile for support chat
    private func openTwitterSupport() {
        let twitterURL = "https://x.com/dantecardines"

        print("🐦 Twitter Support: Attempting to open \(twitterURL)")

        if let url = URL(string: twitterURL) {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            print("🐦 Twitter Support: Opened X profile")
            #else
            NSWorkspace.shared.open(url)
            #endif
        } else {
            print("❌ Twitter Support: Failed to create URL")
        }
    }
}
