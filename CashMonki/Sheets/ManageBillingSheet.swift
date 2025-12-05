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
    
    private var planTitle: String {
        guard let subscription = currentSubscription else { return "No Plan" }
        return subscription.productIdentifier.contains("yearly") ? "Pro Annual" : "Pro Monthly"
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
        guard let subscription = currentSubscription else { return "Free" }
        
        if subscription.productIdentifier.contains("yearly") {
            return "$99.99"
        } else {
            return "$9.99"
        }
    }
    
    private var pricePeriod: String {
        guard let subscription = currentSubscription else { return "" }
        
        if subscription.productIdentifier.contains("yearly") {
            return " / year"
        } else {
            return " / month"
        }
    }
    
    private var isTrialActive: Bool {
        guard let subscription = currentSubscription else { return false }
        // Check if we're still in trial period
        guard let originalPurchaseDate = subscription.originalPurchaseDate,
              let expirationDate = subscription.expirationDate else { return false }
        
        let trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: originalPurchaseDate)
        return Date() < (trialEndDate ?? Date())
    }
    
    private var trialEndDate: String {
        guard let subscription = currentSubscription,
              let originalPurchaseDate = subscription.originalPurchaseDate else { 
            return "December 5, 2025" // Fallback 
        }
        
        if let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: originalPurchaseDate) {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return formatter.string(from: trialEnd)
        }
        
        return "December 5, 2025"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(title: "Manage Billing") {
                isPresented = false
            }
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Hero area with manage billing image
                    Image("manage-billing-image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                    
                    // Current Plan Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current Plan")
                            .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                            .foregroundColor(AppColors.foregroundSecondary)
                        
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(planTitle)
                                        .font(Font.custom("Overused Grotesk", size: 20).weight(.semibold))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppColors.foregroundPrimary)
                                    
                                    if isTrialActive {
                                        Text("1 week trial")
                                            .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.successForeground)
                                            .cornerRadius(12)
                                    }
                                }
                                
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
                            
                            Spacer()
                            
                            // Price breakdown
                            HStack(spacing: 0) {
                                Text(priceAmount)
                                    .font(Font.custom("Overused Grotesk", size: 20).weight(.medium))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(AppColors.foregroundPrimary)
                                
                                Text(pricePeriod)
                                    .font(Font.custom("Overused Grotesk", size: 12).weight(.medium))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(AppColors.foregroundSecondary)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    // Action Items
                    VStack(spacing: 16) {
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
                                        .foregroundColor(.primary)
                                    
                                    Text("Change plan, cancel, or update payment method")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
                                        .foregroundColor(.primary)
                                    
                                    Text("Restore purchases made on another device")
                                        .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoading)
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Footer
            VStack(spacing: 8) {
                Text("Made with 🧠 & ❤️ by")
                    .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Text("Rosebud Studio")
                    .font(Font.custom("Overused Grotesk", size: 14).weight(.bold))
                    .foregroundColor(AppColors.foregroundPrimary)
            }
            .padding(.bottom, 20)
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
}


// MARK: - Preview
#Preview {
    ManageBillingSheet(isPresented: .constant(true))
}