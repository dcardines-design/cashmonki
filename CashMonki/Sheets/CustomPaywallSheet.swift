import SwiftUI
import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

extension Notification.Name {
    static let subscriptionSucceeded = Notification.Name("subscriptionSucceeded")
}

struct CustomPaywallSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var showingManageBilling = false
    @State private var showingSubscriptionError = false
    @State private var subscriptionErrorMessage = ""
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    
    // MARK: - RevenueCat Package Helpers
    private var targetOffering: Offering? {
        revenueCatManager.targetOffering
    }
    
    private var monthlyPackage: Package? {
        guard let offering = targetOffering else { return nil }
        return offering.availablePackages.first { package in
            package.storeProduct.productIdentifier.contains("monthly") ||
            package.packageType == .monthly
        }
    }
    
    private var yearlyPackage: Package? {
        guard let offering = targetOffering else { 
            print("🎯 PAYWALL: No target offering available")
            return nil 
        }
        
        // Debug: Print all available packages
        print("🎯 PAYWALL: Available packages:")
        for package in offering.availablePackages {
            print("   📦 \(package.storeProduct.productIdentifier) - \(package.packageType) - \(package.storeProduct.localizedTitle)")
        }
        
        let yearlyPkg = offering.availablePackages.first { package in
            let identifier = package.storeProduct.productIdentifier.lowercased()
            // Prioritize product identifier over packageType (since packageType can be wrong in test environments)
            return identifier.contains("yearly") || 
                   identifier.contains("annual") ||
                   identifier.hasSuffix("_yearly") ||
                   identifier.contains("_pro_yearly") ||
                   identifier.contains("test_cashmonki_pro_yearly") // Exact test environment match
        }
        
        if let pkg = yearlyPkg {
            print("✅ PAYWALL: Found yearly package: \(pkg.storeProduct.productIdentifier)")
        } else {
            print("❌ PAYWALL: No yearly package found")
        }
        
        return yearlyPkg
    }
    
    private var selectedPackage: Package? {
        switch selectedPlan {
        case .monthly:
            return monthlyPackage
        case .yearly:
            return yearlyPackage
        }
    }
    
    private var paymentTermsText: String {
        guard let package = selectedPackage else {
            return selectedPlan == .yearly ? "$99.99 a year" : "$9.99 a month"
        }
        
        let priceString = package.storeProduct.localizedPriceString
        let periodString = selectedPlan == .yearly ? "a year" : "a month"
        return "\(priceString) \(periodString)"
    }
    
    private func getYearlyPriceString() -> String {
        // Ensure yearly pricing is always $99.99
        guard let package = yearlyPackage else {
            return "$99.99"
        }
        
        let priceString = package.storeProduct.localizedPriceString
        print("🎯 PAYWALL: Yearly package price: \(priceString)")
        
        // If RevenueCat returns incorrect price, use fallback
        if priceString.contains("9.99") && !priceString.contains("99.99") {
            print("⚠️ PAYWALL: Incorrect yearly price detected, using fallback $99.99")
            return "$99.99"
        }
        
        return priceString
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Scrollable content area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                    
                    // Top padding to account for fixed close button
                    Spacer()
                        .frame(height: 32)
                    
                    // Content area with Cashmonki Pro text image
                    VStack(spacing: 24) {
                        // Header image - different for lapsed trial users
                        Image(revenueCatManager.hasUsedTrialBefore ? "cashmonki-pro-text-trial-ended" : "cashmonki-pro-text")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                        
                        // Value props section
                        VStack(spacing: 24) {
                            // Unlimited AI Scans feature
                            HStack(alignment: .top, spacing: 16) {
                                // Sparkle icon container
                                VStack(alignment: .center, spacing: 10) {
                                    Text("✨")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 26)
                                                .weight(.medium)
                                        )
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppColors.foregroundWhite)
                                }
                                .padding(8)
                                .frame(width: 46, height: 46, alignment: .center)
                                .background(.white.opacity(0.05))
                                .cornerRadius(200)
                                
                                // Text content
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Unlimited AI Scans")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 18)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                    
                                    Text("Snap and let AI handle everything, no typing, no hassle.")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 16)
                                                .weight(.medium)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .opacity(0.7)
                                }
                                
                                Spacer()
                            }
                            
                            // Unlimited Custom Categories feature
                            HStack(alignment: .top, spacing: 16) {
                                // Chart icon container
                                VStack(alignment: .center, spacing: 10) {
                                    Text("📊")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 26)
                                                .weight(.medium)
                                        )
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppColors.foregroundWhite)
                                }
                                .padding(8)
                                .frame(width: 46, height: 46, alignment: .center)
                                .background(.white.opacity(0.05))
                                .cornerRadius(200)
                                
                                // Text content
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Unlimited Custom Categories")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 18)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                    
                                    Text("Create categories that actually match your life.")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 16)
                                                .weight(.medium)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .opacity(0.7)
                                }
                                
                                Spacer()
                            }
                            
                            // Multiple Accounts feature
                            HStack(alignment: .top, spacing: 16) {
                                // Briefcase icon container
                                VStack(alignment: .center, spacing: 10) {
                                    Text("💼")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 26)
                                                .weight(.medium)
                                        )
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppColors.foregroundWhite)
                                }
                                .padding(8)
                                .frame(width: 46, height: 46, alignment: .center)
                                .background(.white.opacity(0.05))
                                .cornerRadius(200)
                                
                                // Text content
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Multiple Accounts")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 18)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                    
                                    Text("Switch easily between personal and business accounts.")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 16)
                                                .weight(.medium)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .opacity(0.7)
                                }
                                
                                Spacer()
                            }
                            
                            // Support Indie feature
                            HStack(alignment: .top, spacing: 16) {
                                // Smiling face icon container
                                VStack(alignment: .center, spacing: 10) {
                                    Text("😌")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 26)
                                                .weight(.medium)
                                        )
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppColors.foregroundWhite)
                                }
                                .padding(8)
                                .frame(width: 46, height: 46, alignment: .center)
                                .background(.white.opacity(0.05))
                                .cornerRadius(200)
                                
                                // Text content
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Support Indie")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 18)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                    
                                    Text("Support indie app creators just for 3 cups of coffee a month.")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 16)
                                                .weight(.medium)
                                        )
                                        .foregroundColor(AppColors.foregroundWhite)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .opacity(0.7)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Bottom padding to ensure content doesn't hide behind sticky container
                    Spacer()
                        .frame(height: 20)
                }
            }
            
            // Fixed/Sticky price plan container at bottom
            VStack(alignment: .leading, spacing: 14) {
                // Yearly pricing plan tile
                Button(action: {
                    selectedPlan = .yearly
                }) {
                    HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Yearly")
                                .font(
                                    Font.custom("Overused Grotesk", size: 14)
                                        .weight(.semibold)
                                )
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            
                            Text("Get 2 months free!")
                                .font(
                                    Font.custom("Overused Grotesk", size: 14)
                                        .weight(.semibold)
                                )
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.successForeground)
                        }
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(getYearlyPriceString())
                                .font(
                                    Font.custom("Overused Grotesk", size: 20)
                                        .weight(.medium)
                                )
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            
                            Text("/ year")
                                .font(
                                    Font.custom("Overused Grotesk", size: 12)
                                        .weight(.medium)
                                )
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                    }
                    
                    Spacer()
                    
                        // Selection indicator 
                        Circle()
                            .fill(selectedPlan == .yearly ? AppColors.accentBackground : AppColors.surfacePrimary)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Group {
                                    if selectedPlan == .yearly {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Circle()
                                            .stroke(AppColors.linePrimary, lineWidth: 1)
                                    }
                                }
                            )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .top)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .white, location: 0.00),
                            Gradient.Stop(color: Color(red: 0.98, green: 0.98, blue: 1), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.05), radius: 1, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .inset(by: 0.5)
                        .stroke(selectedPlan == .yearly ? AppColors.accentBackground : AppColors.line1stLine, lineWidth: 1)
                )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Monthly pricing plan tile
                Button(action: {
                    selectedPlan = .monthly
                }) {
                    HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly")
                            .font(
                                Font.custom("Overused Grotesk", size: 14)
                                    .weight(.semibold)
                            )
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppColors.foregroundPrimary)
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(monthlyPackage?.storeProduct.localizedPriceString ?? "$9.99")
                                .font(
                                    Font.custom("Overused Grotesk", size: 20)
                                        .weight(.medium)
                                )
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundPrimary)
                            
                            Text("/ month")
                                .font(
                                    Font.custom("Overused Grotesk", size: 12)
                                        .weight(.medium)
                                )
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                    }
                    
                    Spacer()
                    
                        // Selection indicator
                        Circle()
                            .fill(selectedPlan == .monthly ? AppColors.accentBackground : AppColors.surfacePrimary)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Group {
                                    if selectedPlan == .monthly {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Circle()
                                            .stroke(AppColors.linePrimary, lineWidth: 1)
                                    }
                                }
                            )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .top)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .white, location: 0.00),
                            Gradient.Stop(color: Color(red: 0.98, green: 0.98, blue: 1), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.05), radius: 1, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .inset(by: 0.5)
                        .stroke(selectedPlan == .monthly ? AppColors.accentBackground : AppColors.line1stLine, lineWidth: 1)
                )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Primary button - changes based on subscription status
                if revenueCatManager.isProUser {
                    AppButton.secondary("Manage Billing", size: .extraSmall) {
                        showingManageBilling = true
                    }
                } else {
                    // Different button text for lapsed trial users
                    let buttonText = revenueCatManager.hasUsedTrialBefore ? "Continue with Pro" : "Start my free week"
                    AppButton.primary(buttonText, size: .extraSmall) {
                        handleStartFreeTrial()
                    }
                }
                
                // Payment terms text - different for lapsed trial users
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                    
                    Text(revenueCatManager.hasUsedTrialBefore ? "Secure checkout" : "No payment now")
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.foregroundSecondary)
                    
                    Text("•")
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.foregroundSecondary)
                    
                    Text(revenueCatManager.hasUsedTrialBefore ? "Cancel anytime" : "Free 7 days then \(paymentTermsText)")
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.white)
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .inset(by: 0.5)
                    .stroke(AppColors.line1stLine, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 0)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            }
            
            // Fixed close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.foregroundSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surfacePrimary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .background(
            ZStack {
                // Fallback background color
                Color(red: 0.95, green: 0.95, blue: 0.98)
                    .ignoresSafeArea()
                
                // Background image - aligned to top
                Image("paywall-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
            }
        )
        .animation(.easeInOut(duration: 0.2), value: selectedPlan)
        .fullScreenCover(isPresented: $showingManageBilling) {
            ManageBillingSheet(isPresented: $showingManageBilling)
        }
        .onAppear {
            print("🍞 PAYWALL: CustomPaywallSheet appeared")
        }
        .alert("Subscription Error", isPresented: $showingSubscriptionError) {
            Button("Try Again") {
                print("🔄 PAYWALL: User tapped Try Again on subscription error alert")
                showingSubscriptionError = false
            }
            Button("Cancel", role: .cancel) {
                print("❌ PAYWALL: User tapped Cancel on subscription error alert")
                showingSubscriptionError = false
            }
        } message: {
            Text(subscriptionErrorMessage)
        }
    }
    
    // MARK: - Purchase Handling
    private func handleStartFreeTrial() {
        print("🎯 === PAYWALL PURCHASE START ===")
        print("🎯 PAYWALL: handleStartFreeTrial() called")
        print("🎯 PAYWALL: Selected plan: \(selectedPlan)")
        print("🎯 PAYWALL: Yearly package: \(yearlyPackage?.storeProduct.productIdentifier ?? "nil")")
        print("🎯 PAYWALL: Monthly package: \(monthlyPackage?.storeProduct.productIdentifier ?? "nil")")
        
        guard let package = selectedPackage else {
            print("❌ PAYWALL: No package selected for plan: \(selectedPlan)")
            return
        }
        
        print("🎯 PAYWALL: Starting purchase for \(package.storeProduct.productIdentifier) - \(package.storeProduct.localizedTitle)")
        print("🎯 PAYWALL: About to start async Task...")
        
        Task {
            let result = await revenueCatManager.purchase(package: package)
            
            await MainActor.run {
                if result.success {
                    print("🎉 PAYWALL: Purchase successful!")
                    print("✅ SUBSCRIPTION SUCCESS DEBUG: CustomPaywall purchase successful")
                    
                    // Dismiss paywall immediately so toast appears on main view
                    isPresented = false
                    
                    // Notify main view to show subscription success toast
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🎯 PAYWALL: Posting subscription success notification")
                        NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                    }
                } else {
                    print("❌ PAYWALL: Purchase failed: \(result.error?.localizedDescription ?? "Unknown error")")
                    print("🚨 SUBSCRIPTION ERROR DEBUG: CustomPaywall failure triggered")
                    print("🚨 ERROR DETAILS: \(result.error?.localizedDescription ?? "Unknown error")")
                    
                    // Enhanced error debugging
                    if let error = result.error {
                        let nsError = error as NSError
                        print("🚨 === DETAILED ERROR BREAKDOWN ===")
                        print("🚨 ERROR CODE: \(nsError.code)")
                        print("🚨 ERROR DOMAIN: \(nsError.domain)")
                        print("🚨 ERROR DESCRIPTION: \(error.localizedDescription)")
                        print("🚨 ERROR USER INFO: \(nsError.userInfo)")
                        
                        // Check if this is a user cancellation - DON'T show dialog for these
                        let isUserCancellation = (nsError.domain == "SKErrorDomain" && nsError.code == 2) ||
                                                (nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 1) ||
                                                (nsError.domain == "SKErrorDomain" && nsError.code == 19) // Overlay cancelled
                        
                        if isUserCancellation {
                            print("👤 PAYWALL: User cancelled subscription - no dialog needed")
                            return // Exit early, don't show any dialog
                        }
                        
                        // Check for specific RevenueCat error types
                        if nsError.domain == "RevenueCat.ErrorDomain" {
                            print("🚨 REVENUECAT ERROR DETECTED")
                            switch nsError.code {
                            case 0:
                                print("🚨 RevenueCat Error: Unknown error")
                            case 1:
                                print("🚨 RevenueCat Error: Purchase cancelled by user")
                            case 2:
                                print("🚨 RevenueCat Error: Store problem")
                            case 3:
                                print("🚨 RevenueCat Error: Purchase not allowed")
                            case 4:
                                print("🚨 RevenueCat Error: Purchase invalid")
                            case 5:
                                print("🚨 RevenueCat Error: Product not available for purchase")
                            case 6:
                                print("🚨 RevenueCat Error: Product already purchased")
                            case 7:
                                print("🚨 RevenueCat Error: Receipt already in use")
                            case 8:
                                print("🚨 RevenueCat Error: Invalid receipt")
                            case 9:
                                print("🚨 RevenueCat Error: Missing receipt file")
                            case 10:
                                print("🚨 RevenueCat Error: Network error")
                            case 11:
                                print("🚨 RevenueCat Error: Invalid credentials")
                            case 12:
                                print("🚨 RevenueCat Error: Unexpected backend response error")
                            case 13:
                                print("🚨 RevenueCat Error: Receipt in use by other subscriber")
                            case 14:
                                print("🚨 RevenueCat Error: Invalid subscriber")
                            case 15:
                                print("🚨 RevenueCat Error: Operation already in progress")
                            case 16:
                                print("🚨 RevenueCat Error: Unknown backend error")
                            case 17:
                                print("🚨 RevenueCat Error: Invalid Apple subscription key")
                            case 18:
                                print("🚨 RevenueCat Error: Ineligible error")
                            case 19:
                                print("🚨 RevenueCat Error: Insufficient permissions")
                            case 20:
                                print("🚨 RevenueCat Error: Payment pending")
                            case 21:
                                print("🚨 RevenueCat Error: Invalid subscriber attributes")
                            case 22:
                                print("🚨 RevenueCat Error: Logout called")
                            case 23:
                                print("🚨 RevenueCat Error: Configuration error")
                            case 24:
                                print("🚨 RevenueCat Error: Unsupported error")
                            case 25:
                                print("🚨 RevenueCat Error: Empty subscriber attributes")
                            case 26:
                                print("🚨 RevenueCat Error: Product request timeout")
                            default:
                                print("🚨 RevenueCat Error: Unknown error code \(nsError.code)")
                            }
                        }
                        
                        // Check for StoreKit error types
                        if nsError.domain == "SKErrorDomain" {
                            print("🚨 STOREKIT ERROR DETECTED")
                            switch nsError.code {
                            case 0:
                                print("🚨 StoreKit Error: Unknown error")
                            case 1:
                                print("🚨 StoreKit Error: Client invalid")
                            case 2:
                                print("🚨 StoreKit Error: Payment cancelled")
                            case 3:
                                print("🚨 StoreKit Error: Payment invalid")
                            case 4:
                                print("🚨 StoreKit Error: Payment not allowed")
                            case 5:
                                print("🚨 StoreKit Error: Store product not available")
                            case 6:
                                print("🚨 StoreKit Error: Cloud service permission denied")
                            case 7:
                                print("🚨 StoreKit Error: Cloud service network connection failed")
                            case 8:
                                print("🚨 StoreKit Error: Cloud service revoked")
                            case 9:
                                print("🚨 StoreKit Error: Privacy acknowledgement required")
                            case 10:
                                print("🚨 StoreKit Error: Unauthorized request")
                            case 11:
                                print("🚨 StoreKit Error: Invalid offer identifier")
                            case 12:
                                print("🚨 StoreKit Error: Invalid signature")
                            case 13:
                                print("🚨 StoreKit Error: Missing offer params")
                            case 14:
                                print("🚨 StoreKit Error: Invalid offer price")
                            case 15:
                                print("🚨 StoreKit Error: Overlay dismissed")
                            case 16:
                                print("🚨 StoreKit Error: Overlay timeout")
                            case 17:
                                print("🚨 StoreKit Error: Ineligible for offer")
                            case 18:
                                print("🚨 StoreKit Error: Unsupported platform")
                            case 19:
                                print("🚨 StoreKit Error: Overlay cancelled")
                            default:
                                print("🚨 StoreKit Error: Unknown error code \(nsError.code)")
                            }
                        }
                        print("🚨 ==============================")
                        
                        // Show iOS native alert for non-cancellation errors only
                        print("🚨 PAYWALL: Showing native iOS alert for subscription error")
                        let errorMessage: String
                        
                        if nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 10 {
                            errorMessage = "Network error. Please check your connection and try again."
                        } else {
                            errorMessage = "Something went wrong with your subscription. Please try again later."
                        }
                        
                        subscriptionErrorMessage = errorMessage
                        showingSubscriptionError = true
                    } else {
                        print("🚨 NO ERROR OBJECT PROVIDED")
                        subscriptionErrorMessage = "Unable to process subscription. Please try again."
                        showingSubscriptionError = true
                    }
                    
                    print("🔄 PAYWALL: Keeping paywall open for user retry")
                }
            }
        }
    }
}

// MARK: - Supporting Types
enum PricingPlan: CaseIterable {
    case monthly
    case yearly
}

// MARK: - Preview
#Preview {
    CustomPaywallSheet(isPresented: .constant(true))
}