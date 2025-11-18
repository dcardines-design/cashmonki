//
//  LoginView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingForgotPassword: Bool = false
    @State private var resetEmail: String = ""
    
    // Callback for navigation
    let onLogin: () -> Void
    let onShowRegister: () -> Void
    
    private var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
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
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 80)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundWhite)
        .appTextInputAlert(
            title: "Reset Password",
            isPresented: $showingForgotPassword,
            text: $resetEmail,
            placeholder: "Email",
            message: "Enter your email address and we'll send you a link to reset your password.",
            primaryAction: .primary("Send Reset Email") {
                Task {
                    await authManager.resetPassword(email: resetEmail.isEmpty ? email : resetEmail)
                    resetEmail = ""
                }
            }
        )
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
            Text("Welcome back! 👋")
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
                placeholder: "Password",
                isRequired: false,
                isSecure: true
            )
            
            // Login Button
            AppButton(
                title: authManager.isLoading ? "Signing in..." : "Login",
                action: performLogin,
                hierarchy: .primary,
                size: .small,
                isEnabled: isFormValid
            )
            
            // Forgot Password Link
            Button("Forgot password?") {
                showingForgotPassword = true
            }
            .font(
                Font.custom("Overused Grotesk", size: 18)
                    .weight(.semibold)
            )
            .multilineTextAlignment(.center)
            .foregroundColor(AppColors.accentBackground)
            .padding(.top, 40)
            
            // Register Link
            VStack(spacing: 8) {
                Text("Don't have an account?")
                    .font(
                        Font.custom("Overused Grotesk", size: 18)
                            .weight(.medium)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundSecondary)
                
                Button("Create an account") {
                    onShowRegister()
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
    
    // MARK: - Actions
    
    private func performLogin() {
        print("🔐 LoginView: Performing login for email: \(email)")
        
        Task {
            await authManager.login(email: email, password: password)
            if authManager.isAuthenticated {
                onLogin()
            }
        }
    }
    
    private func performAppleSignIn() {
        print("🔐 LoginView: Apple Sign In requested")
        Task {
            await authManager.signInWithApple()
            if authManager.isAuthenticated {
                onLogin()
            }
        }
    }
    
    private func performGoogleSignIn() {
        print("🔐 LoginView: Google Sign In requested")
        Task {
            await authManager.signInWithGoogle()
            if authManager.isAuthenticated {
                onLogin()
            }
        }
    }
    
    private func performFacebookSignIn() {
        print("🔐 LoginView: Facebook Sign In requested")
        // TODO: Implement Facebook Sign In
    }
}

// MARK: - Preview

#Preview {
    LoginView(
        onLogin: {
            print("Login callback triggered")
        },
        onShowRegister: {
            print("Show register callback triggered")
        }
    )
}