//
//  RegisterView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    
    // Callback for navigation
    let onRegister: () -> Void
    let onShowLogin: () -> Void
    
    private var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        password.count >= 8 &&
        !authManager.isLoading
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Social Login Section (Google first)
                socialLoginSection
                
                // OR Divider
                orDividerSection
                
                // Form Section
                formSection
                
                // Terms and Privacy Policy
                termsAndPrivacySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 80)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundWhite)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 40) {
            // Welcome Message
            Text("Create an account")
                .font(
                    Font.custom("Overused Grotesk", size: 30)
                        .weight(.semibold)
                )
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(.bottom, 60)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 22) {
            // Email Input
            CashMonkiDS.Input.text(
                title: "",
                text: $email,
                placeholder: "E-mail",
                isRequired: false,
                isSecure: false
            )
            
            // Password Input Group
            VStack(spacing: 6) {
                CashMonkiDS.Input.text(
                    title: "",
                    text: $password,
                    placeholder: "Create Password",
                    isRequired: false,
                    isSecure: true
                )

                // Password Requirements
                if !password.isEmpty {
                    Text("Choose a password with at least 8 characters.")
                        .font(
                            Font.custom("Overused Grotesk", size: 16)
                                .weight(.medium)
                        )
                        .foregroundColor(password.count >= 8 ? (AppColors.successForeground) : AppColors.foregroundSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Continue Button
            AppButton(
                title: authManager.isLoading ? "Creating account..." : "Continue",
                action: performRegister,
                hierarchy: .primary,
                size: .small,
                isEnabled: isFormValid
            )
            
            // Error Display
            if let error = authManager.authError {
                VStack(spacing: 8) {
                    Text(error)
                        .font(
                            Font.custom("Overused Grotesk", size: 16)
                                .weight(.medium)
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.errorForeground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColors.errorBackground.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.top, 16)
            }
            
            // Login Link
            VStack(spacing: 8) {
                Text("Already have an account?")
                    .font(
                        Font.custom("Overused Grotesk", size: 18)
                            .weight(.medium)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Button("Login") {
                    onShowLogin()
                }
                .font(
                    Font.custom("Overused Grotesk", size: 18)
                        .weight(.semibold)
                )
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.accentBackground)
            }
            .padding(.top, 40)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Social Login Section
    
    private var socialLoginSection: some View {
        VStack(spacing: 16) {
            // Apple Sign In
            AppButton(
                title: "Continue with Apple",
                action: performAppleSignIn,
                hierarchy: .secondary,
                size: .small,
                leftIcon: "apple"
            )
            
            // Google Sign In
            AppButton(
                title: "Continue with Google",
                action: performGoogleSignIn,
                hierarchy: .secondary,
                size: .small,
                leftIcon: "google"
            )
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - OR Divider Section
    
    private var orDividerSection: some View {
        HStack {
            Rectangle()
                .fill(AppColors.linePrimary)
                .frame(height: 1)
            
            Text("OR")
                .font(
                    Font.custom("Overused Grotesk", size: 12)
                        .weight(.semibold)
                )
                .kerning(1.2)
                .foregroundColor(AppColors.foregroundSecondary)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(AppColors.linePrimary)
                .frame(height: 1)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Terms and Privacy Section

    private var termsAndPrivacySection: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree and consent to our")
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundColor(AppColors.foregroundSecondary)

            HStack(spacing: 4) {
                Button("Terms of Use") {
                    if let url = URL(string: "https://cashmonki.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppFonts.overusedGroteskSemiBold(size: 14))
                .foregroundColor(AppColors.foregroundPrimary)
                .underline()

                Text("and")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)

                Button("Privacy Policy") {
                    if let url = URL(string: "https://cashmonki.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(AppFonts.overusedGroteskSemiBold(size: 14))
                .foregroundColor(AppColors.foregroundPrimary)
                .underline()

                Text(".")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 24)
    }
    
    // MARK: - Actions
    
    private func performRegister() {
        // Don't extract name from email - let user provide it during onboarding
        print("🔐 RegisterView: Performing registration for email: \(email)")
        
        Task {
            await authManager.register(email: email, password: password, name: "")
            if authManager.isAuthenticated {
                onRegister()
            }
        }
    }
    
    private func performAppleSignIn() {
        print("🔐 RegisterView: Apple Sign In requested")
        Task {
            await authManager.signInWithApple()
            if authManager.isAuthenticated {
                onRegister()
            }
        }
    }
    
    private func performGoogleSignIn() {
        print("🔐 RegisterView: Google Sign In requested")
        Task {
            await authManager.signInWithGoogle()
            if authManager.isAuthenticated {
                onRegister()
            }
        }
    }
    
    private func performFacebookSignIn() {
        print("🔐 RegisterView: Facebook Sign In requested")
        Task {
            await authManager.signInWithFacebook()
        }
    }
}

// MARK: - Preview

#Preview {
    RegisterView(
        onRegister: {
            print("Register callback triggered")
        },
        onShowLogin: {
            print("Show login callback triggered")
        }
    )
}