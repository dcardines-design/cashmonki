//
//  OnboardingTransactionSheet.swift
//  CashMonki
//
//  Created by Claude on 1/26/25.
//

import SwiftUI
import PhotosUI

struct OnboardingTransactionSheet: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onBack: (() -> Void)? // Optional callback for going back to goals step
    
    // Photo handling state (same as HomePage)
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
    @State private var isTransactionSaving = false
    @State private var isCompletingOnboarding = false
    
    @ObservedObject private var userManager = UserManager.shared
    @EnvironmentObject private var toastManager: ToastManager
    
    private var canContinue: Bool {
        hasCompletedAction || hasSkipped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Coffee cup illustration
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
                    .padding(.top, 20)
                    
                    // Action tiles
                    VStack(spacing: 16) {
                        ActionTile(
                            icon: "upload-01",
                            title: "Upload",
                            subtitle: "Upload a receipt and we'll get the details"
                        ) {
                            handleUploadAction()
                        }
                        
                        ActionTile(
                            icon: "scan",
                            title: "Scan", 
                            subtitle: "Capture a receipt and we'll get the details"
                        ) {
                            handleScanAction()
                        }
                        
                        ActionTile(
                            icon: "plus",
                            title: "Add",
                            subtitle: "Add transaction details manually"
                        ) {
                            handleAddAction()
                        }
                    }
                    
                    // Skip button using tertiary AppButton with smallest size
                    AppButton.tertiary("Skip for now", size: .extraSmall) {
                        handleSkipAction()
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 120) // Space for fixed bottom button
            }
            
            // Progress Bar - Step 4 of 4 (Transaction Addition - Final Step)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: "F3F5F8") ?? Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color(hex: "542EFF") ?? Color.blue)
                        .frame(width: geometry.size.width * (4.0/4.0), height: 4) // Step 4 of 4 (complete)
                }
            }
            .frame(height: 4)
            
            // Continue button (only enabled after action or skip)
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    completeOnboarding()
                },
                isEnabled: canContinue
            )
        }
        .background(AppColors.backgroundWhite)
        .opacity(isCompletingOnboarding ? 0.0 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isCompletingOnboarding)
        .photosPicker(isPresented: $isDirectPhotoPickerPresented, selection: $selectedDirectPhoto, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedDirectPhoto) { _, newItem in
            if let newItem = newItem {
                handlePhotoSelection(newItem)
                hasCompletedAction = true
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraView(
                isPresented: $isCameraPresented,
                onPhotoTaken: { image in
                    capturedImage = image
                    handleCameraCapture(image)
                    hasCompletedAction = true
                },
                onCancel: {
                    isCameraPresented = false
                }
            )
        }
        .sheet(isPresented: $isAddPresented) {
            AddTransactionSheet(
                isPresented: $isAddPresented,
                primaryCurrency: CurrencyPreferences.shared.primaryCurrency,
                onSave: { transaction in
                    // Start fade transition
                    isTransactionSaving = true
                    
                    // Add transaction
                    userManager.addTransaction(transaction)
                    hasCompletedAction = true
                    
                    // Smooth dismissal with fade
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // Fade effect handled by sheet opacity
                    }
                    
                    // Dismiss after fade completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isAddPresented = false
                        isTransactionSaving = false
                    }
                }
            )
            .presentationDetents([.fraction(0.98)])
            .opacity(isTransactionSaving ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isTransactionSaving)
        }
    }
    
    // MARK: - Action Handlers (same logic as HomePage)
    
    private func handleUploadAction() {
        currentPhotoSource = .upload
        isDirectPhotoPickerPresented = true
    }
    
    private func handleScanAction() {
        currentPhotoSource = .camera
        isCameraPresented = true
    }
    
    private func handleAddAction() {
        isAddPresented = true
    }
    
    private func handleSkipAction() {
        // Set skip flag for gate validation
        UserDefaults.standard.set(true, forKey: "hasSkippedTransactionOnboarding")
        hasSkipped = true
        print("🎯 OnboardingTransaction: User skipped transaction creation")
        
        // Complete onboarding immediately
        completeOnboarding()
    }
    
    // MARK: - Photo Processing (same as HomePage)
    
    private func handlePhotoSelection(_ item: PhotosPickerItem) {
        print("📷 OnboardingTransaction: Photo selected from library")
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data?):
                    if let uiImage = UIImage(data: data) {
                        processReceiptImage(uiImage, source: .upload)
                    }
                case .success(nil):
                    print("❌ OnboardingTransaction: No data from photo")
                case .failure(let error):
                    print("❌ OnboardingTransaction: Error loading photo: \(error)")
                }
                selectedDirectPhoto = nil
            }
        }
    }
    
    private func handleCameraCapture(_ image: UIImage) {
        print("📷 OnboardingTransaction: Photo captured from camera")
        processReceiptImage(image, source: .camera)
    }
    
    private func processReceiptImage(_ image: UIImage, source: PhotoSource) {
        print("🔍 OnboardingTransaction: Processing receipt image from \(source)")
        
        isAnalyzingReceipt = true
        
        // Show scanning toast
        toastManager.startReceiptAnalysis()
        
        // Process with AIReceiptAnalyzer (same as HomePage)
        AIReceiptAnalyzer.shared.analyzeReceipt(image: image) { result in
            DispatchQueue.main.async {
                isAnalyzingReceipt = false
                
                switch result {
                case .success(let analysisResult):
                    print("✅ OnboardingTransaction: Receipt analysis successful - \(analysisResult)")
                    toastManager.completeReceiptAnalysis {
                        // Show receipt confirmation sheet
                        // Note: We'd need to add ReceiptConfirmationSheet here
                        // For now, just complete the action
                        print("🎉 OnboardingTransaction: Receipt processed successfully")
                    }
                    
                case .failure(let error):
                    print("❌ OnboardingTransaction: Receipt analysis failed: \(error)")
                    toastManager.failReceiptAnalysis {
                        print("⚠️ OnboardingTransaction: Receipt analysis failed")
                    }
                }
            }
        }
    }
    
    // MARK: - Completion
    
    private func completeOnboarding() {
        print("🎉 OnboardingTransaction: Completing onboarding...")
        
        // Set special flag to prevent re-onboarding
        UserDefaults.standard.set(true, forKey: "hasReachedTransactionStep")
        
        // Mark onboarding as complete
        OnboardingStateManager.shared.markAsComplete()
        
        // Start fade-out animation
        isCompletingOnboarding = true
        
        // Fade out over 0.3 seconds, then dismiss
        withAnimation(.easeInOut(duration: 0.3)) {
            // Fade effect handled by opacity modifier
        }
        
        // Dismiss after fade completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
            onComplete()
            print("✅ OnboardingTransaction: Onboarding completed successfully")
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
}

// MARK: - Supporting Types
// Note: PhotoSource enum is defined in CustomPhotoPicker.swift

// MARK: - Preview

#Preview {
    OnboardingTransactionSheet(
        isPresented: .constant(true),
        onComplete: {},
        onBack: {}
    )
    .environmentObject(ToastManager())
}