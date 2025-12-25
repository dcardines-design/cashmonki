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
    @State private var randomBlurb: String = SimpleReceiptToast.analyzingBlurbs.randomElement() ?? "Oh, this is gonna be good..."

    // 20 random blurbs shown during receipt analysis (Deadpool energy)
    private static let analyzingBlurbs = [
        "Oh, this is gonna be good...",
        "Your wallet called. It's crying.",
        "No judgment. Okay, some judgment.",
        "What do we have here... 👀",
        "Bold purchases. Questionable timing.",
        "Your bank account just flinched.",
        "Interesting strategy there...",
        "Seen worse. Not by much though.",
        "Ah yes, the classic 'treat yourself' purchase.",
        "Someone likes to live dangerously.",
        "Your future self is typing a strongly worded letter.",
        "Doing some light financial stalking...",
        "This is going to be interesting...",
        "Calculating the damage...",
        "Your money had a good run.",
        "Reading between the line items...",
        "Someone's been busy...",
        "So many questions here...",
        "Brb, alerting your accountant.",
        "Well well well..."
    ]

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

        var iconSystemName: String {
            switch self {
            case .analyzing:
                return "doc.text.magnifyingglass"
            case .done:
                return "checkmark.circle.fill"
            }
        }
    }

    var subtitle: String {
        switch analysisState {
        case .analyzing:
            return randomBlurb
        case .done:
            return "All scanned and sorted ✨"
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
                
                Text(subtitle)
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

// MARK: - Preview

#Preview {
    VStack {
        SimpleReceiptToast(isShowing: .constant(true))
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}