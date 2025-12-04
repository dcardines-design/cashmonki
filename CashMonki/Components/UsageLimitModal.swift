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
                        
                        Text("You've used all 3 daily receipt scans")
                            .font(AppFonts.overusedGroteskMedium(size: 20))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Benefits of Pro
                    VStack(spacing: 20) {
                        Text("Upgrade to Pro for")
                            .font(AppFonts.overusedGroteskMedium(size: 18))
                            .foregroundColor(AppColors.foregroundSecondary)
                        
                        VStack(spacing: 16) {
                            benefitRow(icon: "∞", title: "Unlimited Receipt Scans", subtitle: "Scan as many receipts as you want")
                            benefitRow(icon: "☁️", title: "Cloud Backup", subtitle: "Your data synced across all devices")
                            benefitRow(icon: "📊", title: "Advanced Analytics", subtitle: "Detailed spending insights and trends")
                            benefitRow(icon: "📤", title: "Export Data", subtitle: "Export to CSV, PDF, and more")
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
                    "Upgrade to Pro",
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