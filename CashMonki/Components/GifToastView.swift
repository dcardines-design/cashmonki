//
//  GifToastView.swift
//  CashMonki
//
//  Toast with GIF animations instead of Lottie
//

import SwiftUI

struct GifToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool
    
    private var subtitleText: String {
        switch type {
        case .scanning:
            return "Maybe judging your coffee habit 👀"
        case .done:
            return "All scanned and sorted ✨"
        case .error:
            return "Try again later maybe!"
        }
    }
    
    enum ToastType {
        case scanning
        case done
        case error
        
        var gifName: String {
            switch self {
            case .scanning:
                return "toast-scanning"
            case .done:
                return "toast-done"
            case .error:
                return "error-animation" // You can add this GIF later
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Receipt icon background with GIF animation
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                GifImageView(
                    gifName: type.gifName,
                    size: CGSize(width: 24, height: 24)
                )
            }
            .padding(.leading, 16)
            .padding(.top, 14)
            
            // Message text
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(
                        Font.custom("Overused Grotesk", size: 16)
                            .weight(.semibold)
                    )
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .lineLimit(1)
                
                Text(subtitleText)
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
        .onAppear {
            // Auto-dismiss for success/error toasts
            if type != .scanning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.1)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - GIF Toast Manager

class GifToastManager: ObservableObject {
    @Published var currentToast: ToastData?
    
    struct ToastData: Identifiable {
        let id = UUID()
        var message: String
        var type: GifToastView.ToastType
        var isShowing: Bool = true
    }
    
    func show(_ message: String, type: GifToastView.ToastType) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)) {
            currentToast = ToastData(message: message, type: type)
        }
    }
    
    func showScanning(_ message: String = "Crunching the numbers...") {
        show(message, type: .scanning)
    }
    
    func showDone(_ message: String = "Done analyzing!") {
        show(message, type: .done)
    }
    
    func showError(_ message: String = "Processing failed. Please try again.") {
        show(message, type: .error)
    }
    
    // MARK: - Receipt Analysis Workflow
    
    /// Start receipt analysis toast
    func startReceiptAnalysis() {
        showScanning("Crunching the numbers...")
    }
    
    /// Transition from scanning to done state
    func completeReceiptAnalysis() {
        guard var toast = currentToast else { return }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)) {
            toast.message = "Done analyzing!"
            toast.type = .done
            currentToast = toast
        }
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.dismiss()
        }
    }
    
    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.1)) {
            currentToast = nil
        }
    }
}

// MARK: - GIF Toast Overlay Modifier

struct GifToastOverlay: ViewModifier {
    @StateObject private var toastManager = GifToastManager()
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = toastManager.currentToast {
                    GifToastView(
                        message: toast.message,
                        type: toast.type,
                        isShowing: Binding(
                            get: { toast.isShowing },
                            set: { _ in toastManager.dismiss() }
                        )
                    )
                    .padding(.bottom, 100) // Above tab bar
                    .zIndex(1000)
                }
            }
            .environmentObject(toastManager)
    }
}

extension View {
    func withGifToast() -> some View {
        modifier(GifToastOverlay())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        GifToastView(
            message: "Crunching the numbers...",
            type: .scanning,
            isShowing: .constant(true)
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}