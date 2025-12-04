//
//  ToastView.swift
//  CashMonki
//
//  Toast notifications with Lottie animations
//

import SwiftUI
import Lottie

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool
    let showFailedOverlay: Bool
    @State private var animationOpacity: Double = 1.0
    
    private var subtitleText: String {
        switch type {
        case .scanning:
            return "Maybe judging your coffee habit 👀"
        case .done:
            return "All scanned and sorted ✨"
        case .failed:
            return "Try again in good lighting or cropping closer"
        case .error:
            return "Please try again"
        case .success:
            return "" // No subtitle for success toast
        case .deleted:
            return "" // No subtitle for deleted toast
        case .welcome:
            return "" // No subtitle for welcome toast
        case .noConnection:
            return "" // No subtitle for no connection toast
        }
    }
    
    enum ToastType {
        case scanning
        case done
        case failed
        case error
        case success
        case deleted
        case welcome
        case noConnection
        
        var animationName: String {
            switch self {
            case .scanning:
                return "toast-scanning"
            case .done:
                return "toast-done"
            case .failed:
                return "toast-failed"
            case .error:
                return "error-warning" // You can add this later
            case .success:
                return "toast-done" // Use same animation as done state
            case .deleted:
                return "toast-deleted" // Use deleted Lottie animation
            case .welcome:
                return "toast-wave" // Use wave animation for welcome
            case .noConnection:
                return "toast-no-connection" // Use no-connection JSON animation
            }
        }
        
        var animationFileName: String {
            switch self {
            case .scanning:
                return "toast-scanning-gif" // GIF in Assets.xcassets
            case .done:
                return "toast-done" // Keep Lottie for done state
            case .failed:
                return "toast-failed" // Lottie for failed state
            case .error:
                return "error-warning" // You can add this later
            case .success:
                return "toast-done" // Use same Lottie as done state
            case .deleted:
                return "toast-deleted" // Use deleted Lottie animation
            case .welcome:
                return "toast-wave" // Use wave animation for welcome
            case .noConnection:
                return "toast-no-connection" // Use no-connection JSON animation
            }
        }
        
        var loopMode: LottieLoopMode {
            switch self {
            case .welcome:
                return .loop // Welcome toast should loop continuously
            default:
                return .playOnce // All other toasts play once
            }
        }
        
        var backgroundColor: Color {
            // All toasts use black background now
            return Color.black
        }
    }
    
    var body: some View {
        ZStack {
        HStack(alignment: .top, spacing: 0) {
            // Receipt animation area with overlay support
            ZStack {
                // Base animation (scanning GIF or other states)
                Group {
                    if type == .scanning {
                        AnimatedImageView(
                            fileName: type.animationFileName,
                            animationSpeed: 1.0,
                            isPlaying: $isShowing
                        )
                    } else {
                        SmoothLottieView(
                            animationName: type.animationName,
                            loopMode: type.loopMode,
                            easingType: .bounce,
                            animationSpeed: 1.0,
                            isPlaying: $isShowing
                        )
                    }
                }
                
                // Failed animation overlay (only shows when showFailedOverlay is true)
                if showFailedOverlay {
                    SmoothLottieView(
                        animationName: "toast-failed",
                        loopMode: .playOnce,
                        easingType: .bounce,
                        animationSpeed: 1.0,
                        isPlaying: .constant(true)
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: 109, height: 68)
            .opacity(animationOpacity)
            .animation(.easeInOut(duration: 0.2), value: animationOpacity)
            .onChange(of: type.animationFileName) { oldValue, newValue in
                // Immediately fade in new animation on top without delay
                withAnimation(.easeIn(duration: 0.2)) {
                    animationOpacity = 1.0
                }
            }
            
            // Message text
            VStack(alignment: .leading, spacing: 1) {
                Text(message)
                    .font(
                        Font.custom("Overused Grotesk", size: 16)
                            .weight(.semibold)
                    )
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                
                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(
                            Font.custom("Overused Grotesk", size: 14)
                                .weight(.medium)
                        )
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .lineLimit(1)
                }
            }
            .frame(maxHeight: .infinity, alignment: subtitleText.isEmpty ? .center : .top)
            .padding(.leading, 0)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .frame(width: 311, alignment: .topLeading)
            
            Spacer()
        }
        }
        .frame(width: 410, height: 68)
        .background(.black.opacity(1.0))
        .cornerRadius(10)
        .shadow(color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.18), radius: 24, x: 0, y: 24)
        .padding(.horizontal, 15)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom),
            removal: .move(edge: .bottom).combined(with: .offset(y: 100))
        ))
        .onAppear {
            // Auto-dismiss is now handled by ToastManager only
            // Remove conflicting auto-dismiss logic
        }
    }
}

// MARK: - Toast Manager

class ToastManager: ObservableObject {
    @Published var currentToast: ToastData?
    private var isCompletingAnalysis: Bool = false
    
