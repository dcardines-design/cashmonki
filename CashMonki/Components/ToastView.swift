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
    let scanningBlurb: String  // Random blurb passed in for scanning toasts
    @State private var animationOpacity: Double = 1.0

    // 20 random blurbs shown during receipt analysis (Deadpool energy)
    static let analyzingBlurbs = [
        "Oh, this is gonna be good... 👀",
        "Your wallet called. It's crying. 👀",
        "No judgment. Okay, some judgment. 👀",
        "What do we have here... 👀",
        "Bold purchases. Questionable timing. 👀",
        "Your bank account just flinched. 👀",
        "Interesting strategy there... 👀",
        "Seen worse. Not by much though. 👀",
        "Ah yes, the classic 'treat yourself' purchase. 👀",
        "Someone likes to live dangerously. 👀",
        "Your future self is typing a strongly worded letter. 👀",
        "Doing some light financial stalking... 👀",
        "This is going to be interesting... 👀",
        "Calculating the damage... 👀",
        "Your money had a good run. 👀",
        "Reading between the line items... 👀",
        "Someone's been busy... 👀",
        "So many questions here... 👀",
        "Brb, alerting your accountant. 👀",
        "Well well well... 👀"
    ]

    // Convenience initializer without scanningBlurb (for non-scanning toasts)
    init(message: String, type: ToastType, isShowing: Binding<Bool>, showFailedOverlay: Bool) {
        self.message = message
        self.type = type
        self._isShowing = isShowing
        self.showFailedOverlay = showFailedOverlay
        self.scanningBlurb = ToastView.analyzingBlurbs.randomElement() ?? "Oh, this is gonna be good..."
    }

    // Full initializer with explicit scanningBlurb
    init(message: String, type: ToastType, isShowing: Binding<Bool>, showFailedOverlay: Bool, scanningBlurb: String) {
        self.message = message
        self.type = type
        self._isShowing = isShowing
        self.showFailedOverlay = showFailedOverlay
        self.scanningBlurb = scanningBlurb
    }

    private var subtitleText: String {
        switch type {
        case .scanning:
            return scanningBlurb
        case .done:
            return "All scanned and sorted ✨"
        case .failed:
            return "Try again in good lighting or cropping closer"
        case .error:
            return "Try again later maybe!"
        case .success:
            return "" // No subtitle for regular success toasts
        case .subscriptionSuccess:
            return "Your future self says thanks 😉"
        case .subscriptionError:
            return "No worries, try again in a bit 💫"
        case .deleted:
            return "" // No subtitle for deleted toast
        case .welcome:
            return "" // No subtitle for welcome toast
        case .trialEnded:
            return "" // No subtitle for trial ended toast
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
        case subscriptionSuccess
        case subscriptionError
        case deleted
        case welcome
        case trialEnded
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
            case .subscriptionSuccess:
                return "toast-done" // Use same animation as success state
            case .subscriptionError:
                return "toast-failed" // Use failed animation for error state
            case .deleted:
                return "toast-deleted" // Use deleted Lottie animation
            case .welcome:
                return "toast-wave" // Use wave animation for welcome
            case .trialEnded:
                return "toast-wave" // Use wave animation for trial ended
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
            case .subscriptionSuccess:
                return "toast-done" // Use same Lottie as success state
            case .subscriptionError:
                return "toast-failed" // Use failed Lottie for error state
            case .deleted:
                return "toast-deleted" // Use deleted Lottie animation
            case .welcome:
                return "toast-wave" // Use wave animation for welcome
            case .trialEnded:
                return "toast-wave" // Use wave animation for trial ended
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
        
        var description: String {
            switch self {
            case .scanning:
                return "scanning"
            case .done:
                return "done"
            case .failed:
                return "failed"
            case .error:
                return "error"
            case .success:
                return "success"
            case .subscriptionSuccess:
                return "subscriptionSuccess"
            case .subscriptionError:
                return "subscriptionError"
            case .deleted:
                return "deleted"
            case .welcome:
                return "welcome"
            case .trialEnded:
                return "trialEnded"
            case .noConnection:
                return "noConnection"
            }
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            Spacer()
        }
        }
        .frame(maxWidth: .infinity, maxHeight: 68)
        .background(.black.opacity(1.0))
        .cornerRadius(10)
        .shadow(color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.18), radius: 24, x: 0, y: 24)
        .padding(.horizontal, 15)
        .transition(.move(edge: .top))
        .onAppear {
            // Auto-dismiss is now handled by ToastManager only
            // Remove conflicting auto-dismiss logic
        }
    }
}

