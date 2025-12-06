import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCat)
struct CustomSubscriptionView: View {
    let offering: Offering
    let onPurchaseCompleted: (CustomerInfo) -> Void
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    @State private var selectedPackage: Package?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onDismiss()
                    }
                    .opacity(0) // Invisible for spacing
                    .disabled(true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Text("Unlock unlimited transactions and advanced features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
            
            // Subscription options
            VStack(spacing: 12) {
                ForEach(offering.availablePackages, id: \.identifier) { package in
                    SubscriptionOptionView(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier,
                        onTap: {
                            selectedPackage = package
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Purchase button
            Button(action: {
                guard let selectedPackage = selectedPackage else { return }
                purchasePackage(selectedPackage)
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isLoading ? "Processing..." : "Start Subscription")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(selectedPackage != nil ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(selectedPackage == nil || isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Auto-select first package
            if selectedPackage == nil {
                selectedPackage = offering.availablePackages.first
            }
        }
    }
    
    private func purchasePackage(_ package: Package) {
        print("🛒 CUSTOM PAYWALL: Attempting to purchase: \(package.storeProduct.localizedTitle)")
        isLoading = true
        
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                
                await MainActor.run {
                    isLoading = false
                    if !result.userCancelled {
                        print("✅ CUSTOM PAYWALL: Purchase successful")
                        onPurchaseCompleted(result.customerInfo)
                    } else {
                        print("⏹️ CUSTOM PAYWALL: Purchase cancelled by user")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ CUSTOM PAYWALL: Purchase failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct SubscriptionOptionView: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(package.storeProduct.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if package.packageType == .annual {
                        Text("Best Value")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
                    .padding(.leading, 8)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#else
struct CustomSubscriptionView: View {
    let offering: Any
    let onPurchaseCompleted: (Any) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        Text("RevenueCat not available")
    }
}
#endif