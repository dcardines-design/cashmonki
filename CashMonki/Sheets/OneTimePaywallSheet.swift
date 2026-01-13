//
//  OneTimePaywallSheet.swift
//  CashMonki
//
//  One-time discount promo paywall with 20% off pricing
//

import SwiftUI
import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

struct OneTimePaywallSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedPlan: PricingPlan = .yearly
    @State private var showingManageBilling = false
    @State private var isDismissing = false
    @State private var isPurchasing = false
    @State private var showingCloseConfirmation = false
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @EnvironmentObject var toastManager: ToastManager

    // MARK: - RevenueCat Package Helpers

    /// The promo offering identifier from RevenueCat
    private let promoOfferingId = "Cashmonki One Time Promo"

    private var targetOffering: Offering? {
        revenueCatManager.getOffering(identifier: promoOfferingId)
    }

    private var monthlyPackage: Package? {
        guard let offering = targetOffering else { return nil }
        // Look for promo monthly product first, then fall back to regular monthly
        return offering.availablePackages.first { package in
            package.storeProduct.productIdentifier == "pro_monthly_cashmonki_pro"
        } ?? offering.availablePackages.first { package in
            package.storeProduct.productIdentifier.contains("monthly") ||
            package.packageType == .monthly
        }
    }

    private var yearlyPackage: Package? {
        guard let offering = targetOffering else { return nil }
        // Look for promo yearly product first, then fall back to regular yearly
        return offering.availablePackages.first { package in
            package.storeProduct.productIdentifier == "pro_yearly_cashmonki_pro"
        } ?? offering.availablePackages.first { package in
            let identifier = package.storeProduct.productIdentifier.lowercased()
            return identifier.contains("yearly") ||
                   identifier.contains("annual") ||
                   identifier.hasSuffix("_yearly") ||
                   identifier.contains("_pro_yearly")
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

    // Promo pricing (20% off)
    private var yearlyPromoPrice: String {
        yearlyPackage?.storeProduct.localizedPriceString ?? "$79.99"
    }

    private var monthlyPromoPrice: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "$7.99"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Scrollable content area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // Top padding for close button
                        Spacer()
                            .frame(height: 32)

                        // Content area
                        VStack(spacing: 24) {
                            // Header image
                            Image("cashmonki-pro-text-onetime")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)

                            // Value props section
                            VStack(spacing: 24) {
                                // Unlimited AI Scans
                                featureRow(
                                    emoji: "✨",
                                    title: "Unlimited AI Scans",
                                    description: "Snap and let AI handle everything, no typing, no hassle."
                                )

                                // Unlimited Recurring Transactions
                                featureRow(
                                    emoji: "🔄",
                                    title: "Unlimited Subscriptions",
                                    description: "Track all your recurring bills and income in one place."
                                )

                                // Unlimited Custom Categories
                                featureRow(
                                    emoji: "📊",
                                    title: "Unlimited Custom Categories",
                                    description: "Create categories that actually match your life."
                                )

                                // Multiple Accounts
                                featureRow(
                                    emoji: "💼",
                                    title: "Multiple Accounts",
                                    description: "Switch easily between personal and business accounts."
                                )

                                // Support Indie
                                featureRow(
                                    emoji: "😌",
                                    title: "Support Indie",
                                    description: "Support indie app creators for the price of a few cups of coffee a month."
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                            .frame(height: 20)
                    }
                }

                // Fixed pricing container at bottom
                VStack(alignment: .leading, spacing: 14) {
                    // Yearly pricing tile
                    Button(action: {
                        selectedPlan = .yearly
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            // Top row: Yearly + badge + check
                            HStack {
                                HStack(spacing: 8) {
                                    Text("Yearly")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundPrimary)

                                    Text("20% off permanently")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.successForeground)
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

                            // Bottom row: Price + Billed text
                            HStack(alignment: .bottom) {
                                HStack(alignment: .bottom, spacing: 4) {
                                    Text(yearlyPromoPrice)
                                        .font(
                                            Font.custom("Overused Grotesk", size: 24)
                                                .weight(.bold)
                                        )
                                        .foregroundColor(AppColors.foregroundPrimary)

                                    Text("$99.99")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.medium)
                                        )
                                        .strikethrough(true, color: AppColors.foregroundSecondary)
                                        .foregroundColor(AppColors.foregroundSecondary)

                                    Text("/ year")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 12)
                                                .weight(.medium)
                                        )
                                        .foregroundColor(AppColors.foregroundSecondary)
                                }

                                Spacer()

                                // Right side text
                                Text("Billed \(yearlyPromoPrice) yearly")
                                    .font(
                                        Font.custom("Overused Grotesk", size: 12)
                                            .weight(.medium)
                                    )
                                    .foregroundColor(AppColors.foregroundSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
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

                    // Monthly pricing tile
                    Button(action: {
                        selectedPlan = .monthly
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            // Top row: Monthly + badge + check
                            HStack {
                                HStack(spacing: 8) {
                                    Text("Monthly")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundPrimary)

                                    Text("20% off permanently")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.successForeground)
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

                            // Bottom row: Price + Cancel text
                            HStack(alignment: .bottom) {
                                HStack(alignment: .bottom, spacing: 4) {
                                    Text(monthlyPromoPrice)
                                        .font(
                                            Font.custom("Overused Grotesk", size: 24)
                                                .weight(.bold)
                                        )
                                        .foregroundColor(AppColors.foregroundPrimary)

                                    Text("$9.99")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.medium)
                                        )
                                        .strikethrough(true, color: AppColors.foregroundSecondary)
                                        .foregroundColor(AppColors.foregroundSecondary)

                                    Text("/ month")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 12)
                                                .weight(.medium)
                                        )
                                        .foregroundColor(AppColors.foregroundSecondary)
                                }

                                Spacer()

                                // Right side text
                                Text("Cancel anytime")
                                    .font(
                                        Font.custom("Overused Grotesk", size: 12)
                                            .weight(.medium)
                                    )
                                    .foregroundColor(AppColors.foregroundSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
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

                    // Claim 20% Offer button + Footer text grouped
                    VStack(spacing: 16) {
                        // Claim 20% Offer button
                        if revenueCatManager.isProUser && !isDismissing && !isPurchasing {
                            AppButton.secondary("Manage Billing", size: .extraSmall) {
                                showingManageBilling = true
                            }
                        } else if !isDismissing {
                            let buttonText = isPurchasing ? "Processing..." : "Claim 20% Offer"

                            AppButton(
                                title: buttonText,
                                action: { if !isPurchasing { handlePurchase() } },
                                hierarchy: .primary,
                                size: .extraSmall,
                                state: isPurchasing ? .pressed : .active
                            )
                        }

                        // Footer text
                        VStack(spacing: 8) {
                            // "This discounted price is only available now"
                            HStack(spacing: 4) {
                                Text("This discounted price is")
                                    .font(
                                        Font.custom("Overused Grotesk", size: 14)
                                            .weight(.medium)
                                    )
                                    .foregroundColor(AppColors.foregroundSecondary)

                                Text("only available at this point")
                                    .font(
                                        Font.custom("Overused Grotesk", size: 14)
                                            .weight(.semibold)
                                    )
                                    .foregroundColor(AppColors.accentBackground)
                            }

                            // Terms line with checkmark
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.foregroundSecondary)

                                Text("No payment now  ·  Free 7 days then \(selectedPlan == .yearly ? yearlyPromoPrice : monthlyPromoPrice) a \(selectedPlan == .yearly ? "year" : "month")")
                                    .font(
                                        Font.custom("Overused Grotesk", size: 14)
                                            .weight(.medium)
                                    )
                                    .foregroundColor(AppColors.foregroundSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
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
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            }

            // Fixed close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingCloseConfirmation = true
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
                Color(red: 0.95, green: 0.95, blue: 0.98)
                    .ignoresSafeArea()

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
        .alert("Skip this offer?", isPresented: $showingCloseConfirmation) {
            Button("Keep Offer", role: .cancel) { }
            Button("Skip", role: .destructive) {
                isPresented = false
            }
        } message: {
            Text("This discount won't be available again. Are you sure you want to skip?")
        }
        .onAppear {
            print("🎁 ======= ONE-TIME PAYWALL APPEARED =======")
            print("🎁 ONE-TIME PAYWALL: isProUser=\(revenueCatManager.isProUser)")

            AnalyticsManager.shared.trackPaywallViewed(
                source: "one_time_promo",
                hasUsedTrial: revenueCatManager.hasUsedTrialBefore
            )

            Task {
                await ensureOfferingsLoaded()

                if let promo = revenueCatManager.getOffering(identifier: promoOfferingId) {
                    print("🎁 ONE-TIME PAYWALL: ✅ Found promo offering '\(promoOfferingId)'")
                    for pkg in promo.availablePackages {
                        print("🎁 ONE-TIME PAYWALL:   📦 \(pkg.identifier): \(pkg.storeProduct.localizedPriceString)")
                    }
                } else {
                    print("🎁 ONE-TIME PAYWALL: ❌ Could not find offering '\(promoOfferingId)'")
                }
            }
        }
    }

    // MARK: - Feature Row Component

    private func featureRow(emoji: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .center, spacing: 10) {
                Text(emoji)
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

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(
                        Font.custom("Overused Grotesk", size: 18)
                            .weight(.semibold)
                    )
                    .foregroundColor(AppColors.foregroundWhite)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(description)
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

    // MARK: - Offerings Management

    private func ensureOfferingsLoaded() async {
        if revenueCatManager.offerings == nil {
            await revenueCatManager.loadOfferings()
        }
    }

    // MARK: - Purchase Handling

    private func handlePurchase() {
        print("🎁 ======= ONE-TIME handlePurchase CALLED =======")
        isPurchasing = true
        Task {
            await ensureOfferingsLoaded()

            guard let package = selectedPackage else {
                print("🎁 ONE-TIME PURCHASE: ❌ No package selected")
                await MainActor.run {
                    isDismissing = true
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

            print("🎁 ONE-TIME PURCHASE: Starting purchase for package: \(package.identifier)")
            let result = await revenueCatManager.purchase(package: package)
            print("🎁 ONE-TIME PURCHASE: Result - success=\(result.success), error=\(result.error?.localizedDescription ?? "none")")

            await MainActor.run {
                if result.success {
                    print("🎁 ONE-TIME PURCHASE: ✅ SUCCESS")

                    AnalyticsManager.shared.track(.subscriptionStarted, properties: [
                        "plan": selectedPlan == .yearly ? "yearly" : "monthly",
                        "price": package.storeProduct.localizedPriceString,
                        "source": "one_time_promo"
                    ])

                    isDismissing = true
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                    }
                } else {
                    if let error = result.error {
                        let nsError = error as NSError

                        let isUserCancellation = (nsError.domain == "SKErrorDomain" && nsError.code == 2) ||
                                                (nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 1) ||
                                                (nsError.domain == "SKErrorDomain" && nsError.code == 19) ||
                                                error.localizedDescription.lowercased().contains("cancel")

                        if isUserCancellation {
                            isPurchasing = false
                            return
                        }

                        let errorMessage: String
                        if nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 10 {
                            errorMessage = "Network error. Please check your connection and try again."
                        } else {
                            errorMessage = "Something went wrong with your subscription. Please try again later."
                        }

                        isDismissing = true
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(
                                name: .subscriptionFailed,
                                object: nil,
                                userInfo: ["errorMessage": errorMessage]
                            )
                        }
                    } else {
                        isPurchasing = false
                        return
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OneTimePaywallSheet(isPresented: .constant(true))
}
