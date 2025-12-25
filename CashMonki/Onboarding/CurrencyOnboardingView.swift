//
//  CurrencyOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct CurrencyOnboardingView: View {
    @Binding var isPresented: Bool
    let onCurrencySelected: (Currency) -> Void
    let onBack: (() -> Void)?
    
    @State private var selectedCurrency: Currency = .php // Will be updated by location detection
    @State private var secondaryCurrency: Currency? = nil // Optional secondary currency
    @State private var detectedCountry: String = ""
    @State private var isLocationDetected = false
    
    /// Check if current user is Gmail user
    /// CURRENT: Always false in no-auth flow
    private var isGmailUser: Bool {
        // FUTURE: Uncomment when re-enabling authentication
        // #if canImport(FirebaseAuth)
        // if let currentUser = Auth.auth().currentUser {
        //     return currentUser.providerData.contains { $0.providerID == "google.com" }
        // }
        // #endif
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Icon and Title Section
                    iconAndTitleSection
                    
                    // Currency Selection Inputs
                    currencySelectionSection
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            
            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .currencySelection,
                isGmailUser: isGmailUser
            )
            
            // Fixed Bottom Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    print("✅ CurrencyOnboarding: User confirmed currency selection")
                    print("🏆 CurrencyOnboarding: Primary currency: \(selectedCurrency.rawValue) (\(selectedCurrency.displayName))")
                    print("💲 CurrencyOnboarding: Primary symbol: \(selectedCurrency.symbol)")
                    print("🌍 CurrencyOnboarding: Primary region: \(selectedCurrency.flag)")
                    
                    if let secondary = secondaryCurrency {
                        print("💱 CurrencyOnboarding: Secondary currency: \(secondary.rawValue) (\(secondary.displayName))")
                        print("💲 CurrencyOnboarding: Secondary symbol: \(secondary.symbol)")
                    } else {
                        print("💱 CurrencyOnboarding: No secondary currency selected")
                    }
                    
                    // Set both primary and secondary currency preferences
                    CurrencyPreferences.shared.setPrimaryCurrency(selectedCurrency)
                    CurrencyPreferences.shared.setSecondaryCurrency(secondaryCurrency)
                    
                    // Also update rate manager
                    CurrencyRateManager.shared.setPrimaryCurrency(selectedCurrency)
                    CurrencyRateManager.shared.setSecondaryCurrency(secondaryCurrency)
                    
                    // CRITICAL: Set completion flags when user actually confirms currency
                    UserDefaults.standard.set(true, forKey: "hasCompletedCurrencySelection")
                    UserDefaults.standard.set(true, forKey: "hasSetPrimaryCurrency")
                    print("✅ CurrencyOnboarding: Set currency completion flags - hasCompletedCurrencySelection: true")
                    print("✅ CurrencyOnboarding: Set currency completion flags - hasSetPrimaryCurrency: true")
                    
                    onCurrencySelected(selectedCurrency)
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("💰 CurrencyOnboarding: Starting currency selection process")
            detectLocationAndCurrency()
        }
        .onChange(of: selectedCurrency) { _, newCurrency in
            print("🔄 CurrencyOnboarding: Currency changed to: \(newCurrency.rawValue)")
            print("💰 CurrencyOnboarding: New currency details - Symbol: \(newCurrency.symbol), Name: \(newCurrency.displayName)")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Back Button
            Button(action: {
                if let onBack = onBack {
                    onBack()
                } else {
                    isPresented = false
                }
            }) {
                Image("chevron-left")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            
            Spacer()
            
            // Title
            Text("Get Started")
                .font(AppFonts.overusedGroteskSemiBold(size: 17))
                .foregroundColor(AppColors.foregroundPrimary)
            
            Spacer()
            
            // Invisible element for balance
            Rectangle()
                .fill(Color.clear)
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.backgroundWhite)
    }
    
    // MARK: - Icon and Title Section
    
    private var iconAndTitleSection: some View {
        VStack(spacing: 18) {
            // Currency Icon
            VStack(alignment: .center, spacing: 10) {
                Text("💵")
                    .font(
                        Font.custom("Overused Grotesk", size: 60)
                            .weight(.medium)
                    )
                    .foregroundColor(AppColors.foregroundPrimary)
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)
            
            // Title and Subtitle
            VStack(spacing: 6) {
                // Main Title
                Text("What's your preferred currency?")
                    .font(
                        Font.custom("Overused Grotesk", size: 30)
                            .weight(.semibold)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Subtitle
                Text("We'll use this as your main currency and convert other currencies to match.")
                    .font(
                        Font.custom("Overused Grotesk", size: 16)
                            .weight(.medium)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - Location Detection
    
    private func detectLocationAndCurrency() {
        print("🌍 CurrencyOnboarding: Starting location-based currency detection...")
        
        let locationService = LocationCurrencyService.shared
        
        // Get recommended currency based on device locale
        let recommendedCurrency = locationService.getRecommendedCurrency()
        let country = locationService.getDetectedCountry()
        
        // Update the UI with the detection results
        DispatchQueue.main.async {
            self.selectedCurrency = recommendedCurrency
            self.detectedCountry = country
            self.isLocationDetected = true
            
            // Start with no secondary currency (user can add it if they want)
            self.secondaryCurrency = nil
            
            print("✅ CurrencyOnboarding: Location detection complete")
            print("🌍 CurrencyOnboarding: Country: \(country)")
            print("💰 CurrencyOnboarding: Recommended currency: \(recommendedCurrency.rawValue) (\(recommendedCurrency.displayName))")
            print("💲 CurrencyOnboarding: Currency symbol: \(recommendedCurrency.symbol)")
            print("💱 CurrencyOnboarding: Secondary currency: none (user can add optionally)")
        }
    }
    
    // MARK: - Currency Selection Section
    
    private var currencySelectionSection: some View {
        VStack(spacing: 16) {
            // Primary Currency
            AppInputField.currency(
                selectedCurrency: $selectedCurrency,
                size: .md,
                title: "Primary Currency"
            )
            
            // Secondary Currency temporarily hidden
            /*
            // Secondary Currency - same styling as primary
            SecondaryCurrencyInputField(
                selectedCurrency: $secondaryCurrency,
                primaryCurrency: selectedCurrency,
                title: "Secondary Currency (Optional)"
            )
            */
        }
    }
}

// MARK: - Preview

#Preview {
    CurrencyOnboardingView(
        isPresented: .constant(true),
        onCurrencySelected: { currency in
            print("Selected currency: \(currency)")
        },
        onBack: {
            print("Back pressed")
        }
    )
}