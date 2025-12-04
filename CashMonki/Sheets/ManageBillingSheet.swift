import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

struct ManageBillingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @State private var isLoading = false
    
    // MARK: - Subscription Info Helpers
    private var currentSubscription: EntitlementInfo? {
        revenueCatManager.customerInfo?.entitlements.active.values.first
    }
    
    private var subscriptionTitle: String {
        guard let subscription = currentSubscription else { return "No Active Subscription" }
        return subscription.productIdentifier.contains("yearly") ? "CashMonki Pro Annual" : "CashMonki Pro Monthly"
    }
    
    private var subscriptionPrice: String {
        guard let subscription = currentSubscription,
              let originalPurchaseDate = subscription.originalPurchaseDate else { 
            return "Unknown" 
        }
        
        // Get price from product identifier
        if subscription.productIdentifier.contains("yearly") {
            return "$99.99/year"
        } else {
            return "$9.99/month"
        }
    }
    
    private var nextBillingDate: String {
        guard let subscription = currentSubscription,
              let expirationDate = subscription.expirationDate else { 
            return "Unknown" 
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: expirationDate)
    }
    
    private var isTrialActive: Bool {
        guard let subscription = currentSubscription else { return false }
        // Check if we're still in trial period
        guard let originalPurchaseDate = subscription.originalPurchaseDate,
              let expirationDate = subscription.expirationDate else { return false }
        
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: originalPurchaseDate)
        return Date() < (trialEndDate ?? Date())
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Fixed close button area
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
                
                // Scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header section
                        VStack(spacing: 16) {
                            Image("cashmonki-pro-text")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                            
                            Text("Manage Your Subscription")
                                .font(
                                    Font.custom("Overused Grotesk", size: 24)
                                        .weight(.semibold)
                                )
                                .foregroundColor(AppColors.foregroundPrimary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Subscription status card
                        VStack(spacing: 20) {
                            // Status badge
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(AppColors.successBackground)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(isTrialActive ? "Free Trial Active" : "Pro Active")
                                        .font(
                                            Font.custom("Overused Grotesk", size: 14)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.successForeground)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.successBackground.opacity(0.1))
                                .cornerRadius(20)
                                
                                Spacer()
                            }
                            
                            // Subscription details
                            VStack(spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Plan")
                                            .font(
                                                Font.custom("Overused Grotesk", size: 14)
                                                    .weight(.medium)
                                            )
                                            .foregroundColor(AppColors.foregroundSecondary)
                                        
                                        Text(subscriptionTitle)
                                            .font(
                                                Font.custom("Overused Grotesk", size: 18)
                                                    .weight(.semibold)
                                            )
                                            .foregroundColor(AppColors.foregroundPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(subscriptionPrice)
                                        .font(
                                            Font.custom("Overused Grotesk", size: 18)
                                                .weight(.semibold)
                                        )
                                        .foregroundColor(AppColors.foregroundPrimary)
                                }
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isTrialActive ? "Trial ends" : "Next billing")
                                            .font(
                                                Font.custom("Overused Grotesk", size: 14)
                                                    .weight(.medium)
                                            )
                                            .foregroundColor(AppColors.foregroundSecondary)
                                        
                                        Text(nextBillingDate)
                                            .font(
                                                Font.custom("Overused Grotesk", size: 16)
                                                    .weight(.medium)
                                            )
                                            .foregroundColor(AppColors.foregroundPrimary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .background(.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        
                        // Management options
                        VStack(spacing: 16) {
                            // Apple Subscription Management
                            Button(action: {
                                openAppleSubscriptionManagement()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Manage Subscription")
                                            .font(
                                                Font.custom("Overused Grotesk", size: 16)
                                                    .weight(.semibold)
                                            )
                                            .foregroundColor(AppColors.foregroundPrimary)
                                        
                                        Text("Change plan, cancel, or update payment")
                                            .font(
                                                Font.custom("Overused Grotesk", size: 14)
                                                    .weight(.medium)
                                            )
                                            .foregroundColor(AppColors.foregroundSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.foregroundSecondary)
                                }
                                .padding(16)
                                .background(.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Restore Purchases
                            Button(action: {
                                restorePurchases()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Restore Purchases")
                                            .font(
                                                Font.custom("Overused Grotesk", size: 16)
                                                    .weight(.semibold)
                                            )
                                            .foregroundColor(AppColors.foregroundPrimary)
                                        
                                        Text("If you purchased on another device")
                                            .font(
                                                Font.custom("Overused Grotesk", size: 14)
                                                    .weight(.medium)
                                            )
                                            .foregroundColor(AppColors.foregroundSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppColors.foregroundSecondary)
                                    }
                                }
                                .padding(16)
                                .background(.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isLoading)
                        }
                        
                        // Footer info
                        VStack(spacing: 8) {
                            Text("Questions or need help?")
                                .font(
                                    Font.custom("Overused Grotesk", size: 14)
                                        .weight(.medium)
                                )
                                .foregroundColor(AppColors.foregroundSecondary)
                            
                            Button("Contact Support") {
                                openSupportEmail()
                            }
                            .font(
                                Font.custom("Overused Grotesk", size: 14)
                                    .weight(.semibold)
                            )
                            .foregroundColor(AppColors.accentBackground)
                        }
                        
                        // Bottom padding
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                }
            }
        }
        .background(AppColors.surfacePrimary)
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
                await MainActor.run {
                    revenueCatManager.customerInfo = customerInfo
                    isLoading = false
                    print("✅ BILLING: Purchases restored successfully")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ BILLING: Failed to restore purchases: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func openSupportEmail() {
        #if canImport(UIKit)
        if let url = URL(string: "mailto:support@cashmonki.app?subject=CashMonki%20Pro%20Support") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Preview
#Preview {
    ManageBillingSheet(isPresented: .constant(true))
}