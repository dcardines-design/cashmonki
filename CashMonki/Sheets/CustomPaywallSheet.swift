import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

struct CustomPaywallSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var showingManageBilling = false
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
                        Image("cashmonki-pro-text")
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
                    AppButton.primary("Start my free week", size: .extraSmall) {
                        handleStartFreeTrial()
                    }
                }
                
                // Payment terms text
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                    
                    Text("No payment now")
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
                    
                    Text("Free 7 days then \(paymentTermsText)")
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
    }
    
    // MARK: - Purchase Handling
    private func handleStartFreeTrial() {
        print("🎯 PAYWALL: Selected plan: \(selectedPlan)")
        print("🎯 PAYWALL: Yearly package: \(yearlyPackage?.storeProduct.productIdentifier ?? "nil")")
        print("🎯 PAYWALL: Monthly package: \(monthlyPackage?.storeProduct.productIdentifier ?? "nil")")
        
        guard let package = selectedPackage else {
            print("❌ PAYWALL: No package selected for plan: \(selectedPlan)")
            return
        }
        
        print("🎯 PAYWALL: Starting purchase for \(package.storeProduct.productIdentifier) - \(package.storeProduct.localizedTitle)")
        
        Task {
            let result = await revenueCatManager.purchase(package: package)
            
            await MainActor.run {
                if result.success {
                    print("🎉 PAYWALL: Purchase successful!")
                    isPresented = false
                } else {
                    print("❌ PAYWALL: Purchase failed: \(result.error?.localizedDescription ?? "Unknown error")")
                    // Keep paywall open for retry
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