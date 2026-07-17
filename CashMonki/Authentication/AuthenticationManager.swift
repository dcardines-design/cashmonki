//
//  AuthenticationManager.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import Foundation
import SwiftUI
import AuthenticationServices

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AuthenticatedUser?
    @Published var isLoading: Bool = false
    @Published var authError: String?
    @Published var isNewRegistration: Bool = false // Track if this is a new registration
    @Published var isGuestMode: Bool = false // User chose "Continue as guest" (no account, local-only)

    private init() {
        // Restore guest choice across launches so a guest isn't forced back to the login gate.
        self.isGuestMode = UserDefaults.standard.bool(forKey: "isGuestMode")
        // Don't check authentication immediately - wait for Firebase to be configured
        print("🔐 AuthenticationManager: Initialized - waiting for Firebase configuration (guest: \(isGuestMode))")
    }

    // MARK: - Guest Mode

    /// Continue without an account. App runs on the anonymous session, data local-only
    /// (survives reinstall only if the user later signs in from Settings).
    func continueAsGuest() {
        print("👤 AuthenticationManager: Continue as guest selected")
        let d = UserDefaults.standard

        // Stable guest identity so the (not-connected) local data always loads in guest mode
        // and is never confused with an account. Established once, then reused every time.
        var guestUID = d.string(forKey: "guest_local_uid")
        if guestUID == nil {
            // Adopt the largest existing on-device data box (the user's real un-linked data),
            // else the current pointer, else a fresh guest id.
            guestUID = Self.largestLocalUserUID()
                ?? d.string(forKey: "last_authenticated_firebase_uid")
                ?? "guest_\(UUID().uuidString)"
            d.set(guestUID, forKey: "guest_local_uid")
            print("👤 AuthenticationManager: Established guest identity = \(guestUID ?? "?")")
        }
        // Point local storage at the guest identity so its data loads.
        d.set(guestUID, forKey: "last_authenticated_firebase_uid")

        isGuestMode = true
        d.set(true, forKey: "isGuestMode")

        // Load the guest's own data (posts load-complete -> subscriptions reload too).
        UserManager.shared.restoreUserSession()
    }

    /// UID of the largest `currentUser_firebase_*` blob = the device's real local data.
    /// Used to anchor the guest identity to the user's actual (un-linked) data.
    private static func largestLocalUserUID() -> String? {
        let prefix = "currentUser_firebase_"
        let d = UserDefaults.standard
        var bestUID: String?
        var bestSize = 0
        for key in d.dictionaryRepresentation().keys where
            key.hasPrefix(prefix) &&
            !key.hasSuffix("_preRestoreBackup") &&
            !key.hasSuffix("_legacy_backup") {
            if let data = d.data(forKey: key), data.count > bestSize {
                bestSize = data.count
                bestUID = String(key.dropFirst(prefix.count))
            }
        }
        return bestUID
    }

    /// Clear guest mode (called on logout / when a real account takes over).
    func exitGuestMode() {
        isGuestMode = false
        UserDefaults.standard.set(false, forKey: "isGuestMode")
    }
    
    
    // MARK: - Authentication Status
    
    func checkAuthenticationStatus() {
        print("🔐 AuthenticationManager: Checking authentication status...")
        
        #if canImport(FirebaseAuth)
        // NOTE: anonymous sessions (used so Firestore rules can require auth pre-login)
        // do NOT count as authenticated — the login gate must still show for them.
        if let firebaseUser = Auth.auth().currentUser, !firebaseUser.isAnonymous {
            print("🔐 AuthenticationManager: Found Firebase user: \(firebaseUser.email ?? "unknown")")
            
            // Create AuthenticatedUser from Firebase user
            // UUID can be random since we use Firebase UID for storage consistency
            let user = AuthenticatedUser(
                id: UUID(), // UUID for app compatibility (not used for storage)
                firebaseUID: firebaseUser.uid, // Firebase UID used for consistent storage keys
                email: firebaseUser.email ?? "unknown@email.com",
                name: firebaseUser.displayName ?? extractNameFromEmail(firebaseUser.email ?? ""),
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                isEmailVerified: firebaseUser.isEmailVerified
            )
            
            self.currentUser = user
            self.isAuthenticated = true
            
            print("✅ AuthenticationManager: User authenticated - \(user.name)")
            print("🔑 AuthenticationManager: Using Firebase UID \(firebaseUser.uid) for consistent storage")
        } else {
            print("🔐 AuthenticationManager: No Firebase user found")
            self.isAuthenticated = false
            self.currentUser = nil
        }
        #else
        print("⚠️ AuthenticationManager: Firebase Auth not available, checking UserDefaults...")
        
        // Fallback to UserDefaults if Firebase not available
        let savedAuth = UserDefaults.standard.bool(forKey: "isAuthenticated")
        if savedAuth, let userData = UserDefaults.standard.data(forKey: "currentUser") {
            if let user = try? JSONDecoder().decode(AuthenticatedUser.self, from: userData) {
                self.currentUser = user
                self.isAuthenticated = true
                print("✅ AuthenticationManager: Restored user from UserDefaults - \(user.name)")
            }
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
        }
        #endif
        
        print("🔐 AuthenticationManager: User is \(isAuthenticated ? "authenticated" : "not authenticated")")
    }
    
    #if canImport(FirebaseAuth)
    /// Link a federated credential to the current anonymous session (preserving the UID
    /// and its data). If the credential already belongs to another account, sign into that
    /// account instead — the caller's claim step then merges the local data in.
    private func linkOrSignIn(with credential: AuthCredential) async throws -> AuthDataResult {
        if let anon = Auth.auth().currentUser, anon.isAnonymous {
            do {
                print("🔗 AuthenticationManager: Upgrading anonymous session -> permanent (link)")
                return try await anon.link(with: credential)
            } catch let error as NSError where
                error.code == AuthErrorCode.credentialAlreadyInUse.rawValue ||
                error.code == AuthErrorCode.emailAlreadyInUse.rawValue ||
                error.code == AuthErrorCode.providerAlreadyLinked.rawValue {
                print("🔗 AuthenticationManager: Credential already belongs to an account - signing into it")
                let updated = (error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential) ?? credential
                return try await Auth.auth().signIn(with: updated)
            }
        }
        return try await Auth.auth().signIn(with: credential)
    }
    #endif

    // MARK: - Login

    func login(email: String, password: String) async {
        print("🔐 AuthenticationManager: Attempting login for: \(email)")
        print("🔑 AuthenticationManager: Password provided: \(password.isEmpty ? "No" : "Yes")")
        print("🔍 AuthenticationManager: Email format valid: \(email.contains("@") ? "Yes" : "No")")
        
        await MainActor.run {
            isLoading = true
            authError = nil
            isNewRegistration = false // This is a login, not registration
        }
        
        #if canImport(FirebaseAuth)
        do {
            print("🔐 AuthenticationManager: Using Firebase Auth for login")
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let firebaseUser = authResult.user
            
            print("✅ AuthenticationManager: Firebase login successful")
            
            // CRITICAL FIX: Force refresh user data to get latest email verification status
            print("🔄 AuthenticationManager: Refreshing user data to ensure accurate email verification status...")
            try await firebaseUser.reload()
            print("📧 AuthenticationManager: Email verification status after refresh: \(firebaseUser.isEmailVerified)")
            
            // Create AuthenticatedUser from Firebase user - USE FIREBASE UID for consistency
            let user = AuthenticatedUser(
                id: UUID(), // Keep using UUID for app compatibility
                firebaseUID: firebaseUser.uid, // Store Firebase UID separately for Firebase operations
                email: firebaseUser.email ?? email,
                name: firebaseUser.displayName ?? extractNameFromEmail(firebaseUser.email ?? email),
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                isEmailVerified: firebaseUser.isEmailVerified // Include fresh verification status
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                // Save authentication state
                saveAuthenticationState()

                // Claim current (guest/anonymous) data for this login + merge with the
                // account's existing local/cloud data, then cloud-back it.
                UserManager.shared.claimLocalDataIntoAccount(firebaseUID: firebaseUser.uid)

                print("✅ AuthenticationManager: Login successful for \(user.name)")
                print("🎉 AuthenticationManager: Welcome back! User ID: \(user.id)")
                print("⏰ AuthenticationManager: Last login: \(Date())")
                print("📱 AuthenticationManager: Session established for: \(user.email)")
            }
            
        } catch {
            let errorMessage = self.getAuthErrorMessage(error)
            
            await MainActor.run {
                self.authError = errorMessage
                self.isLoading = false
                print("❌ AuthenticationManager: Firebase login failed: \(error.localizedDescription)")
            }
        }
        #else
        // Fallback simulation if Firebase not available
        do {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            let user = AuthenticatedUser(
                id: UUID(),
                firebaseUID: "simulated_\(email.replacingOccurrences(of: "@", with: "_"))", // Simulate Firebase UID
                email: email,
                name: extractNameFromEmail(email),
                createdAt: Date(),
                isEmailVerified: false // Simulated users start unverified
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                saveAuthenticationState()
                
                print("✅ AuthenticationManager: Simulated login successful for \(user.name)")
                print("🎉 AuthenticationManager: Welcome back! Simulated User ID: \(user.id)")
                print("⏰ AuthenticationManager: Simulated login time: \(Date())")
                print("📱 AuthenticationManager: Simulated session established for: \(user.email)")
            }
            
        } catch {
            await MainActor.run {
                self.authError = "Login failed. Please try again."
                self.isLoading = false
                print("❌ AuthenticationManager: Simulated login failed: \(error)")
            }
        }
        #endif
    }
    
    // MARK: - Register
    
    func register(email: String, password: String, name: String) async {
        print("🔐 AuthenticationManager: Attempting registration for: \(email)")
        print("👤 AuthenticationManager: User name: \(name)")
        print("🔒 AuthenticationManager: Password length: \(password.count) characters")
        
        await MainActor.run {
            isLoading = true
            authError = nil
            isNewRegistration = true // This is a new registration
        }
        
        #if canImport(FirebaseAuth)
        do {
            print("🔐 AuthenticationManager: Using Firebase Auth for registration")
            // If a guest anonymous session exists, UPGRADE it in place (link) so the
            // account keeps the same Firebase UID — the guest's data stays owned by this
            // login with zero migration. Otherwise fall back to a fresh account.
            let authResult: AuthDataResult
            if let anon = Auth.auth().currentUser, anon.isAnonymous {
                print("🔗 AuthenticationManager: Upgrading anonymous session -> permanent (email link)")
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                authResult = try await anon.link(with: credential)
            } else {
                authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            }
            let firebaseUser = authResult.user
            
            // Update display name
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            print("✅ AuthenticationManager: Firebase registration successful")
            
            // Create AuthenticatedUser from Firebase user - USE FIREBASE UID for consistency
            let user = AuthenticatedUser(
                id: UUID(), // Keep using UUID for app compatibility
                firebaseUID: firebaseUser.uid, // Store Firebase UID separately for Firebase operations
                email: firebaseUser.email ?? email,
                name: name,
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                isEmailVerified: firebaseUser.isEmailVerified // New registrations are unverified by default
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                // Save authentication state
                saveAuthenticationState()

                // Claim the guest/anonymous data for this new account + cloud-back it.
                UserManager.shared.claimLocalDataIntoAccount(firebaseUID: firebaseUser.uid)

                print("✅ AuthenticationManager: Registration successful for \(user.name)")
                print("🎉 AuthenticationManager: New user created - ID: \(user.id)")
                print("📧 AuthenticationManager: Email verified: \(user.email)")
                print("📅 AuthenticationManager: Account created at: \(user.createdAt)")
            }
            
        } catch {
            let errorMessage = self.getAuthErrorMessage(error)
            
            await MainActor.run {
                self.authError = errorMessage
                self.isLoading = false
                print("❌ AuthenticationManager: Firebase registration failed: \(error.localizedDescription)")
                print("🔍 AuthenticationManager: Full error details: \(error)")
                
                // Additional debug for Firebase errors
                if let nsError = error as NSError? {
                    print("🔍 AuthenticationManager: Error domain: \(nsError.domain)")
                    print("🔍 AuthenticationManager: Error code: \(nsError.code)")
                    print("🔍 AuthenticationManager: Error userInfo: \(nsError.userInfo)")
                }
            }
        }
        #else
        // Fallback simulation if Firebase not available
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            let user = AuthenticatedUser(
                id: UUID(),
                firebaseUID: "simulated_\(email.replacingOccurrences(of: "@", with: "_"))", // Simulate Firebase UID
                email: email,
                name: name,
                createdAt: Date(),
                isEmailVerified: false // Simulated registrations start unverified
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                saveAuthenticationState()
                
                print("✅ AuthenticationManager: Simulated registration successful for \(user.name)")
                print("🎉 AuthenticationManager: New simulated user created - ID: \(user.id)")
                print("📧 AuthenticationManager: Email: \(user.email)")
                print("📅 AuthenticationManager: Account created at: \(user.createdAt)")
            }
            
        } catch {
            await MainActor.run {
                self.authError = "Registration failed. Please try again."
                self.isLoading = false
                print("❌ AuthenticationManager: Simulated registration failed: \(error)")
            }
        }
        #endif
    }
    
    // MARK: - Logout
    
    func logout() {
        print("🔐 AuthenticationManager: Logging out user")
        
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            print("✅ AuthenticationManager: Firebase signout successful")
        } catch {
            print("❌ AuthenticationManager: Firebase signout error: \(error.localizedDescription)")
        }
        #endif
        
        // Sign out from Google SDK if available
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        print("✅ AuthenticationManager: Google SDK signout completed")
        #endif
        
        // Note: Apple Sign-In doesn't have explicit SDK logout - tokens are managed by iOS
        print("ℹ️ AuthenticationManager: Apple Sign-In tokens managed by iOS (no explicit logout needed)")
        
        currentUser = nil
        isAuthenticated = false
        authError = nil
        isNewRegistration = false // Reset registration flag
        exitGuestMode() // Returning to the login gate - no longer a guest

        // Drop the account's data from memory so it can't leak into a later login, and point
        // local storage back at the guest identity so "Continue as Guest" shows the un-linked
        // (not-connected) data instead of the account we just left. The account's data stays
        // safe in its own box + cloud and returns when the user signs back in.
        UserManager.shared.signOut()
        if let guestUID = UserDefaults.standard.string(forKey: "guest_local_uid") {
            UserDefaults.standard.set(guestUID, forKey: "last_authenticated_firebase_uid")
        } else {
            UserDefaults.standard.removeObject(forKey: "last_authenticated_firebase_uid")
        }

        // Clear saved authentication state
        clearAuthenticationState()
        
        // Also clear onboarding completion flags to force fresh start
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasCompletedCurrencySelection")
        UserDefaults.standard.removeObject(forKey: "hasSetPrimaryCurrency")
        
        print("✅ AuthenticationManager: Logout successful - cleared all session data")
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async {
        print("🔐 AuthenticationManager: Attempting password reset for: \(email)")
        
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        #if canImport(FirebaseAuth)
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            
            await MainActor.run {
                self.isLoading = false
                print("✅ AuthenticationManager: Password reset email sent successfully")
            }
            
        } catch {
            let errorMessage = self.getAuthErrorMessage(error)
            
            await MainActor.run {
                self.authError = errorMessage
                self.isLoading = false
                print("❌ AuthenticationManager: Password reset failed: \(error.localizedDescription)")
            }
        }
        #else
        // Simulate password reset if Firebase not available
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            self.isLoading = false
            print("✅ AuthenticationManager: Simulated password reset email sent")
        }
        #endif
    }
    
    // MARK: - Email Verification
    
    func sendEmailVerification(retryCount: Int = 0) async {
        print("📧 AuthenticationManager: Sending email verification... (attempt \(retryCount + 1))")
        #if canImport(FirebaseAuth)
        print("🔍 AuthenticationManager: Firebase Auth available: true")
        #else
        print("🔍 AuthenticationManager: Firebase Auth available: false")
        #endif
        
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        #if canImport(FirebaseAuth)
        print("🔥 AuthenticationManager: Using Firebase Auth for email verification")
        do {
            let currentUser = Auth.auth().currentUser
            print("👤 AuthenticationManager: Current Firebase user: \(currentUser?.email ?? "none")")
            print("🔒 AuthenticationManager: User authenticated: \(currentUser != nil)")
            
            if let currentUser = currentUser {
                print("📧 AuthenticationManager: Attempting to send verification email to: \(currentUser.email ?? "unknown")")
                print("✅ AuthenticationManager: User email verified status: \(currentUser.isEmailVerified)")
                
                // Add retry delay if this is a retry attempt
                if retryCount > 0 {
                    let delaySeconds = min(pow(2.0, Double(retryCount)), 30.0) // Exponential backoff, max 30 seconds
                    print("⏳ AuthenticationManager: Waiting \(delaySeconds) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
                
                try await currentUser.sendEmailVerification()
                
                await MainActor.run {
                    self.isLoading = false
                    print("✅ AuthenticationManager: Email verification sent successfully to \(currentUser.email ?? "unknown")")
                    print("📫 AuthenticationManager: Check your email inbox for verification link")
                }
            } else {
                await MainActor.run {
                    self.authError = "No user signed in"
                    self.isLoading = false
                    print("⚠️ AuthenticationManager: No user signed in for email verification")
                    print("👥 AuthenticationManager: Please register or login first")
                }
            }
        } catch {
            let errorMessage = getEmailVerificationErrorMessage(error)
            let shouldRetry = shouldRetryEmailVerification(error, retryCount: retryCount)
            
            if shouldRetry {
                print("🔄 AuthenticationManager: Will retry email verification due to: \(error.localizedDescription)")
                await sendEmailVerification(retryCount: retryCount + 1)
            } else {
                await MainActor.run {
                    self.authError = errorMessage
                    self.isLoading = false
                    print("❌ AuthenticationManager: Email verification failed: \(error.localizedDescription)")
                    print("🚫 AuthenticationManager: Max retries reached or non-recoverable error")
                }
            }
        }
        #else
        print("⚠️ AuthenticationManager: Firebase Auth not available - using simulation mode")
        print("💻 AuthenticationManager: This is likely a development/simulator build")
        
        // Simulate email verification if Firebase not available
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            self.isLoading = false
            print("✅ AuthenticationManager: Simulated email verification sent")
            print("📫 AuthenticationManager: In real Firebase build, email would be sent to user")
        }
        #endif
    }
    
    private func shouldRetryEmailVerification(_ error: Error, retryCount: Int) -> Bool {
        guard retryCount < 3 else { return false } // Max 3 retries
        
        #if canImport(FirebaseAuth)
        if let authError = error as NSError? {
            switch authError.code {
            case AuthErrorCode.tooManyRequests.rawValue:
                print("🕐 AuthenticationManager: Too many requests - will retry with backoff")
                return true
            case AuthErrorCode.networkError.rawValue:
                print("🌐 AuthenticationManager: Network error - will retry")
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }
    
    private func getEmailVerificationErrorMessage(_ error: Error) -> String {
        #if canImport(FirebaseAuth)
        if let authError = error as NSError? {
            switch authError.code {
            case AuthErrorCode.tooManyRequests.rawValue:
                return "Too many email requests. Please wait a few minutes and try again."
            case AuthErrorCode.networkError.rawValue:
                return "Network error. Please check your internet connection and try again."
            case AuthErrorCode.userNotFound.rawValue:
                return "User not found. Please sign in again."
            case AuthErrorCode.invalidAPIKey.rawValue:
                return "Configuration error. Please contact support."
            default:
                let errorDesc = error.localizedDescription
                if errorDesc.contains("unusual activity") {
                    return "Firebase has temporarily blocked email verification due to unusual activity. Please try again in a few minutes, or contact support if this persists."
                }
                return "Failed to send verification email. Please try again later."
            }
        }
        #endif
        return error.localizedDescription
    }
    
    func checkEmailVerification() async -> Bool {
        print("🔍 AuthenticationManager: Checking email verification status...")
        
        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            // Reload user to get latest verification status
            do {
                try await currentUser.reload()
                let isVerified = currentUser.isEmailVerified
                print("📧 AuthenticationManager: Email verification status: \(isVerified ? "verified" : "not verified")")
                return isVerified
            } catch {
                print("❌ AuthenticationManager: Failed to check verification status: \(error.localizedDescription)")
                return false
            }
        } else {
            print("⚠️ AuthenticationManager: No user signed in to check verification")
            return false
        }
        #else
        // For non-Firebase builds, assume verification is always successful after a delay
        print("✅ AuthenticationManager: Simulated email verification check - always returns true")
        return true
        #endif
    }
    
    // MARK: - Social Login
    
    func signInWithGoogle() async {
        print("🔐 AuthenticationManager: Google Sign In requested")
        print("🔐 AuthenticationManager: Current auth state before Google sign in:")
        print("   - isAuthenticated: \(isAuthenticated)")
        print("   - currentUser: \(currentUser?.email ?? "none")")
        print("   - isNewRegistration: \(isNewRegistration)")
        
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        // ENHANCED DEBUG: Verify environment before proceeding
        print("🔍 GOOGLE AUTH DEBUG: ======= ENVIRONMENT CHECK =======")
        print("🔍 GOOGLE AUTH DEBUG: Bundle ID: \(Bundle.main.bundleIdentifier ?? "UNKNOWN")")
        print("🔍 GOOGLE AUTH DEBUG: GoogleSignIn SDK available: \(true)")
        
        #if canImport(FirebaseAuth)
        print("🔍 GOOGLE AUTH DEBUG: Firebase Auth available: true")
        if let currentFirebaseUser = Auth.auth().currentUser {
            print("🔍 GOOGLE AUTH DEBUG: Current Firebase user: \(currentFirebaseUser.email ?? "unknown")")
        } else {
            print("🔍 GOOGLE AUTH DEBUG: No current Firebase user")
        }
        #else
        print("🔍 GOOGLE AUTH DEBUG: Firebase Auth available: false")
        #endif
        
        // Check GoogleService-Info.plist configuration
        if let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") {
            print("🔍 GOOGLE AUTH DEBUG: GoogleService-Info.plist found at: \(url.path)")
            if let plistData = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                print("🔍 GOOGLE AUTH DEBUG: PROJECT_ID: \(plist["PROJECT_ID"] as? String ?? "MISSING")")
                print("🔍 GOOGLE AUTH DEBUG: BUNDLE_ID: \(plist["BUNDLE_ID"] as? String ?? "MISSING")")
                print("🔍 GOOGLE AUTH DEBUG: CLIENT_ID: \(plist["CLIENT_ID"] as? String ?? "MISSING")")
                print("🔍 GOOGLE AUTH DEBUG: GOOGLE_APP_ID: \(plist["GOOGLE_APP_ID"] as? String ?? "MISSING")")
                print("🔍 GOOGLE AUTH DEBUG: REVERSED_CLIENT_ID: \(plist["REVERSED_CLIENT_ID"] as? String ?? "MISSING")")
            }
        } else {
            print("❌ GOOGLE AUTH DEBUG: GoogleService-Info.plist NOT FOUND")
        }
        
        // Check Info.plist URL schemes
        if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
            print("🔍 GOOGLE AUTH DEBUG: Found \(urlTypes.count) URL scheme(s)")
            for (index, urlType) in urlTypes.enumerated() {
                if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                    print("🔍 GOOGLE AUTH DEBUG: URL Type \(index): \(schemes)")
                }
            }
        } else {
            print("❌ GOOGLE AUTH DEBUG: No URL schemes found in Info.plist")
        }
        print("🔍 GOOGLE AUTH DEBUG: =====================================")
        
        // Ensure we always reset loading state on exit
        defer {
            Task { @MainActor in
                if self.isLoading {
                    print("⚠️ AuthenticationManager: Google Sign-In defer block cleaning up loading state")
                    self.isLoading = false
                }
            }
        }
        
        // Check if GoogleSignIn SDK is available
        #if canImport(GoogleSignIn)
        
        do {
            // Get the client ID from Firebase configuration
            print("🔍 GOOGLE AUTH DEBUG: ======= CLIENT ID RETRIEVAL =======")
            guard let clientID = getGoogleClientID() else {
                print("❌ GOOGLE AUTH DEBUG: Failed to get CLIENT_ID")
                print("❌ GOOGLE AUTH DEBUG: Checked sources:")
                print("   - GoogleService-Info.plist CLIENT_ID key")
                print("   - Info.plist GOOGLE_CLIENT_ID key")
                print("❌ GOOGLE AUTH DEBUG: This is why you're getting Error 401: invalid_client")
                await MainActor.run {
                    self.authError = "Google Sign-In configuration error: CLIENT_ID not found. Please contact support."
                    self.isLoading = false
                }
                return
            }
            print("✅ GOOGLE AUTH DEBUG: CLIENT_ID found: \(clientID.prefix(20))...")
            print("🔍 GOOGLE AUTH DEBUG: Full CLIENT_ID: \(clientID)")
            print("🔍 GOOGLE AUTH DEBUG: =====================================")
            
            // Configure Google Sign-In
            print("🔍 GOOGLE AUTH DEBUG: ======= UI CONTEXT SETUP =======")
            guard let windowScene = await MainActor.run(body: {
                let scenes = UIApplication.shared.connectedScenes
                print("🔍 GOOGLE AUTH DEBUG: Found \(scenes.count) connected scene(s)")
                let windowScene = scenes.first as? UIWindowScene
                print("🔍 GOOGLE AUTH DEBUG: WindowScene found: \(windowScene != nil)")
                return windowScene
            }),
            let window = await MainActor.run(body: {
                let windows = windowScene.windows
                print("🔍 GOOGLE AUTH DEBUG: Found \(windows.count) window(s)")
                let window = windows.first
                print("🔍 GOOGLE AUTH DEBUG: Window found: \(window != nil)")
                return window
            }),
            let presentingViewController = await MainActor.run(body: {
                let rootVC = window.rootViewController
                print("🔍 GOOGLE AUTH DEBUG: Root view controller found: \(rootVC != nil)")
                print("🔍 GOOGLE AUTH DEBUG: Root VC type: \(String(describing: type(of: rootVC)))")
                return rootVC
            }) else {
                print("❌ GOOGLE AUTH DEBUG: Failed to get UI context for Google Sign-In")
                await MainActor.run {
                    self.authError = "Unable to present Google Sign-In. Please try again."
                    self.isLoading = false
                }
                return
            }
            print("✅ GOOGLE AUTH DEBUG: UI context ready for presentation")
            print("🔍 GOOGLE AUTH DEBUG: ==================================")
            
            print("🔍 GOOGLE AUTH DEBUG: ======= GOOGLE SDK SETUP =======")
            print("🔍 GOOGLE AUTH DEBUG: Configuring GIDSignIn with CLIENT_ID...")
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("✅ GOOGLE AUTH DEBUG: GIDSignIn configuration complete")
            print("🔍 GOOGLE AUTH DEBUG: Starting sign-in presentation...")
            print("🔍 GOOGLE AUTH DEBUG: ===================================")
            
            // Perform Google Sign-In
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
                DispatchQueue.main.async {
                    print("🔍 GOOGLE AUTH DEBUG: ======= SIGN-IN ATTEMPT =======")
                    print("🔍 GOOGLE AUTH DEBUG: Calling GIDSignIn.signIn...")
                    GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                        print("🔍 GOOGLE AUTH DEBUG: Google Sign-In callback received")
                        
                        if let error = error {
                            print("❌ GOOGLE AUTH DEBUG: Error received from Google SDK:")
                            print("   - Error: \(error.localizedDescription)")
                            print("   - Code: \((error as NSError).code)")
                            print("   - Domain: \((error as NSError).domain)")
                            print("   - UserInfo: \((error as NSError).userInfo)")
                            
                            // Enhanced error analysis
                            if error.localizedDescription.contains("invalid_client") {
                                print("❌ GOOGLE AUTH DEBUG: INVALID CLIENT ERROR DETECTED!")
                                print("   This means your OAuth client is not properly configured")
                                print("   Check: Google Cloud Console → APIs & Services → Credentials")
                                print("   Ensure: Bundle ID matches OAuth client configuration")
                                print("   Ensure: OAuth consent screen is published")
                            }
                            if error.localizedDescription.contains("canceled") || error.localizedDescription.contains("cancelled") {
                                print("ℹ️ GOOGLE AUTH DEBUG: User cancelled sign-in (normal behavior)")
                            }
                            if (error as NSError).domain.contains("GoogleSignIn") {
                                print("⚠️ GOOGLE AUTH DEBUG: This is a GoogleSignIn SDK error")
                            }
                            
                            continuation.resume(throwing: error)
                        } else if let result = result {
                            print("✅ GOOGLE AUTH DEBUG: Sign-in result received successfully")
                            print("   - User ID: \(result.user.userID ?? "unknown")")
                            print("   - Email: \(result.user.profile?.email ?? "unknown")")
                            print("   - Name: \(result.user.profile?.name ?? "unknown")")
                            continuation.resume(returning: result)
                        } else {
                            print("❌ GOOGLE AUTH DEBUG: Nil result and nil error (unexpected)")
                            let unknownError = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error - no result or error returned"])
                            continuation.resume(throwing: unknownError)
                        }
                        print("🔍 GOOGLE AUTH DEBUG: ==============================")
                    }
                }
            }
            
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                await MainActor.run {
                    self.authError = "Failed to get Google ID token"
                    self.isLoading = false
                }
                return
            }
            
            let accessToken = user.accessToken.tokenString
            
            // Create Firebase credential with Google token
            #if canImport(FirebaseAuth)
            let credential = FirebaseAuth.GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Sign in to Firebase with Google credential. If a guest anonymous session
            // exists, UPGRADE it (link) so the account keeps the same UID and the guest's
            // data stays owned. If the Google account already exists elsewhere, fall back
            // to signing into it (data is merged afterwards by the claim step).
            let authResult = try await linkOrSignIn(with: credential)
            let firebaseUser = authResult.user
            
            print("✅ AuthenticationManager: Google Sign-In successful")
            
            // Create AuthenticatedUser from Firebase user
            let authenticatedUser = AuthenticatedUser(
                id: UUID(),
                firebaseUID: firebaseUser.uid,
                email: firebaseUser.email ?? user.profile?.email ?? "unknown@email.com",
                name: firebaseUser.displayName ?? user.profile?.name ?? extractNameFromEmail(firebaseUser.email ?? ""),
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                isEmailVerified: firebaseUser.isEmailVerified
            )
            
            // ENHANCED: Determine if this should be treated as a new registration
            let firebaseIsNewUser = authResult.additionalUserInfo?.isNewUser ?? false
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            // Check if user has complete Firebase profile data (for Google sign-ins)
            let hasFirebaseDisplayName = firebaseUser.displayName != nil && 
                                       !firebaseUser.displayName!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // Update UI state synchronously
            await MainActor.run {
                self.currentUser = authenticatedUser
                self.isAuthenticated = true
                self.isLoading = false
                
                // Treat as new registration if:
                // 1. Firebase says it's a new user, OR
                // 2. User has no onboarding completion AND no Firebase profile data (could be deleted account signing in again)
                // 3. Users with complete Firebase profile (like Google sign-in) should NOT be treated as new
                self.isNewRegistration = firebaseIsNewUser || (!hasCompletedOnboarding && !hasFirebaseDisplayName)
                
                // Save authentication state
                saveAuthenticationState()
            }
            
            // SYNC FIX: Update UserManager with Google profile data to ensure consistent name checking
            await syncGoogleProfileToUserManager(authenticatedUser)

            // Claim the guest/anonymous data for this account + cloud-back it.
            await MainActor.run {
                UserManager.shared.claimLocalDataIntoAccount(firebaseUID: firebaseUser.uid)
            }

            print("✅ AuthenticationManager: Google Sign-In successful for \(authenticatedUser.name)")
            print("🔐 AuthenticationManager: Post-Google auth state:")
            print("   - isAuthenticated: \(self.isAuthenticated)")
            print("   - currentUser: \(authenticatedUser.email)")
            print("   - firebaseIsNewUser: \(firebaseIsNewUser)")
            print("   - hasCompletedOnboarding: \(hasCompletedOnboarding)")
            print("   - hasFirebaseDisplayName: \(hasFirebaseDisplayName)")
            print("   - firebaseDisplayName: '\(firebaseUser.displayName ?? "nil")'")
            print("   - isNewRegistration: \(self.isNewRegistration) (final decision)")
            print("   - userName: '\(authenticatedUser.name)'")
            print("   - firebaseUID: \(authenticatedUser.firebaseUID)")
            #else
            // If Firebase Auth is not available, create user directly from Google info
            let authenticatedUser = AuthenticatedUser(
                id: UUID(),
                firebaseUID: "google_\(user.userID ?? UUID().uuidString)",
                email: user.profile?.email ?? "unknown@email.com",
                name: user.profile?.name ?? "Google User",
                createdAt: Date(),
                isEmailVerified: false // Google users need separate email verification
            )
            
            await MainActor.run {
                self.currentUser = authenticatedUser
                self.isAuthenticated = true
                self.isLoading = false
                self.isNewRegistration = true // Assume new user for non-Firebase builds
                
                saveAuthenticationState()
                
                print("✅ AuthenticationManager: Google Sign-In successful (non-Firebase) for \(authenticatedUser.name)")
            }
            #endif
            
        } catch {
            print("🔍 GOOGLE AUTH DEBUG: ======= CATCH BLOCK ERROR =======")
            print("❌ GOOGLE AUTH DEBUG: Exception caught in signInWithGoogle:")
            print("   - Error: \(error.localizedDescription)")
            print("   - Code: \((error as NSError).code)")
            print("   - Domain: \((error as NSError).domain)")
            print("   - UserInfo: \((error as NSError).userInfo)")
            
            // Provide specific guidance based on error
            let userFriendlyMessage: String
            if error.localizedDescription.contains("invalid_client") {
                userFriendlyMessage = "Google Sign-In setup incomplete. Please check OAuth client configuration in Google Cloud Console."
            } else if error.localizedDescription.contains("canceled") || error.localizedDescription.contains("cancelled") {
                userFriendlyMessage = "" // Silent for cancellation
            } else {
                userFriendlyMessage = "Google Sign-In failed: \(error.localizedDescription)"
            }
            
            await MainActor.run {
                self.authError = userFriendlyMessage.isEmpty ? nil : userFriendlyMessage
                self.isLoading = false
                print("❌ AuthenticationManager: Google Sign-In failed: \(error.localizedDescription)")
            }
            print("🔍 GOOGLE AUTH DEBUG: ===================================")
        }
        #else
        // GoogleSignIn SDK not available - show helpful message
        await MainActor.run {
            self.authError = "Google Sign-In requires additional setup. Please add GoogleSignIn SDK to the project."
            self.isLoading = false
            print("⚠️ AuthenticationManager: GoogleSignIn SDK not available. Add 'https://github.com/google/GoogleSignIn-iOS' to Swift Package Manager.")
        }
        #endif
    }
    
    private func getGoogleClientID() -> String? {
        #if canImport(FirebaseAuth)
        // Try to get client ID from Firebase configuration
        if let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
           let plistData = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
           let clientID = plist["CLIENT_ID"] as? String {
            return clientID
        }
        #endif
        
        // Fallback: try Info.plist
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String {
            return clientID
        }
        
        return nil
    }
    
    // MARK: - Debug Functions for Duplicate Account Issues
    
    func debugAuthenticationProviders() {
        #if canImport(FirebaseAuth)
        guard let firebaseUser = Auth.auth().currentUser else {
            print("🔍 DEBUG: No Firebase user currently signed in")
            return
        }
        
        print("🔍 DEBUG: ======= FIREBASE USER ANALYSIS =======")
        print("🔍 DEBUG: Email: \(firebaseUser.email ?? "nil")")
        print("🔍 DEBUG: Display Name: \(firebaseUser.displayName ?? "nil")")
        print("🔍 DEBUG: UID: \(firebaseUser.uid)")
        print("🔍 DEBUG: Email Verified: \(firebaseUser.isEmailVerified)")
        print("🔍 DEBUG: Provider Data Count: \(firebaseUser.providerData.count)")
        
        for (index, provider) in firebaseUser.providerData.enumerated() {
            print("🔍 DEBUG: Provider \(index + 1):")
            print("🔍 DEBUG:   - Provider ID: \(provider.providerID)")
            print("🔍 DEBUG:   - Email: \(provider.email ?? "nil")")
            print("🔍 DEBUG:   - Display Name: \(provider.displayName ?? "nil")")
            print("🔍 DEBUG:   - UID: \(provider.uid)")
        }
        
        // Check for duplicate providers
        let providerIDs = firebaseUser.providerData.map { $0.providerID }
        let hasBothGoogleAndEmail = providerIDs.contains("google.com") && providerIDs.contains("password")
        
        print("🔍 DEBUG: Has both Google and Email providers: \(hasBothGoogleAndEmail)")
        
        if hasBothGoogleAndEmail {
            print("⚠️ DEBUG: DUPLICATE ACCOUNT DETECTED! Same email registered with both Google and Email/Password")
            print("⚠️ DEBUG: This can cause onboarding confusion - consider account linking or cleanup")
        }
        
        print("🔍 DEBUG: =====================================")
        #else
        print("🔍 DEBUG: Firebase not available for provider analysis")
        #endif
    }
    
    func cleanupDuplicateAccount() async {
        #if canImport(FirebaseAuth)
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ DEBUG: No Firebase user to cleanup")
            return
        }
        
        let providerIDs = firebaseUser.providerData.map { $0.providerID }
        let hasBothGoogleAndEmail = providerIDs.contains("google.com") && providerIDs.contains("password")
        
        if hasBothGoogleAndEmail {
            print("🧹 DEBUG: Cleaning up duplicate account...")
            print("🧹 DEBUG: Unlinking email/password provider to keep only Google")
            
            do {
                // Unlink the email/password provider, keep Google
                let _ = try await firebaseUser.unlink(fromProvider: "password")
                print("✅ DEBUG: Successfully unlinked email/password provider")
                
                // Refresh user data
                try await firebaseUser.reload()
                print("✅ DEBUG: User data refreshed")
                
                // Re-check providers
                debugAuthenticationProviders()
                
            } catch {
                print("❌ DEBUG: Failed to cleanup duplicate account: \(error.localizedDescription)")
            }
        } else {
            print("✅ DEBUG: No duplicate providers found - account is clean")
        }
        #else
        print("❌ DEBUG: Firebase not available for account cleanup")
        #endif
    }
    
    func signInWithApple() async {
        print("🔐 AuthenticationManager: Apple Sign In requested")
        print("🔐 AuthenticationManager: Current auth state before Apple sign in:")
        print("   - isAuthenticated: \(isAuthenticated)")
        print("   - currentUser: \(currentUser?.email ?? "none")")
        print("   - isNewRegistration: \(isNewRegistration)")
        
        await MainActor.run {
            isLoading = true
            authError = nil
        }
        
        do {
            // Create Apple Sign-In request
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            // Create authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            // Perform Apple Sign-In
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
                Task { @MainActor in
                    let delegate = AppleSignInDelegate { result in
                        switch result {
                        case .success(let credential):
                            continuation.resume(returning: credential)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    authorizationController.delegate = delegate
                    authorizationController.presentationContextProvider = delegate
                    authorizationController.performRequests()
                    
                    // Keep delegate alive
                    objc_setAssociatedObject(authorizationController, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
            
            let credential = result
            guard let identityToken = credential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                await MainActor.run {
                    self.authError = "Failed to get Apple ID token"
                    self.isLoading = false
                }
                return
            }
            
            // Extract user information
            let email: String = credential.email ?? ""
            let firstName: String = credential.fullName?.givenName ?? ""
            let lastName: String = credential.fullName?.familyName ?? ""
            let fullName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
            
            #if canImport(FirebaseAuth)
            // Create Firebase credential with Apple token
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nil,
                fullName: credential.fullName
            )
            
            // Sign in to Firebase with Apple credential. Upgrade a guest anonymous session
            // in place (link) when possible so data stays owned; otherwise sign into the
            // existing account and let the claim step merge the data.
            let authResult = try await linkOrSignIn(with: firebaseCredential)
            let firebaseUser = authResult.user

            print("✅ AuthenticationManager: Apple Sign-In successful")
            
            // Create AuthenticatedUser from Firebase user
            let userEmail = firebaseUser.email ?? email
            let userName = firebaseUser.displayName ?? (fullName.isEmpty ? extractNameFromEmail(userEmail) : fullName)
            
            let authenticatedUser = AuthenticatedUser(
                id: UUID(),
                firebaseUID: firebaseUser.uid,
                email: userEmail,
                name: userName,
                createdAt: firebaseUser.metadata.creationDate ?? Date(),
                isEmailVerified: firebaseUser.isEmailVerified
            )
            
            // Check if user has complete Firebase profile data (for Apple sign-ins)
            let hasFirebaseDisplayName = firebaseUser.displayName != nil && 
                                       !firebaseUser.displayName!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // ENHANCED: Determine if this should be treated as a new registration
            let firebaseIsNewUser = authResult.additionalUserInfo?.isNewUser ?? false
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            await MainActor.run {
                self.currentUser = authenticatedUser
                self.isAuthenticated = true
                self.isLoading = false
                
                // Treat as new registration if:
                // 1. Firebase says it's a new user, OR
                // 2. User has no onboarding completion AND no Firebase profile data (could be deleted account signing in again)
                // 3. Users with complete Firebase profile (like Apple sign-in) should NOT be treated as new
                self.isNewRegistration = firebaseIsNewUser || (!hasCompletedOnboarding && !hasFirebaseDisplayName)
                
                // Save authentication state
                saveAuthenticationState()
            }
            
            // SYNC FIX: Update UserManager with Apple profile data to ensure consistent name checking
            await syncAppleProfileToUserManager(authenticatedUser)

            // Claim the guest/anonymous data for this account + cloud-back it.
            await MainActor.run {
                UserManager.shared.claimLocalDataIntoAccount(firebaseUID: firebaseUser.uid)
            }

            print("✅ AuthenticationManager: Apple Sign-In successful for \(authenticatedUser.name)")
            print("🔐 AuthenticationManager: Post-Apple auth state:")
            print("   - isAuthenticated: \(self.isAuthenticated)")
            print("   - currentUser: \(authenticatedUser.email)")
            print("   - firebaseIsNewUser: \(firebaseIsNewUser)")
            print("   - hasCompletedOnboarding: \(hasCompletedOnboarding)")
            print("   - hasFirebaseDisplayName: \(hasFirebaseDisplayName)")
            print("   - firebaseDisplayName: '\(firebaseUser.displayName ?? "nil")'")
            print("   - isNewRegistration: \(self.isNewRegistration) (final decision)")
            print("   - userName: '\(authenticatedUser.name)'")
            print("   - firebaseUID: \(authenticatedUser.firebaseUID)")
            print("   - fullName from Apple: '\(fullName)'")
            print("   - email from Apple: '\(email)'")
            #else
            // If Firebase Auth is not available, create user directly from Apple info
            let authenticatedUser = AuthenticatedUser(
                id: UUID(),
                firebaseUID: "apple_\(credential.user)",
                email: email.isEmpty ? "apple_user@example.com" : email,
                name: fullName.isEmpty ? "Apple User" : fullName,
                createdAt: Date(),
                isEmailVerified: false // Apple users need separate email verification
            )
            
            await MainActor.run {
                self.currentUser = authenticatedUser
                self.isAuthenticated = true
                self.isLoading = false
                self.isNewRegistration = true // Assume new user for non-Firebase builds
                
                saveAuthenticationState()
            }
            
            // SYNC FIX: Update UserManager with Apple profile data (non-Firebase)
            await syncAppleProfileToUserManager(authenticatedUser)
            
            print("✅ AuthenticationManager: Apple Sign-In successful (non-Firebase) for \(authenticatedUser.name)")
            #endif
            
        } catch {
            await MainActor.run {
                // Enhanced error messaging for common Apple Sign-In issues
                let errorMessage: String
                if error.localizedDescription.contains("identity provider configuration") {
                    errorMessage = """
                    Apple Sign-In configuration error. Please check:
                    1. Apple Developer Console: Enable 'Sign In with Apple' for your App ID
                    2. Firebase Console: Enable Apple as a sign-in provider
                    3. Ensure bundle ID matches: com.dante.cashmonki
                    """
                } else {
                    errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                }
                
                self.authError = errorMessage
                self.isLoading = false
                print("❌ AuthenticationManager: Apple Sign-In failed: \(error.localizedDescription)")
                
                // Detailed error debugging
                if let nsError = error as NSError? {
                    print("🔍 AuthenticationManager: Apple Sign-In Error Details:")
                    print("   - Domain: \(nsError.domain)")
                    print("   - Code: \(nsError.code)")
                    print("   - UserInfo: \(nsError.userInfo)")
                    print("   - Localized Description: \(nsError.localizedDescription)")
                }
            }
        }
    }
    
    func signInWithFacebook() async {
        print("🔐 AuthenticationManager: Facebook Sign In requested")
        // TODO: Implement Facebook Sign In
        await MainActor.run {
            self.authError = "Facebook Sign In not yet implemented"
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractNameFromEmail(_ email: String) -> String {
        let components = email.components(separatedBy: "@")
        return components.first?.capitalized ?? "User"
    }
    
    
    private func saveAuthenticationState() {
        // A real account now owns the session — no longer a guest.
        if isGuestMode {
            isGuestMode = false
            UserDefaults.standard.set(false, forKey: "isGuestMode")
        }
        // TODO: Save to UserDefaults or Keychain
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        if let user = currentUser {
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "currentUser")
            }
        }
    }
    
    // MARK: - Google Profile Sync Fix
    
    /// Sync Google profile data to UserManager to ensure consistent name checking
    private func syncGoogleProfileToUserManager(_ authenticatedUser: AuthenticatedUser) async {
        print("🔄 AuthenticationManager: ======= SYNCING GOOGLE PROFILE TO USER MANAGER =======")
        print("🔄 AuthenticationManager: Authenticated user name: '\(authenticatedUser.name)'")
        print("🔄 AuthenticationManager: Authenticated user email: '\(authenticatedUser.email)'")
        
        // Get or create user profile in UserManager
        let userManager = UserManager.shared
        
        // Check if user profile exists
        if userManager.hasUserProfile {
            print("🔄 AuthenticationManager: User profile exists, updating name...")
            
            // Update existing profile with Google data
            await MainActor.run {
                userManager.currentUser.name = authenticatedUser.name
                print("✅ AuthenticationManager: Updated UserManager name to: '\(userManager.currentUser.name)'")
                
                // Also sync to Firebase to ensure consistency
                Task { @MainActor in
                    userManager.syncToFirebase { success in
                        print("🔥 AuthenticationManager: Firebase sync result: \(success ? "✅ Success" : "❌ Failed")")
                    }
                }
            }
        } else {
            print("🔄 AuthenticationManager: No user profile exists, creating new one...")
            
            // Create new user data from Google data
            let defaultWallet = AccountData(
                id: UUID(),
                name: authenticatedUser.name + "'s Wallet",
                type: .personal,
                currency: .php,
                isDefault: true
            )
            
            let newUserData = UserData(
                id: authenticatedUser.id,
                name: authenticatedUser.name,
                email: authenticatedUser.email,
                transactions: [],
                accounts: [defaultWallet],
                onboardingCompleted: 0, // New user starts onboarding
                enableFirebaseSync: true // Google users likely want sync
            )
            
            await MainActor.run {
                userManager.currentUser = newUserData
                print("✅ AuthenticationManager: Created new UserManager profile with name: '\(newUserData.name)'")
                
                // Sync to Firebase
                Task { @MainActor in
                    userManager.syncToFirebase { success in
                        print("🔥 AuthenticationManager: New profile Firebase sync result: \(success ? "✅ Success" : "❌ Failed")")
                    }
                }
            }
        }
        
        print("🔄 AuthenticationManager: ======= GOOGLE PROFILE SYNC COMPLETE =======")
    }
    
    /// Sync Apple profile data to UserManager to ensure consistent name checking
    private func syncAppleProfileToUserManager(_ authenticatedUser: AuthenticatedUser) async {
        print("🔄 AuthenticationManager: ======= SYNCING APPLE PROFILE TO USER MANAGER =======")
        print("🔄 AuthenticationManager: Authenticated user name: '\(authenticatedUser.name)'")
        print("🔄 AuthenticationManager: Authenticated user email: '\(authenticatedUser.email)'")
        
        // Get or create user profile in UserManager
        let userManager = UserManager.shared
        
        // Check if user profile exists
        if userManager.hasUserProfile {
            print("🔄 AuthenticationManager: User profile exists, updating name...")
            
            // Update existing profile with Apple data
            await MainActor.run {
                userManager.currentUser.name = authenticatedUser.name
                print("✅ AuthenticationManager: Updated UserManager name to: '\(userManager.currentUser.name)'")
                
                // Also sync to Firebase to ensure consistency
                Task { @MainActor in
                    userManager.syncToFirebase { success in
                        print("🔥 AuthenticationManager: Firebase sync result: \(success ? "✅ Success" : "❌ Failed")")
                    }
                }
            }
        } else {
            print("🔄 AuthenticationManager: No user profile exists, creating new one...")
            
            // Create new user data from Apple data
            let defaultWallet = AccountData(
                id: UUID(),
                name: authenticatedUser.name + "'s Wallet",
                type: .personal,
                currency: .php,
                isDefault: true
            )
            
            let newUserData = UserData(
                id: authenticatedUser.id,
                name: authenticatedUser.name,
                email: authenticatedUser.email,
                transactions: [],
                accounts: [defaultWallet],
                onboardingCompleted: 0, // New user starts onboarding
                enableFirebaseSync: true // Apple users likely want sync
            )
            
            await MainActor.run {
                userManager.currentUser = newUserData
                print("✅ AuthenticationManager: Created new UserManager profile with name: '\(newUserData.name)'")
                
                // Sync to Firebase
                Task { @MainActor in
                    userManager.syncToFirebase { success in
                        print("🔥 AuthenticationManager: New profile Firebase sync result: \(success ? "✅ Success" : "❌ Failed")")
                    }
                }
            }
        }
        
        print("🔄 AuthenticationManager: ======= APPLE PROFILE SYNC COMPLETE =======")
    }
    
    private func clearAuthenticationState() {
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
    
    private func getAuthErrorMessage(_ error: Error) -> String {
        #if canImport(FirebaseAuth)
        if let authError = error as NSError? {
            switch authError.code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                return "An account with this email already exists. Please try logging in instead, or use Google/Apple sign-in if you originally signed up that way."
            case AuthErrorCode.invalidEmail.rawValue:
                return "Please enter a valid email address."
            case AuthErrorCode.weakPassword.rawValue:
                return "Password is too weak. Please choose a stronger password."
            case AuthErrorCode.userNotFound.rawValue:
                return "No account found with this email address."
            case AuthErrorCode.wrongPassword.rawValue:
                return "Incorrect password. Please try again."
            case AuthErrorCode.userDisabled.rawValue:
                return "This account has been disabled."
            case AuthErrorCode.networkError.rawValue:
                return "Network error. Please check your connection."
            case AuthErrorCode.tooManyRequests.rawValue:
                return "Too many attempts. Please try again later."
            default:
                return "Authentication failed. Please try again."
            }
        }
        #endif
        return error.localizedDescription
    }
}

// MARK: - AuthenticatedUser Model

struct AuthenticatedUser: Identifiable, Codable {
    let id: UUID
    let firebaseUID: String // Firebase user's unique ID for consistent Firebase operations
    let email: String
    var name: String // Changed to var to allow name updates during onboarding
    let createdAt: Date
    var isEmailVerified: Bool // Email verification status from Firebase Auth
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.first?.uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.first?.uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
}

// MARK: - Apple Sign-In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(credential))
        } else {
            completion(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get Apple ID credential"])))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}