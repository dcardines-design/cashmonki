//
//  SlideInSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

// MARK: - Slide-In Sheet Container (DEPRECATED - Use .fullScreenCover() instead)
// This component is now deprecated in favor of SwiftUI's native .fullScreenCover()
// for better performance, native transitions, and proper safe area handling.
struct SlideInSheet<SheetContent: View>: ViewModifier {
    let isPresented: Bool
    let sheetContent: SheetContent
    
    init(isPresented: Bool, @ViewBuilder content: () -> SheetContent) {
        self.isPresented = isPresented
        self.sheetContent = content()
    }
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: .constant(isPresented)) {
                sheetContent
            }
    }
}

// MARK: - View Extension for Easy Usage (DEPRECATED)
extension View {
    /// DEPRECATED: Use .fullScreenCover() directly instead
    /// Presents a sheet using SwiftUI's native full-screen cover
    /// - Parameters:
    ///   - isPresented: Binding to control sheet visibility
    ///   - content: The sheet content to display
    @available(*, deprecated, message: "Use .fullScreenCover() directly for better performance and native behavior")
    func slideInSheet<SheetContent: View>(
        isPresented: Bool,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        self.modifier(SlideInSheet(isPresented: isPresented, content: content))
    }
    
    /// Current implementation - presents a sheet using SwiftUI's native full-screen cover
    /// - Parameters:
    ///   - isPresented: Binding to control sheet visibility
    ///   - content: The sheet content to display
    func slideInSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        self.fullScreenCover(isPresented: isPresented) {
            content()
        }
    }
}

// MARK: - Sheet Presentation Helpers (DEPRECATED)
struct SheetPresentationHelper {
    /// DEPRECATED: SwiftUI's native fullScreenCover handles animations automatically
    static let slideAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    
    /// DEPRECATED: SwiftUI's native fullScreenCover handles transitions automatically
    static let slideTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .bottom),
        removal: .move(edge: .bottom)
    )
    
    /// DEPRECATED: SwiftUI's native fullScreenCover handles z-index automatically
    static let sheetZIndex: Double = 999
}

// MARK: - Usage Examples and Documentation
/*
 
 USAGE EXAMPLES:
 
 1. Basic Sheet Presentation:
 ```swift
 ContentView()
     .slideInSheet(isPresented: showingSheet) {
         MyCustomSheet(isPresented: $showingSheet)
     }
 ```
 
 2. Multiple Sheets:
 ```swift
 ContentView()
     .slideInSheet(isPresented: showingAddSheet) {
         AddTransactionSheet(isPresented: $showingAddSheet)
     }
     .slideInSheet(isPresented: showingEditSheet) {
         EditTransactionSheet(isPresented: $showingEditSheet)
     }
 ```
 
 3. Sheet with Complex Logic:
 ```swift
 ContentView()
     .slideInSheet(isPresented: showingDetail) {
         if let transaction = selectedTransaction {
             TransactionDetailSheet(
                 transaction: transaction,
                 onDismiss: { showingDetail = false }
             )
         }
     }
 ```
 
 SHEET IMPLEMENTATION GUIDELINES:
 
 1. All sheets should include SheetHeader for consistency:
 ```swift
 struct MySheet: View {
     @Binding var isPresented: Bool
     
     var body: some View {
         VStack(spacing: 0) {
             SheetHeader.basic(title: "My Sheet") {
                 isPresented = false
             }
             
             // Sheet content...
         }
     }
 }
 ```
 
 2. Use FixedBottomGroup for action buttons:
 ```swift
 VStack(spacing: 0) {
     // Header and content...
     
     FixedBottomGroup.primary(
         title: "Save",
         action: { /* save logic */ }
     )
 }
 ```
 
 */