    struct ToastData: Identifiable {
        let id = UUID()
        var message: String
        var type: ToastView.ToastType
        var isShowing: Bool = true
        var showFailedOverlay: Bool = false
    }
    
    func show(_ message: String, type: ToastView.ToastType) {
        print("🍞 DEBUG: ToastManager.show() called with message: '\(message)', type: \(type)")
        print("🍞 DEBUG: 🔧 FIXED: ToastManager object ID: \(ObjectIdentifier(self))")
        withAnimation(.bouncy(duration: 0.3)) {
            currentToast = ToastData(message: message, type: type)
            print("🍞 DEBUG: Toast created successfully")
        }
    }
    
    func showScanning(_ message: String = "Crunching the numbers...") {
        show(message, type: .scanning)
    }
    
    func showDone(_ message: String = "Done analyzing!") {
        show(message, type: .done)
    }
    
    func showFailed(_ message: String = "Couldn't read that one 🤔") {
        show(message, type: .failed)
    }
    
    func showError(_ message: String = "Processing failed. Please try again.") {
        show(message, type: .error)
    }
    
    func showSuccess(_ message: String = "Transaction added!") {
        show(message, type: .success)
        
        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.dismiss()
        }
    }
    
    func showDeleted(_ message: String = "Transaction deleted") {
        // Delay showing the toast by 0.3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var toastData = ToastData(message: message, type: .deleted)
            toastData.isShowing = false // Start with animation paused
            
            withAnimation(.bouncy(duration: 0.3)) {
                self.currentToast = toastData
            }
            
            // Delay animation play by another 0.3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.currentToast?.isShowing = true // Start animation
            }
            
            // Auto-dismiss after 1.5 seconds from animation start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.dismiss()
            }
        }
    }
    
    func showWelcome(_ firstName: String) {
        print("🎉 ToastManager: ======= WELCOME TOAST FUNCTION CALLED =======")
        let message = "Welcome, \(firstName)!"
        print("🎉 ToastManager: Showing welcome toast for: '\(firstName)'")
        print("🎉 ToastManager: Welcome message: '\(message)'")
        print("🎉 ToastManager: About to call show() with .welcome type...")
        show(message, type: .welcome)
        print("🎉 ToastManager: ✅ Called show() successfully!")
        
        // Auto-dismiss after 2.5 seconds (1 second longer than transaction added toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            print("🎉 ToastManager: Auto-dismissing welcome toast after 2.5 seconds")
            self.dismiss()
        }
    }
    
    // MARK: - Receipt Analysis Workflow
    
    /// Start receipt analysis toast
    func startReceiptAnalysis() {
        print("🍞 DEBUG: ToastManager.startReceiptAnalysis() called")
        
        // Force reset any existing toast and immediately show scanning toast
        currentToast = nil
        print("🍞 DEBUG: Reset current toast, now showing scanning toast")
        
        // Start new scanning toast immediately
        showScanning("Crunching the numbers...")
        print("🍞 DEBUG: Current toast after scanning start: \(currentToast?.message ?? "nil")")
    }
    
    /// Transition from scanning to done state
    func completeReceiptAnalysis(onComplete: @escaping () -> Void = {}) {
        print("🍞 DEBUG: completeReceiptAnalysis called, currentToast: \(currentToast?.message ?? "nil")")
        
        // Prevent multiple executions
        guard !isCompletingAnalysis else {
            print("🍞 DEBUG: Already completing analysis, ignoring duplicate call")
            return
        }
        
        isCompletingAnalysis = true
        print("🍞 DEBUG: Starting completion process")
        
        // Update existing toast to done state
        withAnimation(.bouncy(duration: 0.3)) {
            currentToast?.message = "Done analyzing!"
            currentToast?.type = .done
            print("🍞 DEBUG: Updated toast to done state successfully")
        }
        
        // Show done animation for 2 seconds then show confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onComplete() // Call completion handler to show receipt confirmation
            print("🍞 DEBUG: Completion handler called after 2 second done animation")
            
            // Then dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🍞 DEBUG: Dismissing done toast")
                self.dismiss()
                self.isCompletingAnalysis = false // Reset flag after completion
                print("🍞 DEBUG: Reset completion flag")
            }
        }
    }
    
    /// Transition from scanning to failed state
    func failReceiptAnalysis(onFailure: @escaping () -> Void = {}) {
        print("🍞 DEBUG: failReceiptAnalysis called, currentToast: \(currentToast?.message ?? "nil")")
        
        // Prevent multiple executions
        guard !isCompletingAnalysis else {
            print("🍞 DEBUG: Already completing analysis, ignoring duplicate call")
            return
        }
        
        isCompletingAnalysis = true
        print("🍞 DEBUG: Starting failure process")
        
        // Show failed overlay on top of scanning animation
        withAnimation(.bouncy(duration: 0.3)) {
            currentToast?.message = "Couldn't read that one 🤔"
            currentToast?.type = .failed
            currentToast?.showFailedOverlay = true
            print("🍞 DEBUG: Showing failed overlay on top of scanning animation")
        }
        
        // Show failed animation for 2 seconds then call failure handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onFailure() // Call failure handler AFTER failed animation is seen
            print("🍞 DEBUG: Failure handler called after failed animation")
            
            // Then dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🍞 DEBUG: Dismissing failed toast")
                self.dismiss()
                self.isCompletingAnalysis = false // Reset flag after failure
                print("🍞 DEBUG: Reset completion flag")
            }
        }
    }
    
    /// Show no connection toast
    func showNoConnectionToast() {
        print("🍞 DEBUG: showNoConnectionToast called")
        
        withAnimation(.bouncy(duration: 0.3)) {
            currentToast = ToastData(
                message: "Uh oh... No Wi-Fi, no magic.",
                type: .noConnection,
                isShowing: true,
                showFailedOverlay: false
            )
            print("🍞 DEBUG: No connection toast shown")
        }
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.dismiss()
            print("🍞 DEBUG: No connection toast auto-dismissed")
        }
    }
    
    // MARK: - Smart Error Handling
    
    /// Automatically detect network errors and show appropriate toast
    func failReceiptAnalysis(error: Error, onFailure: @escaping () -> Void = {}) {
        print("🍞 DEBUG: failReceiptAnalysis called with error: \(error)")
        
        // Check if this is a network connection error
        let isNetworkError = isNetworkConnectionError(error)
        print("🔍 Network error detected: \(isNetworkError)")
        
        if isNetworkError {
            // Show no connection toast instead of failed toast
            print("📶 Showing no connection toast for network error")
            showNoConnectionToast()
            // Call failure handler immediately for network errors
            onFailure()
        } else {
            // Show regular failed toast for non-network errors
            failReceiptAnalysis(onFailure: onFailure)
        }
    }
    
    /// Network error detection (copied from HomePage for automatic error handling)
    private func isNetworkConnectionError(_ error: Error) -> Bool {
        // Check for URLError network-related issues
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed,
                 .timedOut:
                return true
            default:
                return false
            }
        }
        
        // Check for NSError with network-related domains
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                // Additional URLError cases that might be wrapped
                return nsError.code == NSURLErrorNotConnectedToInternet ||
                       nsError.code == NSURLErrorNetworkConnectionLost ||
                       nsError.code == NSURLErrorCannotConnectToHost ||
                       nsError.code == NSURLErrorCannotFindHost ||
                       nsError.code == NSURLErrorDNSLookupFailed ||
                       nsError.code == NSURLErrorTimedOut
                       
            case "NSPOSIXErrorDomain":
                // POSIX network errors (connection refused, etc.)
                return nsError.code == 61 || // Connection refused
                       nsError.code == 65 || // No route to host  
                       nsError.code == 51    // Network unreachable
                       
            default:
                // Check error description for common network-related terms
                let description = error.localizedDescription.lowercased()
                return description.contains("network") ||
                       description.contains("connection") ||
                       description.contains("internet") ||
                       description.contains("offline") ||
                       description.contains("unreachable") ||
                       description.contains("timeout") ||
                       description.contains("dns")
            }
        }
        
        return false
    }
    
    func dismiss() {
        print("🍞 DEBUG: dismiss() called, currentToast: \(currentToast?.message ?? "nil")")
        withAnimation(.bouncy(duration: 0.3)) {
            currentToast?.showFailedOverlay = false
            currentToast = nil
            print("🍞 DEBUG: Toast dismissed successfully")
        }
    }
}

