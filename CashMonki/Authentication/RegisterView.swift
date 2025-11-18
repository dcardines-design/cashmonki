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
        GeometryReader { geometry in
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
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 80)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundWhite)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 40) {
            // App Logo/Title
            Image("CashMonki Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 300)
            
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
            
            // Password Input
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
                    .frame(width: 400, alignment: .topLeading)
                    .padding(.top, -12)
            }
            
            // Continue Button
            AppButton(
                title: authManager.isLoading ? "Creating account..." : "Continue",
                action: performRegister,
                hierarchy: .primary,
                size: .small,
                isEnabled: isFormValid
            )
            
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
            HStack(spacing: 4) {
                Text("By continuing, you agree and consent to our")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Button("Terms of Use") {
                    // TODO: Show Terms of Use
                    print("Terms of Use tapped")
                }
                .font(AppFonts.overusedGroteskSemiBold(size: 14))
                .foregroundColor(AppColors.foregroundPrimary)
                .underline()
            }
            
            HStack(spacing: 4) {
                Text("and")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Button("Privacy Policy") {
                    // TODO: Show Privacy Policy
                    print("Privacy Policy tapped")
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
        // Extract name from email for registration
        let extractedName = email.components(separatedBy: "@").first?.capitalized ?? "User"
        print("🔐 RegisterView: Performing registration for: \(extractedName) (\(email))")
        
        Task {
            await authManager.register(email: email, password: password, name: extractedName)
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