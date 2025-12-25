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
    @State private var isDismissing = false // Prevents UI re-render during dismissal
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
        guard let offering = targetOffering else { return nil }

        return offering.availablePackages.first { package in
            let identifier = package.storeProduct.productIdentifier.lowercased()
            return identifier.contains("yearly") ||
                   identifier.contains("annual") ||
                   identifier.hasSuffix("_yearly") ||
                   identifier.contains("_pro_yearly") ||
                   identifier.contains("test_cashmonki_pro_yearly")
        }
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
        guard let package = yearlyPackage else { return "$99.99" }
        let priceString = package.storeProduct.localizedPriceString
        // If RevenueCat returns incorrect price, use fallback
        if priceString.contains("9.99") && !priceString.contains("99.99") {
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
                                    Font.custom("Overused Grotesk", size: 24)
                                        .weight(.bold)
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
                                    Font.custom("Overused Grotesk", size: 24)
                                        .weight(.bold)
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
                // Use isDismissing to prevent showing "Manage Billing" during dismissal animation
                let _ = print("🎫 PAYWALL BUTTON DEBUG: isProUser=\(revenueCatManager.isProUser), isDismissing=\(isDismissing), hasUsedTrialBefore=\(revenueCatManager.hasUsedTrialBefore)")
                if revenueCatManager.isProUser && !isDismissing {
                    let _ = print("🎫 PAYWALL: Showing 'Manage Billing' button")
                    AppButton.secondary("Manage Billing", size: .extraSmall) {
                        showingManageBilling = true
                    }
                } else if !isDismissing {
                    // Different button text for lapsed trial users
                    let buttonText = revenueCatManager.hasUsedTrialBefore ? "Continue with Pro" : "Start my free week"
                    let _ = print("🎫 PAYWALL: Showing '\(buttonText)' button")
                    AppButton.primary(buttonText, size: .extraSmall) {
                        handleStartFreeTrial()
                    }
                } else {
                    let _ = print("🎫 PAYWALL: ⚠️ NO BUTTON SHOWN - isDismissing=\(isDismissing)")
                }
                
                // Payment terms text - different for lapsed trial users
                HStack(spacing: 4) {
                    Text(revenueCatManager.hasUsedTrialBefore ? "Secure checkout  •  Cancel anytime" : "7 days free, then \(paymentTermsText)  •  Cancel anytime")
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.foregroundSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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
            print("🎫 ======= PAYWALL APPEARED =======")
            print("🎫 PAYWALL onAppear: isProUser=\(revenueCatManager.isProUser)")
            print("🎫 PAYWALL onAppear: isDismissing=\(isDismissing)")
            print("🎫 PAYWALL onAppear: hasUsedTrialBefore=\(revenueCatManager.hasUsedTrialBefore)")
            print("🎫 PAYWALL onAppear: customerInfo=\(revenueCatManager.customerInfo != nil ? "loaded" : "nil")")
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
                        isDismissing = true // Prevent UI from showing "Manage Billing"
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                        }
                    } else {
                        toastManager.showSubscriptionError(message: "No previous purchases found")
                    }
                }
            } catch {
                await MainActor.run {
                    toastManager.showSubscriptionError(message: "Restore failed. Please try again.")
                }
            }
        }
    }

    private func handleStartFreeTrial() {
        print("🎫 ======= handleStartFreeTrial CALLED =======")
        Task {
            await ensureOfferingsLoaded()

            guard let package = selectedPackage else {
                print("🎫 PURCHASE: ❌ No package selected")
                await MainActor.run {
                    isDismissing = true // Prevent any UI state changes during dismissal
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(
                            name: .subscriptionFailed,
                            object: nil,
                            userInfo: ["errorMessage": "Subscription plans are not available. Please try again later."]
                        )
                    }
                }
                return
            }

            print("🎫 PURCHASE: Starting purchase for package: \(package.identifier)")
            let result = await revenueCatManager.purchase(package: package)
            print("🎫 PURCHASE: Result - success=\(result.success), error=\(result.error?.localizedDescription ?? "none")")

            await MainActor.run {
                if result.success {
                    print("🎫 PURCHASE: ✅ SUCCESS - Setting isDismissing=true, isPresented=false")
                    // Dismiss paywall immediately and show success toast
                    isDismissing = true // Prevent UI from showing "Manage Billing"
                    isPresented = false
                    print("🎫 PURCHASE: Posting subscriptionSucceeded notification in 0.3s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🎫 PURCHASE: Posting subscriptionSucceeded notification NOW")
                        NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                    }
                } else {
                    if let error = result.error {
                        let nsError = error as NSError

                        // Check for user cancellation - don't show error dialog
                        let isUserCancellation = (nsError.domain == "SKErrorDomain" && nsError.code == 2) ||
                                                (nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 1) ||
                                                (nsError.domain == "SKErrorDomain" && nsError.code == 19) ||
                                                error.localizedDescription.lowercased().contains("cancel")

                        if isUserCancellation {
                            return
                        }
                        
                        // Show user-friendly error message
                        let errorMessage: String
                        if nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 10 {
                            errorMessage = "Network error. Please check your connection and try again."
                        } else {
                            errorMessage = "Something went wrong with your subscription. Please try again later."
                        }

                        isDismissing = true // Prevent any UI state changes during dismissal
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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