import SwiftUI
import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

extension Notification.Name {
    static let subscriptionSucceeded = Notification.Name("subscriptionSucceeded")
    static let subscriptionFailed = Notification.Name("subscriptionFailed")
}

struct CustomPaywallSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var showingManageBilling = false
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @EnvironmentObject var toastManager: ToastManager
    
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
            return selectedPlan == .yearly ? "$99.99/yr" : "$9.99/mo"
        }

        let priceString = package.storeProduct.localizedPriceString
        let periodString = selectedPlan == .yearly ? "/yr" : "/mo"
        return "\(priceString)\(periodString)"
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
                                    
                                    Text("Support indie app creators for the price of a few cups of coffee a month.")
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
                    print("🎯 PAYWALL DEBUG: Yearly tile TAPPED - changing selectedPlan from \(selectedPlan) to .yearly")
                    selectedPlan = .yearly
                    print("🎯 PAYWALL DEBUG: selectedPlan is now: \(selectedPlan)")
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
                    print("🎯 PAYWALL DEBUG: Monthly tile TAPPED - changing selectedPlan from \(selectedPlan) to .monthly")
                    selectedPlan = .monthly
                    print("🎯 PAYWALL DEBUG: selectedPlan is now: \(selectedPlan)")
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

                    Text(revenueCatManager.hasUsedTrialBefore ? "Cancel anytime" : "7 days free, then \(paymentTermsText)")
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                .frame(maxWidth: .infinity)

                // Restore Purchase link
                Button(action: {
                    restorePurchases()
                }) {
                    Text("Restore Purchase")
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, -8)
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
            .padding(.horizontal, 10)
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
                .environmentObject(toastManager)
        }
        .onAppear {
            Task {
                await ensureOfferingsLoaded()
            }
        }
    }
    
    // MARK: - Offerings Management
    private func ensureOfferingsLoaded() async {
        if revenueCatManager.offerings == nil {
            await revenueCatManager.loadOfferings()
        }
    }
    
    // MARK: - Purchase Handling
    private func restorePurchases() {
        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                let hasActiveEntitlements = customerInfo.entitlements.active.count > 0
                await revenueCatManager.forceRefreshCustomerInfo()

                await MainActor.run {
                    if hasActiveEntitlements {
                        print("✅ Restore successful - active entitlements found")
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                        }
                    } else {
                        print("ℹ️ Restore completed - no active purchases found")
                        toastManager.showSubscriptionError(message: "No previous purchases found")
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Restore failed: \(error.localizedDescription)")
                    toastManager.showSubscriptionError(message: "Restore failed. Please try again.")
                }
            }
        }
    }

    private func handleStartFreeTrial() {
        print("🎯 PAYWALL DEBUG: handleStartFreeTrial() called")
        print("🎯 PAYWALL DEBUG: Current selectedPlan = \(selectedPlan)")
        print("🎯 PAYWALL DEBUG: monthlyPackage = \(monthlyPackage?.storeProduct.productIdentifier ?? "nil")")
        print("🎯 PAYWALL DEBUG: yearlyPackage = \(yearlyPackage?.storeProduct.productIdentifier ?? "nil")")
        print("🎯 PAYWALL DEBUG: selectedPackage = \(selectedPackage?.storeProduct.productIdentifier ?? "nil")")

        Task {
            await ensureOfferingsLoaded()

            print("🎯 PAYWALL DEBUG: After ensureOfferingsLoaded - selectedPlan = \(selectedPlan)")
            print("🎯 PAYWALL DEBUG: After ensureOfferingsLoaded - selectedPackage = \(selectedPackage?.storeProduct.productIdentifier ?? "nil")")

            guard let package = selectedPackage else {
                await MainActor.run {
                    // Dismiss paywall first so toast appears on main view
                    isPresented = false
                    
                    // Show error toast instead of blocking alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🎯 PAYWALL: Posting subscription error notification - no package available")
                        NotificationCenter.default.post(
                            name: .subscriptionFailed, 
                            object: nil,
                            userInfo: ["errorMessage": "Subscription plans are not available. Please try again later."]
                        )
                    }
                }
                return
            }
            
            print("🎯 PAYWALL: Starting purchase for \(selectedPlan)")
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
                    print("❌ PAYWALL: Purchase failed")
                    
                    if let error = result.error {
                        let nsError = error as NSError
                        
                        // Check for user cancellation - don't show error dialog
                        let isUserCancellation = (nsError.domain == "SKErrorDomain" && nsError.code == 2) ||
                                                (nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 1) ||
                                                (nsError.domain == "SKErrorDomain" && nsError.code == 19) ||
                                                error.localizedDescription.lowercased().contains("cancel")
                        
                        if isUserCancellation {
                            print("👤 PAYWALL: User cancelled")
                            return
                        }
                        
                        // Show user-friendly error message
                        let errorMessage: String
                        if nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 10 {
                            errorMessage = "Network error. Please check your connection and try again."
                        } else {
                            errorMessage = "Something went wrong with your subscription. Please try again later."
                        }
                        
                        // Dismiss paywall first so toast appears on main view
                        isPresented = false
                        
                        // Show error toast instead of blocking alert
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("🎯 PAYWALL: Posting subscription error notification")
                            NotificationCenter.default.post(
                                name: .subscriptionFailed, 
                                object: nil,
                                userInfo: ["errorMessage": errorMessage]
                            )
                        }
                    } else {
                        return // No error object, likely user cancellation
                    }
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