//
//  EmailConfirmationView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct EmailConfirmationView: View {
    @Binding var isPresented: Bool
    let email: String
    let onConfirmed: () -> Void
    let onBack: (() -> Void)? // Optional callback for back navigation
    
    @State private var isVerifying = false
    @State private var showingResendAlert = false
    @State private var verificationError: String?
    @State private var resendTimer: Timer?
    @State private var resendCountdown: Int = 0
    @State private var canResend: Bool = true
    @State private var hasSentInitialEmail = false
    @ObservedObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Icon Section
                    iconAndTitleSection
                    
                    // Text Content Section
                    textContentSection
                    
                    // Resend Section
                    resendSection
                        .padding(.top, 18)
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            
            // Progress Bar - full width (no progress - all grey)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: "F3F5F8") ?? Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    // No purple fill - 0% progress
                }
            }
            .frame(height: 4)
            
            // Fixed Bottom Button
            FixedBottomGroup.primary(
                title: isVerifying ? "Checking..." : "Confirm Verification",
                action: {
                    verifyCode()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .onAppear {
            print("📧 EmailConfirmation: Starting email verification for: \(email)")
            print("🔍 EmailConfirmation: Email domain: \(email.components(separatedBy: "@").last ?? "unknown")")
            print("👤 EmailConfirmation: AuthManager authenticated: \(authManager.isAuthenticated)")
            print("📧 EmailConfirmation: Current user email: \(authManager.currentUser?.email ?? "none")")

            // Only send email once - prevent duplicate sends from SwiftUI re-renders
            guard !hasSentInitialEmail else {
                print("⚠️ EmailConfirmation: Already sent initial email, skipping duplicate send")
                return
            }
            hasSentInitialEmail = true

            // Automatically send verification email when view appears
            Task {
                print("🚀 EmailConfirmation: Calling sendEmailVerification()...")
                await authManager.sendEmailVerification()
                print("🏁 EmailConfirmation: sendEmailVerification() completed")

                if let error = authManager.authError {
                    print("❌ EmailConfirmation: Email sending failed: \(error)")
                    await MainActor.run {
                        verificationError = error
                    }
                } else {
                    print("✅ EmailConfirmation: Email sending succeeded (no error)")
                }
            }
        }
        .onDisappear {
            stopResendTimer()
        }
        .appInfoAlert(
            title: "Code Sent",
            isPresented: $showingResendAlert,
            message: "A new verification code has been sent to your email."
        )
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
            Text("Confirm Email")
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
        // Email Icon with Background
        VStack(alignment: .center, spacing: 10) {
            Text("📮")
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
    }
    
    // MARK: - Text Content Section (tight 6px spacing)
    
    private var textContentSection: some View {
        VStack(spacing: 24) {
            // Main title
            Text("Check your inbox!")
                .font(
                    Font.custom("Overused Grotesk", size: 30)
                        .weight(.semibold)
                )
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
            
            // Instruction text and email
            VStack(spacing: 6) {
                Text("Please tap the link we just sent to")
                    .font(Font.custom("Overused Grotesk", size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundSecondary)

                Text(email)
                    .font(
                        Font.custom("Overused Grotesk", size: 18)
                            .weight(.medium)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)

                Text("Check your spam folder if you don't see it.")
                    .font(Font.custom("Overused Grotesk", size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            
            // Error Message
            if let error = verificationError {
                Text(error)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.destructiveForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
        }
    }
    
    // MARK: - Resend Section
    
    private var resendSection: some View {
        HStack(spacing: 4) {
            Text(canResend ? "Didn't receive the code?" : "Resend again in")
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundSecondary)
            
            if canResend {
                Button("Resend link") {
                    resendVerificationCode()
                }
                .font(AppFonts.overusedGroteskSemiBold(size: 16))
                .foregroundColor(AppColors.primary)
            } else {
                Text("\(resendCountdown)s")
                    .font(AppFonts.overusedGroteskSemiBold(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func verifyCode() {
        print("🔑 EmailConfirmation: Checking email verification status...")
        print("🕰 EmailConfirmation: Checking verification status for: \(email)")
        
        isVerifying = true
        verificationError = nil
        
        Task {
            let isVerified = await authManager.checkEmailVerification()
            
            await MainActor.run {
                isVerifying = false
                
                if isVerified {
                    print("✅ EmailConfirmation: Email verified successfully for \(email)")
                    print("🎉 EmailConfirmation: Email verification completed!")
                    onConfirmed()
                } else {
                    print("❌ EmailConfirmation: Email not yet verified for \(email)")
                    verificationError = "Email not yet verified. Please check your email and click the verification link, then try again."
                }
            }
        }
    }
    
    private func resendVerificationCode() {
        print("🔁 EmailConfirmation: Resending verification email...")
        print("📧 EmailConfirmation: Target email: \(email)")
        
        // Start countdown timer
        startResendTimer()
        
        Task {
            await authManager.sendEmailVerification()
            
            await MainActor.run {
                if authManager.authError == nil {
                    showingResendAlert = true
                    print("✅ EmailConfirmation: Verification email resent successfully to \(email)")
                    print("🔔 EmailConfirmation: User should check their email inbox")
                } else {
                    verificationError = authManager.authError
                    print("❌ EmailConfirmation: Failed to resend verification email: \(authManager.authError ?? "unknown error")")
                    // Reset timer if email sending failed
                    stopResendTimer()
                }
            }
        }
    }
    
    private func startResendTimer() {
        canResend = false
        resendCountdown = 30
        
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCountdown > 1 {
                resendCountdown -= 1
            } else {
                stopResendTimer()
            }
        }
        
        print("⏱️ EmailConfirmation: Started 30-second resend timer")
    }
    
    private func stopResendTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
        resendCountdown = 0
        canResend = true
        
        print("⏹️ EmailConfirmation: Stopped resend timer")
    }
}

// MARK: - Preview

#Preview {
    EmailConfirmationView(
        isPresented: .constant(true),
        email: "dcardinesiii@gmail.com",
        onConfirmed: {
            print("Email confirmed")
        },
        onBack: {
            print("Back pressed")
        }
    )
}