//
//  ReceiptAnalyzingToast.swift
//  CashMonki
//
//  Specialized toast for receipt analysis with state transitions
//

import SwiftUI
import Lottie

struct ReceiptAnalyzingToast: View {
    @Binding var isShowing: Bool
    @State private var analysisState: AnalysisState = .analyzing
    
    enum AnalysisState {
        case analyzing
        case done
        
        var animationName: String {
            switch self {
            case .analyzing:
                return "toast-scanning"
            case .done:
                return "toast-done"
            }
        }
        
        var title: String {
            switch self {
            case .analyzing:
                return "Crunching the numbers..."
            case .done:
                return "Done analyzing!"
            }
        }
        
        var subtitle: String {
            switch self {
            case .analyzing:
                return "Maybe judging your coffee habit 👀"
            case .done:
                return "All scanned and sorted ✨"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Receipt icon background with Lottie animation
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                LottieView(
                    animationName: analysisState.animationName,
                    loopMode: analysisState == .analyzing ? .loop : .playOnce
                )
                .frame(width: 24, height: 24)
            }
            .padding(.leading, 16)
            .padding(.top, 14)
            
            // Message text
            VStack(alignment: .leading, spacing: 4) {
                Text(analysisState.title)
                    .font(
                        Font.custom("Overused Grotesk", size: 16)
                            .weight(.semibold)
                    )
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .lineLimit(1)
                
                Text(analysisState.subtitle)
                    .font(
                        Font.custom("Overused Grotesk", size: 14)
                            .weight(.medium)
                    )
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .lineLimit(1)
            }
            .padding(.leading, 12)
            .padding(.top, 14)
            .padding(.trailing, 16)
            
            Spacer()
        }
        .padding(0)
        .frame(height: 68, alignment: .top)
        .background(Color.black)
        .cornerRadius(10)
        .shadow(
            color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.18), 
            radius: 24, 
            x: 0, 
            y: 24
        )
        .padding(.horizontal, 20)
        .transition(.move(edge: .top))
    }
    
    // MARK: - Public Methods
    
    /// Call this when receipt analysis completes successfully
    func markAnalysisComplete() {
        withAnimation(.easeInOut(duration: 0.3)) {
            analysisState = .done
        }
        
        // Auto-dismiss after showing success state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowing = false
            }
        }
    }
}

// MARK: - Receipt Analysis Toast Manager

class ReceiptAnalysisToastManager: ObservableObject {
    @Published var isShowingAnalysisToast = false
    
    private var currentToastView: ReceiptAnalyzingToast?
    
    /// Show the analyzing toast
    func startAnalysis() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingAnalysisToast = true
        }
    }
    
    /// Mark analysis as complete and transition to done state
    func completeAnalysis() {
        // This will be called from the parent view that has access to the toast
        // We'll handle the state transition in the integration
    }
    
    /// Dismiss the toast (for errors or manual dismissal)
    func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingAnalysisToast = false
        }
    }
}

// MARK: - Toast Overlay Modifier for Receipt Analysis

struct ReceiptAnalysisToastOverlay: ViewModifier {
    @StateObject private var toastManager = ReceiptAnalysisToastManager()
    @State private var toastRef: ReceiptAnalyzingToast?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if toastManager.isShowingAnalysisToast {
                    ReceiptAnalyzingToast(isShowing: $toastManager.isShowingAnalysisToast)
                        .onAppear {
                            // Store reference to control state transitions
                        }
                        .padding(.bottom, 100) // Above tab bar
                        .zIndex(1000)
                }
            }
            .environmentObject(toastManager)
    }
}

extension View {
    func withReceiptAnalysisToast() -> some View {
        modifier(ReceiptAnalysisToastOverlay())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ReceiptAnalyzingToast(isShowing: .constant(true))
        
        Spacer()
    }
    .background(AppColors.surfacePrimary)
}