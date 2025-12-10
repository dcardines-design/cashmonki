//
//  LottieIntegrationExample.swift
//  How to integrate Lottie animations into existing CashMonki workflows
//

import SwiftUI

// MARK: - Example: Enhanced Receipt Confirmation Sheet

struct EnhancedReceiptConfirmationSheet: View {
    @Binding var isPresented: Bool
    let receiptImage: UIImage?
    let analysis: ReceiptAnalysis?
    let onConfirm: (Txn) -> Void
    
    @State private var showSuccessAnimation = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(title: "Confirm Receipt") {
                isPresented = false
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Show success animation when processing completes
                    if showSuccessAnimation {
                        LottieAnimations.receiptSuccess()
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    isPresented = false
                                }
                            }
                    } else {
                        // Regular receipt confirmation content
                        receiptConfirmationContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Actions
            if !showSuccessAnimation {
                FixedBottomGroup.primary(
                    title: isProcessing ? "Processing..." : "Save Transaction",
                    action: handleConfirm
                )
            }
        }
        .background(AppColors.backgroundWhite)
    }
    
    private var receiptConfirmationContent: some View {
        VStack(spacing: 20) {
            // Receipt image
            if let receiptImage = receiptImage {
                Image(uiImage: receiptImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
            
            // Analysis results
            if let analysis = analysis {
                VStack(spacing: 16) {
                    Text("Merchant: \\(analysis.merchant)")
                    Text("Amount: \\(analysis.amount)")
                    Text("Date: \\(analysis.date)")
                    // ... other fields
                }
            }
        }
    }
    
    private func handleConfirm() {
        isProcessing = true
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showSuccessAnimation = true
                isProcessing = false
            }
            
            // Create and save transaction
            if let analysis = analysis {
                let transaction = createTransactionFromAnalysis(analysis)
                onConfirm(transaction)
            }
        }
    }
    
    private func createTransactionFromAnalysis(_ analysis: ReceiptAnalysis) -> Txn {
        // Implementation to create Txn from analysis
        // This would be your existing logic
        return Txn(/* ... */)
    }
}

// MARK: - Example: Enhanced HomePage with Loading States

extension HomePage {
    
    /// Enhanced receipt analysis with Lottie animations
    func enhancedAnalyzeReceiptImage(_ image: UIImage, source: AnalyzingSource = .scan) {
        isAnalyzingReceipt = true
        analyzingSource = source
        receiptAnalysisError = nil
        
        // Show loading animation during analysis
        let creationTime = Date()
        AIReceiptAnalyzer.shared.analyzeReceipt(image: image, creationTime: creationTime) { result in
            DispatchQueue.main.async {
                isAnalyzingReceipt = false
                analyzingSource = nil
                originalTileClicked = nil
                
                switch result {
                case .success(let analysis):
                    // Show brief success animation before showing confirmation
                    withAnimation {
                        pendingReceiptImage = image
                        pendingReceiptAnalysis = analysis
                        showingReceiptConfirmation = true
                    }
                    
                case .failure(let error):
                    print("❌ Receipt analysis failed: \\(error.localizedDescription)")
                    receiptAnalysisError = "Analysis failed. Please try again."
                }
            }
        }
    }
    
    /// Enhanced loading overlay with Lottie
    var enhancedLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                LottieAnimations.receiptAnalyzing()
                
                Text("Analyzing your receipt...")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.backgroundWhite)
                    .shadow(radius: 10)
            )
        }
    }
}

// MARK: - Example: Empty State with Animation

struct EmptyTransactionsView: View {
    let onAddTransaction: () -> Void
    let onScanReceipt: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            LottieAnimations.emptyTransactions()
            
            VStack(spacing: 16) {
                CashMonkiDS.Button.primary("Add Transaction") {
                    onAddTransaction()
                }
                
                CashMonkiDS.Button.secondary("Scan Receipt") {
                    onScanReceipt()
                }
            }
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    EmptyTransactionsView(
        onAddTransaction: {},
        onScanReceipt: {}
    )
}