// MARK: - Toast Manager

class ToastManager: ObservableObject {
    @Published var currentToast: ToastData? {
        didSet {
            // Only manage window when transitioning between nil and non-nil states
            // This allows seamless content updates without recreating the window
            let wasNil = oldValue == nil
            let isNil = currentToast == nil

            if wasNil && !isNil {
                // nil → non-nil: Create window for new toast
                WindowToastController.shared.showToast(toastManager: self)
            } else if !wasNil && isNil {
                // non-nil → nil: Hide window after slide-out animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if self.currentToast == nil {
                        WindowToastController.shared.hideToast()
                    }
                }
            }
            // non-nil → non-nil: Do nothing - view updates via @Published/onReceive
        }
    }
    private var isCompletingAnalysis: Bool = false
    
    struct ToastData: Identifiable {
        let id = UUID()
        var message: String
        var type: ToastView.ToastType
        var isShowing: Bool = true
        var showFailedOverlay: Bool = false
        var scanningBlurb: String = ToastView.analyzingBlurbs.randomElement() ?? "Oh, this is gonna be good..."
    }
    
    func show(_ message: String, type: ToastView.ToastType) {
        print("🍞 === SHOW() CORE DEBUG START ===")
        print("🍞 DEBUG: ToastManager.show() called with message: '\(message)', type: \(type)")
        print("🍞 DEBUG: ToastManager object ID: \(ObjectIdentifier(self))")
        print("🍞 DEBUG: Current thread: \(Thread.current)")
        print("🍞 DEBUG: Is main thread: \(Thread.isMainThread)")
        print("🍞 DEBUG: Existing currentToast before clear: \(currentToast?.message ?? "nil")")
        
        // Clear any existing toast first
        currentToast = nil
        print("🍞 DEBUG: Cleared existing toast")
        
        print("🍞 DEBUG: About to create new ToastData...")
        let newToast = ToastData(message: message, type: type)
        print("🍞 DEBUG: Created ToastData - message: '\(newToast.message)', type: \(newToast.type.description)")
        print("🍞 DEBUG: ToastData isShowing: \(newToast.isShowing)")
        
        print("🍞 DEBUG: About to set currentToast with animation...")
        withAnimation(.bouncy(duration: 0.3)) {
            currentToast = newToast
            print("🍞 DEBUG: Set currentToast inside animation block")
        }
        
        print("🍞 DEBUG: Animation block completed")
        print("🍞 DEBUG: Final currentToast: \(currentToast?.message ?? "nil")")
        print("🍞 DEBUG: Final currentToast type: \(currentToast?.type.description ?? "nil")")
        print("🍞 DEBUG: Final currentToast isShowing: \(currentToast?.isShowing ?? false)")
        print("🍞 === SHOW() CORE DEBUG END ===")
    }
    
    func showScanning(_ message: String = "Crunching the numbers...") {
        show(message, type: .scanning)
        if let blurb = currentToast?.scanningBlurb {
            print("🎲 Random blurb selected: \"\(blurb)\"")
        }
    }
    
    func showDone(_ message: String = "Done analyzing!") {
        show(message, type: .done)
    }
    
    func showFailed(_ message: String = "Couldn't read that one 🤔") {
        print("🍞 === SHOWFAILED DEBUG START ===")
        print("🍞 showFailed() called with message: '\(message)'")
        print("🍞 ToastManager object ID: \(ObjectIdentifier(self))")
        print("🍞 Current toast before showFailed: \(currentToast?.message ?? "nil")")
        print("🍞 Current toast type before: \(currentToast?.type.description ?? "nil")")
        print("🍞 About to call show() with .failed type...")
        
        show(message, type: .failed)
        
        print("🍞 show() call completed")
        print("🍞 Current toast after show(): \(currentToast?.message ?? "nil")")
        print("🍞 Current toast type after: \(currentToast?.type.description ?? "nil")")
        print("🍞 Current toast isShowing: \(currentToast?.isShowing ?? false)")
        print("🍞 === SHOWFAILED DEBUG END ===")
        
        // Auto-dismiss failed toast after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🚨 ToastManager: Auto-dismissing failed toast after 3 seconds")
            self.dismiss()
        }
    }
    
    func showError(_ message: String = "Processing failed. Please try again.") {
        show(message, type: .error)
        
        // Auto-dismiss error toast after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("❌ ToastManager: Auto-dismissing error toast after 3 seconds")
            self.dismiss()
        }
    }
    
    func showSuccess(_ message: String = "Transaction added!") {
        show(message, type: .success)

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.dismiss()
        }
    }

    func showChangesSaved(_ message: String = "Changes saved!") {
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

    /// Show welcome toast without a name (uses wave animation)
    func showWelcome() {
        print("🎉 ToastManager: ======= WELCOME TOAST (NO NAME) CALLED =======")
        let message = "Welcome to Cashmonki!"
        print("🎉 ToastManager: Welcome message: '\(message)'")
        show(message, type: .welcome)
        print("🎉 ToastManager: ✅ Called show() successfully!")

        // Auto-dismiss after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            print("🎉 ToastManager: Auto-dismissing welcome toast after 2.5 seconds")
            self.dismiss()
        }
    }

    /// Show subscription expired toast (uses wave animation)
    func showSubscriptionExpired() {
        print("⏰ ToastManager: ======= SUBSCRIPTION EXPIRED TOAST CALLED =======")
        let message = "Sad to see you go!"
        print("⏰ ToastManager: Subscription expired message: '\(message)'")
        show(message, type: .trialEnded)
        print("⏰ ToastManager: ✅ Called show() successfully!")

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("⏰ ToastManager: Auto-dismissing subscription expired toast after 1.5 seconds")
            self.dismiss()
        }
    }

    /// Legacy alias for showSubscriptionExpired
    func showTrialEnded() {
        showSubscriptionExpired()
    }

    func showSubscriptionSuccess() {
        print("🎯 ToastManager: ======= SUBSCRIPTION SUCCESS TOAST =======")
        show("Welcome to Cashmonki Pro!", type: .subscriptionSuccess)
        
        // Auto-dismiss after 4 seconds (longer to allow reading)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            print("🎯 ToastManager: Auto-dismissing subscription success toast")
            self.dismiss()
        }
    }
    
    func showSubscriptionError(message: String = "Subscription failed") {
        print("🎯 ToastManager: ======= SUBSCRIPTION ERROR TOAST =======")
        print("🎯 ToastManager: Error message: \(message)")
        show(message, type: .subscriptionError)
        
        // Auto-dismiss after 4 seconds (same as success for consistency)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            print("🎯 ToastManager: Auto-dismissing subscription error toast")
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
    
    /// Show no connection toast - modifies existing toast in place for seamless transition
    func showNoConnectionToast() {
        print("🍞 DEBUG: showNoConnectionToast called")

        withAnimation(.bouncy(duration: 0.3)) {
            if currentToast != nil {
                // Modify existing toast in place for seamless transition from scanning
                currentToast?.message = "Uh oh... No Wi-Fi, no magic."
                currentToast?.type = .noConnection
                currentToast?.showFailedOverlay = false
            } else {
                // Create new toast if none exists
                currentToast = ToastData(
                    message: "Uh oh... No Wi-Fi, no magic.",
                    type: .noConnection,
                    isShowing: true,
                    showFailedOverlay: false
                )
            }
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

// MARK: - Navigation Constants

struct NavigationConstants {
    static let navbarTopPadding: CGFloat = 8
    static let navbarBottomPadding: CGFloat = 30
    static let toastSpacingFromNavbar: CGFloat = 0

    /// Simplified calculation: actual navbar content height is much smaller
    /// The navbar is really just: content (~40px) + top padding (8px) + bottom padding (30px) = ~78px
    static var totalNavbarHeight: CGFloat {
        return 48 + navbarTopPadding + navbarBottomPadding
        // 48 + 8 + 30 = 86px (more accurate)
    }

    /// Distance from bottom of screen to position toast 15px above navbar
    static var toastBottomPadding: CGFloat {
        // Simplified: navbar height is roughly 80px + 15px spacing = 95px
        return 80
    }
}

// MARK: - Window-Level Toast (Appears Above All Sheets)

/// A UIWindow-based toast system that appears above all presentations including fullScreenCover
class WindowToastController {
    static let shared = WindowToastController()

    private var toastWindow: UIWindow?
    private var hostingController: UIHostingController<AnyView>?

    private init() {}

    /// Show toast in a window above all other content
    func showToast(toastManager: ToastManager) {
        // Remove existing window if any
        hideToast()

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("🍞 WindowToast: No window scene available")
            return
        }

        // Create a new window at alert level (above sheets)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1  // Above alerts and sheets
        window.backgroundColor = .clear

        // Create the toast view wrapped in a view that ignores safe area
        let toastView = WindowToastView(toastManager: toastManager)
            .ignoresSafeArea(.all)
        let hostingController = UIHostingController(rootView: AnyView(toastView))
        hostingController.view.backgroundColor = .clear

        // Disable safe area on the hosting controller
        hostingController._disableSafeArea = true

        window.rootViewController = hostingController
        window.isHidden = false
        window.isUserInteractionEnabled = false  // Allow touches to pass through

        self.toastWindow = window
        self.hostingController = hostingController

        print("🍞 WindowToast: Toast window created and shown")
    }

    /// Hide the toast window
    func hideToast() {
        toastWindow?.isHidden = true
        toastWindow = nil
        hostingController = nil
    }
}

/// SwiftUI view for window-level toast
struct WindowToastView: View {
    @ObservedObject var toastManager: ToastManager

    // Local state to control animation independently from toast data
    @State private var isVisible: Bool = false
    @State private var localToast: ToastManager.ToastData?

    // Get safe area top from the key window
    private var safeAreaTop: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 59 // Default for Dynamic Island devices
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            if isVisible, let toast = localToast {
                ToastView(
                    message: toast.message,
                    type: toast.type,
                    isShowing: Binding(
                        get: { toast.isShowing },
                        set: { _ in toastManager.dismiss() }
                    ),
                    showFailedOverlay: toast.showFailedOverlay,
                    scanningBlurb: toast.scanningBlurb
                )
                .allowsHitTesting(true)
                .padding(.top, safeAreaTop + 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top),
                    removal: .move(edge: .top)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.bouncy(duration: 0.3), value: isVisible)
        .onAppear {
            // Copy toast data and animate in after a tiny delay
            if let toast = toastManager.currentToast {
                localToast = toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    isVisible = true
                }
            }
        }
        .onReceive(toastManager.$currentToast) { newToast in
            if newToast == nil && isVisible {
                // Animate out - keep localToast for the animation duration
                // Animation is handled by .animation() modifier
                isVisible = false
            } else if let toast = newToast {
                // Update local toast data (for message/type changes during animation)
                localToast = toast
                if !isVisible {
                    // Animate in if not already visible
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        isVisible = true
                    }
                }
            }
        }
    }
}

