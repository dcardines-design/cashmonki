import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

struct ManageBillingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @EnvironmentObject var toastManager: ToastManager
    @State private var isLoading = false

    // Restore purchase alert states
    @State private var showingRestoreSuccessAlert = false
    @State private var showingRestoreNoPurchasesAlert = false
    @State private var showingRestoreErrorAlert = false
    @State private var restoreErrorMessage = ""
    
    #if DEBUG
    // Debug state management
    enum DebugSubscriptionState {
        case freePlan, trialMonthly, trialYearly, subscribedMonthly, subscribedYearly
    }
    @State private var debugState: DebugSubscriptionState? = nil  // Changed from .freePlan to nil
    #endif
    
    // MARK: - Subscription State Management
    enum SubscriptionState {
        case freePlan           // No subscription, never had trial
        case trialActive        // Currently in free trial
        case trialLapsed        // Trial ended, no active subscription
        case subscribedRegular  // Active paid subscription
    }
    
    private var subscriptionState: SubscriptionState {
        #if DEBUG
        // Use debug state when available
        if let debugState = debugState {
            switch debugState {
            case .freePlan:
                return .freePlan
            case .trialMonthly, .trialYearly:
                return .trialActive
            case .subscribedMonthly, .subscribedYearly:
                return .subscribedRegular
            }
        }
        #endif
        
        let hasActiveSubscription = revenueCatManager.isProUser
        let hasUsedTrialBefore = revenueCatManager.hasUsedTrialBefore

        if isTrialActive {
            return .trialActive
        } else if hasActiveSubscription {
            return .subscribedRegular
        } else if hasUsedTrialBefore {
            return .trialLapsed
        } else {
            return .freePlan
        }
    }
    
    // MARK: - Subscription Info Helpers
    private var currentSubscription: EntitlementInfo? {
        return revenueCatManager.customerInfo?.entitlements.active.values.first
    }
    
    private var planTitle: String {
        #if DEBUG
        // Use debug state when available
        if let debugState = debugState {
            switch debugState {
            case .freePlan:
                return "Free"
            case .trialMonthly, .subscribedMonthly:
                return "Pro Monthly"
            case .trialYearly, .subscribedYearly:
                return "Pro Annual"
            }
        }
        #endif
        
        // Use RevenueCat entitlement info
        if let subscription = currentSubscription {
            return subscription.productIdentifier.contains("yearly") ? "Pro Annual" : "Pro Monthly"
        }
        
        return "Free"
    }
    
    private var planPrice: String {
        guard let subscription = currentSubscription else { return "Free" }
        
        if subscription.productIdentifier.contains("yearly") {
            return "$99.99 / year"
        } else {
            return "$9.99 / month"
        }
    }
    
    private var priceAmount: String {
        #if DEBUG
        // Use debug state when available
        if let debugState = debugState {
            switch debugState {
            case .freePlan:
                return "US$0.00"
            case .trialMonthly, .subscribedMonthly:
                return "US$9.99"
            case .trialYearly, .subscribedYearly:
                return "US$99.99"
            }
        }
        #endif
        
        // Use RevenueCat entitlement info
        if let subscription = currentSubscription {
            return subscription.productIdentifier.contains("yearly") ? "US$99.99" : "US$9.99"
        }
        
        return "US$0.00"
    }
    
    private var pricePeriod: String {
        #if DEBUG
        // Use debug state when available
        if let debugState = debugState {
            switch debugState {
            case .freePlan:
                return ""
            case .trialMonthly, .subscribedMonthly:
                return " / month"
            case .trialYearly, .subscribedYearly:
                return " / year"
            }
        }
        #endif
        
        // Use RevenueCat entitlement info
        if let subscription = currentSubscription {
            return subscription.productIdentifier.contains("yearly") ? " / year" : " / month"
        }
        
        return ""
    }
    
    private var isTrialActive: Bool {
        #if DEBUG
        // Use debug state when available
        if let debugState = debugState {
            switch debugState {
            case .freePlan, .subscribedMonthly, .subscribedYearly:
                return false
            case .trialMonthly, .trialYearly:
                return true
            }
        }
        #endif
        
        guard let subscription = currentSubscription else { return false }
        return subscription.periodType == .trial
    }
    
    private var trialEndDate: String {
        // Use RevenueCat subscription data
        if let subscription = currentSubscription,
           let originalPurchaseDate = subscription.originalPurchaseDate {
            
            if let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: originalPurchaseDate) {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                return formatter.string(from: trialEnd)
            }
        }
        
        // Default fallback for testing
        return "December 5, 2025"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with surface color background
            SheetHeader.withCustomBackground(
                title: "Manage Billing",
                onBackTap: { isPresented = false },
                backgroundColor: AppColors.surfacePrimary
            )
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Billing card container
                    VStack(spacing: 0) {
                        // Billing card section
                        VStack(alignment: .leading, spacing: 4) {
                            // Current Plan label
                            Text("Current Plan")
                                .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                .foregroundColor(AppColors.foregroundSecondary)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 8) {
                                        Text(planTitle)
                                            .font(Font.custom("Overused Grotesk", size: 20).weight(.semibold))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(AppColors.foregroundPrimary)
                                        
                                        if isTrialActive {
                                            Text("1 week trial")
                                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                                .foregroundColor(AppColors.backgroundWhite)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(AppColors.successForeground)
                                                .cornerRadius(12)
                                        }
                                    }
                                    
                                    // Only show billing information for trial active and subscribed users
                                    if subscriptionState == .trialActive || subscriptionState == .subscribedRegular {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(isTrialActive ? "Trial ends" : "Next billing")
                                                .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                                .foregroundColor(AppColors.foregroundSecondary)
                                            
                                            Text(trialEndDate)
                                                .font(Font.custom("Overused Grotesk", size: 16).weight(.semibold))
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(AppColors.foregroundPrimary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Price breakdown - show US$0.00 for free, actual price for others
                                HStack(spacing: 0) {
                                    Text(priceAmount)
                                        .font(Font.custom("Overused Grotesk", size: 20).weight(.medium))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppColors.foregroundPrimary)
                                    
                                    if subscriptionState != .freePlan {
                                        Text(pricePeriod)
                                            .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(AppColors.foregroundSecondary)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(AppColors.backgroundWhite)
                    }
                    .background(AppColors.backgroundWhite)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Action Items - grouped together like settings buttons
                    VStack(spacing: 0) {
                        // Manage Subscription
                        Button(action: {
                            openAppleSubscriptionManagement()
                        }) {
                            HStack(spacing: 12) {
                                Text("⚙️")
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Manage Subscription")
                                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                                        .foregroundColor(AppColors.foregroundPrimary)
                                    
                                    Text("Change plan, cancel, or update payment")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(AppColors.foregroundSecondary)
                                }
                                
                                Spacer()
                                
                                AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                                    .font(AppFonts.overusedGroteskMedium(size: 14))
                                    .foregroundStyle(AppColors.foregroundSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .padding(.leading, 52)
                        
                        // Already Purchased / Restore Purchases
                        Button(action: {
                            restorePurchases()
                        }) {
                            HStack(spacing: 12) {
                                Text("🛒")
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Already Purchased?")
                                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                                        .foregroundColor(AppColors.foregroundPrimary)
                                    
                                    Text("Restore purchases made on another device")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(AppColors.foregroundSecondary)
                                }
                                
                                Spacer()
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                                        .font(AppFonts.overusedGroteskMedium(size: 14))
                                        .foregroundStyle(AppColors.foregroundSecondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoading)
                        
                        Divider()
                            .padding(.leading, 52)
                        
                        // Contact Support
                        Button(action: {
                            openSupportEmail()
                        }) {
                            HStack(spacing: 12) {
                                Text("😁")
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Need Customer Support?")
                                        .font(Font.custom("Overused Grotesk", size: 16).weight(.medium))
                                        .foregroundColor(AppColors.foregroundPrimary)
                                    
                                    Text("Get help with your account")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(AppColors.foregroundSecondary)
                                }
                                
                                Spacer()
                                
                                AppIcon(assetName: "chevron-right", fallbackSystemName: "chevron.right")
                                    .font(AppFonts.overusedGroteskMedium(size: 14))
                                    .foregroundStyle(AppColors.foregroundSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .background(AppColors.backgroundWhite)
                    .cornerRadius(16)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    
                    // Debug Controls - only show in DEBUG builds
                    #if DEBUG
                    VStack(spacing: 0) {
                        Text("Debug Subscription States")
                            .font(Font.custom("Overused Grotesk", size: 16).weight(.semibold))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .padding(.vertical, 12)
                        
                        // RevenueCat Subscription Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("🎯 RevenueCat Subscription: \(revenueCatManager.isSubscriptionActive ? "ACTIVE" : "INACTIVE")")
                                .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                .foregroundColor(revenueCatManager.isSubscriptionActive ? .green : .red)
                            
                            if let subscription = currentSubscription {
                                Text("📱 Product ID: \(subscription.productIdentifier)")
                                    .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.surfaceSecondary)
                        .cornerRadius(8)
                        .padding(.bottom, 12)
                        
                        debugButton("🆓 Free Plan") {
                            debugSetState(.freePlan)
                        }
                        
                        debugButton("📅 Trial Monthly") {
                            debugSetState(.trialMonthly)
                        }
                        
                        debugButton("📆 Trial Yearly") {
                            debugSetState(.trialYearly)
                        }
                        
                        debugButton("💳 Subscribed Monthly") {
                            debugSetState(.subscribedMonthly)
                        }
                        
                        debugButton("💰 Subscribed Yearly") {
                            debugSetState(.subscribedYearly)
                        }
                        
                        debugButton("🔄 Refresh Subscription Status") {
                            Task {
                                await revenueCatManager.forceRefreshCustomerInfo()
                            }
                        }
                        
                        debugButton("📆 Force Yearly Trial") {
                            debugSetState(.trialYearly)
                        }
                        
                        // RevenueCat Testing buttons
                        Text("RevenueCat Debug States:")
                            .font(Font.custom("Overused Grotesk", size: 14).weight(.semibold))
                            .foregroundColor(AppColors.successForeground)
                            .padding(.top, 12)
                        
                        debugButton("💰 Force Monthly Subscription") {
                            debugSetState(.subscribedMonthly)
                        }
                        
                        debugButton("📅 Force Yearly Subscription") {
                            debugSetState(.subscribedYearly)
                        }
                        
                        debugButton("🆓 Clear Debug State") {
                            debugState = nil
                            print("🔧 BILLING: Debug state cleared - using real RevenueCat data")
                        }
                    }
                    .background(AppColors.backgroundWhite)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    #endif
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.top, 0)
            }
            
            // Footer
            VStack(spacing: 8) {
                Text("Made with ☕️ & ♥️ by")
                    .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Text("Rosebud Studio")
                    .font(Font.custom("Overused Grotesk", size: 14).weight(.semibold))
                    .foregroundColor(AppColors.foregroundPrimary)
            }
            .padding(.bottom, 20)
        }
        .background(AppColors.surfacePrimary)
        // MARK: - Restore Purchase Alerts
        .alert("Purchases Restored!", isPresented: $showingRestoreSuccessAlert) {
            Button("OK") {
                // Auto-dismiss the billing sheet after successful restore
                isPresented = false
            }
        } message: {
            Text("Your subscription has been restored successfully. Enjoy your premium features!")
        }
        .alert("No Purchases Found", isPresented: $showingRestoreNoPurchasesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We couldn't find any previous purchases for this Apple ID.\n\nMake sure you're signed in with the same Apple ID you used to make the original purchase.")
        }
        .alert("Restore Failed", isPresented: $showingRestoreErrorAlert) {
            Button("Try Again") {
                restorePurchases()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Unable to restore purchases. Please check your internet connection and try again.\n\n\(restoreErrorMessage)")
        }
    }

    // MARK: - Actions
    private func openAppleSubscriptionManagement() {
        #if canImport(UIKit)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    private func restorePurchases() {
        isLoading = true

        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()

                // Check if any entitlements were restored
                let hasActiveEntitlements = customerInfo.entitlements.active.count > 0

                // Refresh subscription status via RevenueCatManager
                await revenueCatManager.forceRefreshCustomerInfo()

                await MainActor.run {
                    isLoading = false
                    print("✅ BILLING: Purchases restored successfully")

                    if hasActiveEntitlements {
                        // Show success alert and auto-dismiss after
                        print("✅ BILLING: Active entitlements found - subscription restored")
                        showingRestoreSuccessAlert = true
                    } else {
                        // No purchases to restore - show helpful message
                        print("ℹ️ BILLING: No active entitlements found")
                        showingRestoreNoPurchasesAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ BILLING: Failed to restore purchases: \(error.localizedDescription)")

                    // Show error alert
                    restoreErrorMessage = error.localizedDescription
                    showingRestoreErrorAlert = true
                }
            }
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
            #endif
        } else {
            print("❌ Support Email: Failed to create mailto URL")
        }
    }
    
    #if DEBUG
    // MARK: - Debug Functions
    private func debugSetState(_ state: DebugSubscriptionState) {
        debugState = state
        print("🐛 DEBUG: Set subscription state to \(state)")
    }
    
    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                .foregroundColor(AppColors.foregroundPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(AppColors.surfacePrimary)
                .cornerRadius(8)
        }
    }
    #endif
}



// MARK: - Preview
#Preview {
    ManageBillingSheet(isPresented: .constant(true))
}