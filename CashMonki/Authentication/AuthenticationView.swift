//
//  AuthenticationView.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import SwiftUI

struct AuthenticationView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showingRegister = false
    
    var body: some View {
        Group {
            let _ = print("🔐 AuthenticationView: Rendering - showingRegister: \(showingRegister)")
            let _ = print("👤 AuthenticationView: Auth state: \(authManager.isAuthenticated)")
            if showingRegister {
                RegisterView(
                    onRegister: {
                        // Registration handled by AuthenticationManager
                        // User will be automatically logged in after successful registration
                    },
                    onShowLogin: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingRegister = false
                        }
                    }
                )
            } else {
                LoginView(
                    onLogin: {
                        // Login handled by AuthenticationManager
                        // User will be automatically logged in after successful login
                    },
                    onShowRegister: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingRegister = true
                        }
                    }
                )
            }
        }
        .background(Color.white)
        .onAppear {
            print("🔐 AuthenticationView: View appeared")
        }
        .appInfoAlert(
            title: "Authentication Error",
            isPresented: .constant(authManager.authError != nil),
            message: authManager.authError ?? "Unknown error occurred",
            onDismiss: {
                authManager.authError = nil
            }
        )
    }
}

#Preview {
    AuthenticationView()
}