// MARK: - Toast Overlay Modifier

struct ToastOverlay: ViewModifier {
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        let _ = print("🍞 DEBUG OVERLAY: body called, currentToast = \(toastManager.currentToast?.message ?? "nil")")

        ZStack {
            content

            if let toast = toastManager.currentToast {
                let _ = print("🍞 DEBUG OVERLAY: Rendering toast with message: \(toast.message)")

                VStack {
                    ToastView(
                        message: toast.message,
                        type: toast.type,
                        isShowing: Binding(
                            get: { toast.isShowing },
                            set: { _ in toastManager.dismiss() }
                        ),
                        showFailedOverlay: toast.showFailedOverlay,
                        scanningBlurb: toast.scanningBlurb
                    )
                    .onAppear {
                        print("🍞 UI: ToastView appeared on screen!")
                    }
                    .onDisappear {
                        print("🍞 UI: ToastView disappeared from screen!")
                    }

                    Spacer()
                }
                .padding(.top, 15)
                .transition(.move(edge: .top))
                .zIndex(1000)
            } else {
                let _ = print("🍞 DEBUG OVERLAY: No toast to render (currentToast is nil)")
            }
        }
        .animation(.bouncy(duration: 0.3), value: toastManager.currentToast?.id)
        .onReceive(toastManager.$currentToast) { newToast in
            if let toast = newToast {
                print("🍞 UI: ToastOverlay received new toast: '\(toast.message)', type: \(toast.type.description)")
            } else {
                print("🍞 UI: ToastOverlay received nil toast (dismissal)")
            }
        }
    }
}

extension View {
    func withToast(toastManager: ToastManager) -> some View {
        modifier(ToastOverlay(toastManager: toastManager))
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