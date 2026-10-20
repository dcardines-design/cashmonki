//
//  UsageLimitModal.swift
//  CashMonki
//
//  Created by Claude on 12/4/25.
//

import SwiftUI

/// Modal shown when free users exceed their daily receipt analysis limit
struct UsageLimitModal: View {
    @Binding var isPresented: Bool
    let onUpgradeToProTapped: () -> Void
    
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    isPresented = false
                }) {
                    AppIcon(assetName: "x", fallbackSystemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.foregroundSecondary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Daily Limit Reached")
                    .font(AppFonts.overusedGroteskSemiBold(size: 18))
                    .foregroundColor(AppColors.foregroundPrimary)
                
                Spacer()
                
                // Invisible spacer for balance
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Illustration
                    VStack(spacing: 16) {
                        Text("📊")
                            .font(.system(size: 80))
                        
                        Text("You've used all \(revenueCatManager.planTier.dailyScanLimit ?? PlanTier.freeDailyScanLimit) daily receipt scans")
                            .font(AppFonts.overusedGroteskMedium(size: 20))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Benefits of Pro
                    VStack(spacing: 20) {
                        Text(revenueCatManager.planTier == .plus ? "Upgrade to Pro for" : "Upgrade for")
                            .font(AppFonts.overusedGroteskMedium(size: 18))
                            .foregroundColor(AppColors.foregroundSecondary)
                        
                        VStack(spacing: 16) {
                            benefitRow(icon: "🧾", title: "More receipt scans", subtitle: "\(PlanTier.plusDailyScanLimit) a day on Plus, unlimited on Pro")
                            benefitRow(icon: "💬", title: "More Ask messages", subtitle: "\(PlanTier.plusDailyAskLimit) a day on Plus, \(PlanTier.proDailyAskLimit) a day on Pro")
                            benefitRow(icon: "💼", title: "Unlimited wallets & recurring", subtitle: "On both Plus and Pro")
                            benefitRow(icon: "📁", title: "Custom categories", subtitle: "On both Plus and Pro")
                        }
                    }
                    
                    // Reset info
                    VStack(spacing: 8) {
                        Text("Your daily limit resets at midnight")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                            .multilineTextAlignment(.center)
                        
                        Text("You can still add transactions manually")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120) // Space for fixed buttons
            }
            
            // Fixed bottom buttons
            VStack(spacing: 12) {
                // Upgrade to Pro button
                AppButton.primary(
                    revenueCatManager.planTier == .plus ? "Upgrade to Pro" : "See plans",
                    size: .medium
                ) {
                    onUpgradeToProTapped()
                    isPresented = false
                }
                
                // Try again tomorrow button
                AppButton.ghost(
                    "I'll try again tomorrow",
                    size: .medium
                ) {
                    isPresented = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(AppColors.surfaceSecondary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    UsageLimitModal(
        isPresented: .constant(true),
        onUpgradeToProTapped: {
            print("Upgrade to Pro tapped")
        }
    )
}