// MARK: - Toast Overlay Modifier

struct ToastOverlay: ViewModifier {
    @StateObject private var toastManager = ToastManager()
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = toastManager.currentToast {
                    ToastView(
                        message: toast.message,
                        type: toast.type,
                        isShowing: Binding(
                            get: { toast.isShowing },
                            set: { _ in toastManager.dismiss() }
                        ),
                        showFailedOverlay: toast.showFailedOverlay
                    )
                    .padding(.bottom, 65) // 65px above navbar
                    .zIndex(1000)
                }
            }
            .environmentObject(toastManager)
    }
}

extension View {
    func withToast() -> some View {
        modifier(ToastOverlay())
    }
}

// MARK: - Convenience Extensions

extension View {
    func showToast(_ message: String, type: ToastView.ToastType) -> some View {
        self.onAppear {
            // This would need access to ToastManager from environment
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ToastView(
            message: "Scanning receipt...",
            type: .scanning,
            isShowing: .constant(true),
            showFailedOverlay: false
        )
        
        ToastView(
            message: "Receipt processed successfully!",
            type: .done,
            isShowing: .constant(true),
            showFailedOverlay: false
        )
        
        ToastView(
            message: "Processing failed. Please try again.",
            type: .error,
            isShowing: .constant(true),
            showFailedOverlay: false
        )
    }
    .padding()
    .background(AppColors.surfacePrimary)
}