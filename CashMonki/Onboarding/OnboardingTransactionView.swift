//
//  OnboardingTransactionView.swift
//  CashMonki
//
//  Created by Claude on 11/11/25.
//

import SwiftUI
import PhotosUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct OnboardingTransactionView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onBack: (() -> Void)?
    
    /// Check if user has completed transaction onboarding
    static var hasCompletedTransactionOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedTransactionOnboarding")
    }
    
    // Photo handling state (same as OnboardingTransactionSheet)
    @State private var isDirectPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isAddPresented = false
    @State private var currentPhotoSource: PhotoSource = .upload
    @State private var selectedDirectPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var isAnalyzingReceipt = false
    
    // Completion tracking
    @State private var hasCompletedAction = false
    @State private var hasSkipped = false
    @State private var isDismissing = false
    @State private var hasShownWelcomeToast = false // Prevent multiple toast calls
    
    // Receipt confirmation state
    @State private var showingReceiptConfirmation = false
    @State private var pendingReceiptImage: UIImage?
    @State private var pendingReceiptAnalysis: ReceiptAnalysis?
    @State private var showingUsageLimitModal = false
    
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var dailyUsageManager = DailyUsageManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    
    /// Check if current user is Gmail user
    private var isGmailUser: Bool {
        #if canImport(FirebaseAuth)
        if let currentUser = Auth.auth().currentUser {
            return currentUser.providerData.contains { $0.providerID == "google.com" }
        }
        return false
        #else
        return false
        #endif
    }
    
    private var canContinue: Bool {
        hasCompletedAction || hasSkipped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Icon and Title Section
                    iconAndTitleSection
                    
                    // Action tiles
                    VStack(spacing: 16) {
                        ActionTile(
                            icon: "upload-01",
                            title: "Upload",
                            subtitle: "Upload a receipt and we'll get the details",
                            onTap: {
                                handleUploadAction()
                            }
                        )
                        
                        ActionTile(
                            icon: "scan",
                            title: "Scan", 
                            subtitle: "Scan a receipt and we'll get the details",
                            onTap: {
                                handleScanAction()
                            }
                        )
                        
                        ActionTile(
                            icon: "plus",
                            title: "Add",
                            subtitle: "Add transaction details manually"
                        ) {
                            handleAddAction()
                        }
                    }
                    
                    Spacer(minLength: 80) // Space for bottom button
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 120) // Space for fixed bottom button
            }
            
            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .transactionAddition,
                isGmailUser: isGmailUser
            )
            
            // Fixed Bottom Button
            FixedBottomGroup.primary(
                title: "Complete",
                action: {
                    // Complete onboarding - welcome toast will be shown by parent
                    completeOnboarding()
                }
            )
        }
        .background(AppColors.backgroundWhite)
        .navigationBarHidden(true)
        .offset(y: isDismissing ? UIScreen.main.bounds.height : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isDismissing)
        .photosPicker(isPresented: $isDirectPhotoPickerPresented, selection: $selectedDirectPhoto, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedDirectPhoto) { _, newItem in
            if let newItem = newItem {
                handlePhotoSelection(newItem)
                // DO NOT auto-dismiss here - only dismiss on successful transaction creation
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraView(
                isPresented: $isCameraPresented,
                onPhotoTaken: { image in
                    DispatchQueue.main.async {
                        capturedImage = image
                        handleCameraCapture(image)
                        // DO NOT auto-dismiss here - only dismiss on successful transaction creation
                    }
                },
                onCancel: {
                    print("📸 OnboardingTransactionView: Camera cancelled")
                    isCameraPresented = false
                }
            )
        }
        .sheet(isPresented: $isAddPresented) {
            AddTransactionSheet(
                isPresented: $isAddPresented,
                primaryCurrency: CurrencyPreferences.shared.primaryCurrency,
                onSave: { transaction in
                    DispatchQueue.main.async {
                        userManager.addTransaction(transaction)
                        
                        // Show success toast (same as HomePage timing - 1.5s)
                        toastManager.showSuccess("Transaction added!")
                        
                        hasCompletedAction = true
                        isAddPresented = false
                        
                        // Mark transaction onboarding as completed
                        UserDefaults.standard.set(true, forKey: "hasCompletedTransactionOnboarding")
                        
                        // Dismiss onboarding when transaction toast completes (1.5s total)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                // Close onboarding sheet - welcome toast will be shown by parent
                                completeOnboarding()
                            }
                        }
                    }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            print("🔥 TRANSITION DEBUG: OnboardingTransactionView appeared")
            print("🎯 OnboardingTransactionView: Starting transaction onboarding process")
            print("🔍 OnboardingTransactionView: Completion status - hasCompletedTransactionOnboarding: \(OnboardingTransactionView.hasCompletedTransactionOnboarding)")
        }
        .onDisappear {
            print("🔥 TRANSITION DEBUG: OnboardingTransactionView disappeared")
        }
        .sheet(isPresented: $showingReceiptConfirmation) {
            if let pendingImage = pendingReceiptImage, let pendingAnalysis = pendingReceiptAnalysis {
                ReceiptConfirmationSheet(
                    originalImage: pendingImage,
                    analysis: pendingAnalysis,
                    primaryCurrency: CurrencyPreferences.shared.primaryCurrency,
                    onConfirm: { confirmedAnalysis, note in
                        print("✅ OnboardingTransactionView: Receipt confirmed, creating transaction")
                        
                        // Create transaction from confirmed analysis (same logic as HomePage)
                        let categoryResult = CategoriesManager.shared.findCategoryOrSubcategory(by: confirmedAnalysis.category)
                        let categoryId = categoryResult.category?.id ?? categoryResult.subcategory?.id
                        
                        // Determine if this is income based on category type
                        let isIncome = categoryResult.category?.type == .income || categoryResult.subcategory?.type == .income
                        
                        let rateManager = CurrencyRateManager.shared
                        let confirmedTransaction = rateManager.createTransaction(
                            accountID: userManager.currentUser.id,
                            walletID: AccountManager.shared.selectedSubAccountId,
                            category: confirmedAnalysis.category,
                            categoryId: categoryId,
                            originalAmount: confirmedAnalysis.totalAmount,
                            originalCurrency: confirmedAnalysis.currency,
                            date: confirmedAnalysis.date,
                            merchantName: confirmedAnalysis.merchantName,
                            note: note,
                            items: confirmedAnalysis.items,
                            isIncome: isIncome
                        )
                        
                        print("💫 OnboardingTransactionView: Created confirmed transaction with currency conversion:")
                        print("   - Original: \(confirmedAnalysis.currency.symbol)\(confirmedAnalysis.totalAmount)")
                        print("   - Converted: \(confirmedTransaction.primaryCurrency.symbol)\(abs(confirmedTransaction.amount))")
                        
                        // Add transaction to user account
                        userManager.addTransaction(confirmedTransaction)
                        
                        // Clean up pending data first
                        pendingReceiptImage = nil
                        pendingReceiptAnalysis = nil
                        showingReceiptConfirmation = false
                        
                        // Show success toast after sheet dismissal (same as HomePage timing - 1.5s)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            toastManager.showSuccess("Transaction added!")
                        }
                        
                        // Mark transaction onboarding as completed
                        UserDefaults.standard.set(true, forKey: "hasCompletedTransactionOnboarding")
                        
                        // Mark as completed and dismiss onboarding when transaction toast completes (1.6s total)
                        hasCompletedAction = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { // 0.1s + 1.5s toast = 1.6s total
                            // Close onboarding sheet - welcome toast will be shown by parent
                            completeOnboarding()
                        }
                    },
                    onCancel: {
                        print("❌ OnboardingTransactionView: Receipt confirmation cancelled")
                        // Clean up pending data
                        pendingReceiptImage = nil
                        pendingReceiptAnalysis = nil
                        showingReceiptConfirmation = false
                        // Stay on onboarding - user can try again
                    }
                )
            }
        }
        .sheet(isPresented: $showingUsageLimitModal) {
            UsageLimitModal(
                isPresented: $showingUsageLimitModal,
                onUpgradeToProTapped: {
                    // Open RevenueCat paywall or subscription flow
                    print("📊 OnboardingTransactionView: User wants to upgrade to Pro")
                    // TODO: Implement RevenueCat subscription flow
                }
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Back Button
            Button(action: {
                print("🔥 TRANSITION DEBUG: Back button tapped in OnboardingTransactionView")
                print("🔥 TRANSITION DEBUG: onBack callback available: \(onBack != nil)")
                if let onBack = onBack {
                    print("🔥 TRANSITION DEBUG: Calling onBack() callback...")
                    onBack()
                    print("🔥 TRANSITION DEBUG: onBack() callback completed")
                } else {
                    print("🔥 TRANSITION DEBUG: No onBack callback - dismissing sheet")
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
            Text("Complete Setup")
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
        VStack(spacing: 12) {
            VStack(alignment: .center, spacing: 10) {
                Text("☕")
                    .font(.system(size: 48))
            }
            .padding(8)
            .frame(width: 100, height: 100, alignment: .center)
            .background(AppColors.surfacePrimary)
            .cornerRadius(200)
            
            Text("Add something you bought today!")
                .font(
                    Font.custom("Overused Grotesk", size: 30)
                        .weight(.semibold)
                )
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.foregroundPrimary)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleUploadAction() {
        // Check daily usage limit before proceeding
        guard dailyUsageManager.canUseReceiptAnalysis() else {
            print("📊 OnboardingTransactionView: Upload blocked - daily limit reached")
            showingUsageLimitModal = true
            return
        }
        
        currentPhotoSource = .upload
        isDirectPhotoPickerPresented = true
    }
    
    private func handleScanAction() {
        // Check daily usage limit before proceeding
        guard dailyUsageManager.canUseReceiptAnalysis() else {
            print("📊 OnboardingTransactionView: Scan blocked - daily limit reached")
            showingUsageLimitModal = true
            return
        }
        
        print("📸 OnboardingTransactionView: Scan action triggered")
        
        #if targetEnvironment(simulator)
        print("📸 OnboardingTransactionView: Running in simulator - camera may not work properly")
        #endif
        
        currentPhotoSource = .camera
        print("📸 OnboardingTransactionView: About to present camera")
        isCameraPresented = true
        print("📸 OnboardingTransactionView: isCameraPresented set to true")
    }
    
    private func handleAddAction() {
        isAddPresented = true
    }
    
    private func handleSkipAction() {
        // Set skip flag for gate validation
        UserDefaults.standard.set(true, forKey: "hasSkippedTransactionOnboarding")
        hasSkipped = true
        print("🎯 OnboardingTransactionView: User skipped transaction creation")
        
        // Complete onboarding immediately
        completeOnboarding()
    }
    
    // MARK: - Photo Processing
    
    private func handlePhotoSelection(_ item: PhotosPickerItem) {
        print("📷 OnboardingTransactionView: Photo selected from library")
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data?):
                    if let uiImage = UIImage(data: data) {
                        processReceiptImage(uiImage, source: .upload)
                    }
                case .success(nil):
                    print("❌ OnboardingTransactionView: No data from photo")
                case .failure(let error):
                    print("❌ OnboardingTransactionView: Error loading photo: \(error)")
                }
                selectedDirectPhoto = nil
            }
        }
    }
    
    private func handleCameraCapture(_ image: UIImage) {
        print("📷 OnboardingTransactionView: Photo captured from camera")
        processReceiptImage(image, source: .camera)
    }
    
    private func processReceiptImage(_ image: UIImage, source: PhotoSource) {
        print("🔍 OnboardingTransactionView: Processing receipt image from \(source)")
        
        DispatchQueue.main.async {
            isAnalyzingReceipt = true
        }
        
        // Show scanning toast
        toastManager.startReceiptAnalysis()
        
        // Process with AIReceiptAnalyzer (SECURE)
        let creationTime = Date()
        Task {
            do {
                let analysis = try await AIReceiptAnalyzer.shared.analyzeReceiptSecure(image: image, creationTime: creationTime)
                await MainActor.run {
                    isAnalyzingReceipt = false
                    print("✅ OnboardingTransactionView: Receipt analysis successful - \(analysis)")
                    
                    // Record usage for receipt analysis (onboarding = free, doesn't count towards daily limit)
                    dailyUsageManager.recordReceiptAnalysis(isOnboarding: true)
                    print("📊 OnboardingTransactionView: Onboarding receipt analysis - free usage")
                    
                    // Complete the toast animation and show confirmation sheet (like HomePage does)
                    toastManager.completeReceiptAnalysis {
                        print("🎉 OnboardingTransactionView: Receipt processed successfully")
                        
                        // Store pending data and show confirmation sheet
                        self.pendingReceiptImage = image
                        self.pendingReceiptAnalysis = analysis
                        self.showingReceiptConfirmation = true
                    }
                }
            } catch {
                await MainActor.run {
                    isAnalyzingReceipt = false
                    print("❌ OnboardingTransactionView: Receipt analysis failed (SECURE): \(error)")
                    toastManager.failReceiptAnalysis(error: error) {
                        print("⚠️ OnboardingTransactionView: Receipt analysis failed")
                    }
                }
            }
        }
    }
    
    // MARK: - Completion
    
    private func completeOnboarding() {
        print("🎉 OnboardingTransactionView: Completing onboarding with slide animation...")
        
        // Set completion flags
        UserDefaults.standard.set(true, forKey: "hasReachedTransactionStep")
        UserDefaults.standard.set(true, forKey: "hasCompletedTransactionOnboarding")
        
        // Start slide-out animation (matching standard 98% sheet dismissal speed)
        withAnimation(.easeInOut(duration: 0.35)) {
            isDismissing = true
        }
        
        // Call completion handler after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { // Slightly longer than animation
            onComplete()
            
            // Show welcome toast only once when completing onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Allow sheet to fully dismiss first
                if !hasShownWelcomeToast, let firstName = AuthenticationManager.shared.currentUser?.name.components(separatedBy: " ").first {
                    hasShownWelcomeToast = true
                    print("🎉 OnboardingTransactionView: Showing welcome toast for: \(firstName)")
                    toastManager.showWelcome(firstName)
                } else {
                    print("🚫 OnboardingTransactionView: Welcome toast already shown or no user name")
                }
            }
            
            print("✅ OnboardingTransactionView: Onboarding completed successfully")
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingTransactionView(
        isPresented: .constant(true),
        onComplete: {},
        onBack: {}
    )
    .environmentObject(ToastManager())
}