//
//  LoginView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var toastManager: ToastManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingForgotPassword: Bool = false
    @State private var resetEmail: String = ""
    @State private var showingResetSuccessAlert: Bool = false

    // Which bottom sheet is currently presented (login / signup / guest notice).
    @State private var activeSheet: AuthSheet?

    // Callbacks for navigation
    let onLogin: () -> Void
    let onShowRegister: () -> Void

    // When presented as the initial auth gate, guests can skip. When presented as a
    // "Connect Account" flow from inside the app, hide it — the user is already a guest.
    var allowGuest: Bool = true

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !authManager.isLoading
    }

    private var isSignupValid: Bool {
        !email.isEmpty && password.count >= 8 && !authManager.isLoading
    }

    enum AuthSheet: Identifiable {
        case login, signup
        var id: Int { hashValue }
    }

    // MARK: - Body

    var body: some View {
        continueScreen
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .login: emailLoginSheet
                case .signup: signupSheet
                }
            }
            .appTextInputAlert(
                title: "Reset Password",
                isPresented: $showingForgotPassword,
                text: $resetEmail,
                placeholder: "Email",
                message: "Enter your email address and we'll send you a link to reset your password.",
                primaryAction: .primary("Send Reset Email") {
                    let emailToReset = resetEmail.isEmpty ? email : resetEmail
                    guard !emailToReset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        toastManager.showError("Please enter an email address")
                        return
                    }
                    Task {
                        await authManager.resetPassword(email: emailToReset)
                        resetEmail = ""
                        if authManager.authError != nil {
                            toastManager.showError("Failed to send reset email")
                        } else {
                            showingResetSuccessAlert = true
                        }
                    }
                }
            )
            .onChange(of: showingForgotPassword) { _, isShowing in
                if !isShowing {
                    Task { await MainActor.run { authManager.isLoading = false } }
                }
            }
            .appInfoAlert(
                title: "Check Your Email",
                isPresented: $showingResetSuccessAlert,
                message: "We've sent you a reset link. Check your spam folder if you don't see it."
            )
    }

    // MARK: - Continue Screen (base)

    private var continueScreen: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 80) {
                // Logo + wordmark
                logoBlock

                // Auth options
                VStack(spacing: 40) {
                    // Email + primary email CTA
                    VStack(spacing: 16) {
                        authInput(text: $email, placeholder: "Email address", isSecure: false)

                        AppButton(
                            title: "Sign in or create account",
                            action: { activeSheet = .login },
                            hierarchy: .secondary,
                            size: .extraSmall,
                            textColorOverride: AppColors.accentBackground
                        )
                    }

                    orDivider

                    // Social + guest
                    VStack(spacing: 16) {
                        AppButton(
                            title: "Continue with Apple",
                            action: performAppleSignIn,
                            hierarchy: .secondary,
                            size: .extraSmall,
                            leftIcon: "apple"
                        )
                        AppButton(
                            title: "Continue with Google",
                            action: performGoogleSignIn,
                            hierarchy: .secondary,
                            size: .extraSmall,
                            leftIcon: "google"
                        )
                        if allowGuest {
                            AppButton(
                                title: "Continue as Guest",
                                action: { authManager.continueAsGuest() },
                                hierarchy: .ghost,
                                size: .extraSmall
                            )
                        }
                    }
                }

                // Legal
                legalText
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundWhite)
    }

    // MARK: - Email Login Sheet ("Welcome back! 👋")

    private var emailLoginSheet: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Welcome back! 👋")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    logoBlock
                        .padding(.bottom, 60)

                    VStack(spacing: 40) {
                        VStack(spacing: 22) {
                            authInput(text: $email, placeholder: "Email", isSecure: false)
                            authInput(text: $password, placeholder: "Password", isSecure: true)

                            AppButton(
                                title: authManager.isLoading ? "Signing in..." : "Sign in",
                                action: performLogin,
                                hierarchy: .primary,
                                size: .extraSmall,
                                isEnabled: isFormValid
                            )
                        }

                        accentLink("Forgot password?") { showingForgotPassword = true }
                    }

                    Spacer(minLength: 40)

                    // Switch to signup
                    VStack(spacing: 8) {
                        Text("Don't have an account?")
                            .font(Font.custom("Overused Grotesk", size: 18).weight(.medium))
                            .foregroundColor(AppColors.foregroundSecondary)
                        accentLink("Create an account") { activeSheet = .signup }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.backgroundWhite)
        .presentationDetents([.fraction(0.98)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Signup Sheet ("Create an account")

    private var signupSheet: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Create an account")

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    logoBlock
                        .padding(.bottom, 60)

                    VStack(spacing: 40) {
                        VStack(spacing: 22) {
                            authInput(text: $email, placeholder: "Email", isSecure: false)

                            VStack(alignment: .leading, spacing: 6) {
                                authInput(text: $password, placeholder: "Create Password", isSecure: true)
                                Text("Choose a password with at least 8 characters.")
                                    .font(Font.custom("Overused Grotesk", size: 14).weight(.medium))
                                    .foregroundColor(AppColors.foregroundSecondary)
                            }

                            AppButton(
                                title: authManager.isLoading ? "Creating..." : "Continue",
                                action: performRegister,
                                hierarchy: .primary,
                                size: .extraSmall,
                                isEnabled: isSignupValid
                            )
                        }
                    }

                    Spacer(minLength: 40)

                    // Switch to login
                    VStack(spacing: 8) {
                        Text("Already have an account?")
                            .font(Font.custom("Overused Grotesk", size: 18).weight(.medium))
                            .foregroundColor(AppColors.foregroundSecondary)
                        accentLink("Login") { activeSheet = .login }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AppColors.backgroundWhite)
        .presentationDetents([.fraction(0.98)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Reusable pieces

    private func authInput(text: Binding<String>, placeholder: String, isSecure: Bool) -> some View {
        CashMonkiDS.Input.text(
            title: "",
            text: text,
            placeholder: placeholder,
            isRequired: false,
            isSecure: isSecure,
            size: .md
        )
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppColors.linePrimary).frame(height: 1)
            Text("OR")
                .font(Font.custom("Overused Grotesk", size: 12).weight(.semibold))
                .kerning(1.2)
                .foregroundColor(AppColors.foregroundSecondary)
            Rectangle().fill(AppColors.linePrimary).frame(height: 1)
        }
    }

    private var legalText: some View {
        VStack(spacing: 2) {
            Text("By continuing, you agree and consent to our")
                .foregroundColor(AppColors.foregroundTertiary)
            HStack(spacing: 4) {
                Link("Terms of Use", destination: URL(string: "https://cashmonki.app/terms")!)
                    .foregroundColor(AppColors.foregroundPrimary)
                Text("and")
                    .foregroundColor(AppColors.foregroundTertiary)
                Link("Privacy Policy.", destination: URL(string: "https://cashmonki.app/privacy")!)
                    .foregroundColor(AppColors.foregroundPrimary)
            }
        }
        .font(Font.custom("Overused Grotesk", size: 14).weight(.semibold))
        .multilineTextAlignment(.center)
    }

    private func accentLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(Font.custom("Overused Grotesk", size: 18).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundColor(AppColors.accentBackground)
    }

    // App icon + wordmark logo block (Figma: 60px icon, 24px gap, CashMonki wordmark).
    private var logoBlock: some View {
        VStack(spacing: 24) {
            Image("login-app-icon")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Image("cashmonki-wordmark")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 250)
                .foregroundColor(AppColors.foregroundPrimary)
        }
    }

    // Sheet header: chevron-left back button (left), optional centered title.
    private func sheetHeader(title: String? = nil) -> some View {
        ZStack {
            if let title {
                Text(title)
                    .font(Font.custom("Overused Grotesk", size: 20).weight(.semibold))
                    .foregroundColor(AppColors.foregroundPrimary)
            }
            HStack {
                Button(action: { activeSheet = nil }) {
                    Image("chevron-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundPrimary)
                }
                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - Actions

    private func performLogin() {
        Task {
            await authManager.login(email: email, password: password)
            if authManager.isAuthenticated {
                activeSheet = nil
                onLogin()
            }
        }
    }

    private func performRegister() {
        let name = email.components(separatedBy: "@").first ?? "there"
        Task {
            await authManager.register(email: email, password: password, name: name)
            if authManager.isAuthenticated {
                activeSheet = nil
                onLogin()
            }
        }
    }

    private func performAppleSignIn() {
        Task {
            await authManager.signInWithApple()
            if authManager.isAuthenticated { onLogin() }
        }
    }

    private func performGoogleSignIn() {
        Task {
            await authManager.signInWithGoogle()
            if authManager.isAuthenticated { onLogin() }
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView(
        onLogin: { print("Login callback triggered") },
        onShowRegister: { print("Show register callback triggered") }
    )
}
