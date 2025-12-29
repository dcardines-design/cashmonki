//
//  ReceiptAnalysisToastIntegration.swift
//  Example of how to integrate the receipt analysis toast into HomePage
//

import SwiftUI

// MARK: - Example Integration in HomePage

extension HomePage {
    
    /// Enhanced receipt analysis with toast workflow
    func analyzeReceiptWithToast(_ image: UIImage, source: AnalyzingSource = .scan) {
        // Get toast manager from environment
        guard let toastManager = getToastManager() else { return }
        
        // Step 1: Show analyzing toast
        toastManager.startReceiptAnalysis()
        
        // Step 2: Start actual analysis
        isAnalyzingReceipt = true
        analyzingSource = source
        receiptAnalysisError = nil
        
        let creationTime = Date()
        AIReceiptAnalyzer.shared.analyzeReceipt(image: image, creationTime: creationTime) { result in
            DispatchQueue.main.async {
                isAnalyzingReceipt = false
                analyzingSource = nil
                originalTileClicked = nil
                
                switch result {
                case .success(let analysis):
                    // Step 3: Analysis completed successfully - transition toast
                    toastManager.completeReceiptAnalysis()
                    
                    // Step 4: Show receipt confirmation (after brief delay)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        pendingReceiptImage = image
                        pendingReceiptAnalysis = analysis
                        showingReceiptConfirmation = true
                    }
                    
                case .failure(let error):
                    print("❌ Receipt analysis failed: \\(error.localizedDescription)")
                    
                    // Step 3: Analysis failed - dismiss scanning toast and show error
                    toastManager.dismiss()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        toastManager.showError("Analysis failed. Please try again.")
                    }
                }
            }
        }
    }
    
    // Helper method to get toast manager from environment
    private func getToastManager() -> ToastManager? {
        // This would need to be implemented based on how you inject the environment object
        // For now, return nil - you'll need to access it through @EnvironmentObject
        return nil
    }
}

// MARK: - Complete HomePage Integration Example

struct HomePageWithToast: View {
    @StateObject private var toastManager = ToastManager()
    
    var body: some View {
        // Your existing HomePage content
        VStack {
            // Your home page content here
            
            Button("Test Receipt Analysis Toast") {
                testReceiptAnalysisWorkflow()
            }
            .padding()
        }
        .withToast() // Add toast overlay
        .environmentObject(toastManager) // Provide toast manager
    }
    
    private func testReceiptAnalysisWorkflow() {
        // Step 1: Start analysis
        toastManager.startReceiptAnalysis()
        
        // Step 2: Simulate analysis completion after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            toastManager.completeReceiptAnalysis()
        }
    }
}

// MARK: - Usage Instructions

/*
## How to Integrate into Your Existing HomePage:

1. **Add Toast Manager to Your App:**
   ```swift
   struct ContentView: View {
       @StateObject private var toastManager = ToastManager()
       
       var body: some View {
           HomePage()
               .withToast()
               .environmentObject(toastManager)
       }
   }
   ```

2. **Update Your Receipt Analysis Function:**
   ```swift
   extension HomePage {
       func analyzeReceiptImage(_ image: UIImage, source: AnalyzingSource = .scan) {
           @EnvironmentObject var toastManager: ToastManager
           
           // Start toast
           toastManager.startReceiptAnalysis()
           
           // Your existing analysis code...
           let creationTime = Date()
        AIReceiptAnalyzer.shared.analyzeReceipt(image: image, creationTime: creationTime) { result in
               DispatchQueue.main.async {
                   switch result {
                   case .success(let analysis):
                       // Complete toast
                       toastManager.completeReceiptAnalysis()
                       
                       // Your existing success handling...
                       
                   case .failure(let error):
                       // Dismiss scanning toast and show error
                       toastManager.dismiss()
                       toastManager.showError("Analysis failed")
                   }
               }
           }
       }
   }
   ```

3. **Toast States:**
   - `toastManager.startReceiptAnalysis()` - Shows "Analyzing receipt..." with scanning animation
   - `toastManager.completeReceiptAnalysis()` - Transitions to "Done analyzing!" with done animation
   - `toastManager.showError()` - Shows error toast
   - `toastManager.dismiss()` - Manually dismiss toast

## Animation Flow:
1. User scans/uploads receipt
2. Toast appears from bottom with "Analyzing receipt..." + scanning animation
3. Analysis completes successfully
4. Toast transitions to "Done analyzing!" + done animation (auto-dismisses after 2s)
5. Receipt confirmation sheet appears

## Error Flow:
1. User scans/uploads receipt  
2. Toast appears with scanning state
3. Analysis fails
4. Scanning toast dismisses
5. Error toast appears with error message
*/

#Preview {
    HomePageWithToast()
}