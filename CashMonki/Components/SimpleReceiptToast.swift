//
//  SimpleReceiptToast.swift
//  CashMonki
//
//  Simplified receipt toast without Lottie (fallback version)
//

import SwiftUI

struct SimpleReceiptToast: View {
    @Binding var isShowing: Bool
    @State private var analysisState: AnalysisState = .analyzing
    
    enum AnalysisState {
        case analyzing
        case done
        
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
        
        var iconSystemName: String {
            switch self {
            case .analyzing:
                return "doc.text.magnifyingglass"
            case .done:
                return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Receipt icon background with SF Symbol
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: analysisState.iconSystemName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(analysisState == .analyzing ? 360 : 0))
                    .animation(
                        analysisState == .analyzing 
                            ? .linear(duration: 2.0).repeatForever(autoreverses: false)
                            : .easeInOut(duration: 0.3),
                        value: analysisState
                    )
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

// MARK: - Preview

#Preview {
    VStack {
        SimpleReceiptToast(isShowing: .constant(true))
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}