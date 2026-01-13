//
//  CameraView.swift
//  Cashooya Playground
//
//  Created by Claude on 10/18/25.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Lag Debug Helper
/// Singleton to track timing across components for camera lag debugging
class CameraLagDebug {
    static let shared = CameraLagDebug()
    private init() {}

    var scanButtonTappedAt: Date?
    var cameraViewAppearedAt: Date?
    var permissionRequestedAt: Date?
    var permissionGrantedAt: Date?
    var sessionConfigureStartedAt: Date?
    var sessionConfiguredAt: Date?
    var sessionStartedAt: Date?
    var firstFrameReadyAt: Date?

    func timeSinceScanButton() -> String {
        guard let start = scanButtonTappedAt else { return "N/A" }
        return String(format: "%.0f", Date().timeIntervalSince(start) * 1000)
    }

    func reset() {
        scanButtonTappedAt = nil
        cameraViewAppearedAt = nil
        permissionRequestedAt = nil
        permissionGrantedAt = nil
        sessionConfigureStartedAt = nil
        sessionConfiguredAt = nil
        sessionStartedAt = nil
        firstFrameReadyAt = nil
    }

    func printSummary() {
        print("🕐🕐🕐 CAMERA LAG DEBUG: ==== TIMING SUMMARY ====")
        guard let scanTap = scanButtonTappedAt else {
            print("🕐 No timing data available")
            return
        }

        if let appear = cameraViewAppearedAt {
            print("🕐 Button tap → View appear: \(String(format: "%.0f", appear.timeIntervalSince(scanTap) * 1000))ms")
        }
        if let permReq = permissionRequestedAt {
            print("🕐 Button tap → Permission request: \(String(format: "%.0f", permReq.timeIntervalSince(scanTap) * 1000))ms")
        }
        if let permGrant = permissionGrantedAt {
            print("🕐 Button tap → Permission granted: \(String(format: "%.0f", permGrant.timeIntervalSince(scanTap) * 1000))ms")
        }
        if let configStart = sessionConfigureStartedAt {
            print("🕐 Button tap → Config started: \(String(format: "%.0f", configStart.timeIntervalSince(scanTap) * 1000))ms")
        }
        if let configured = sessionConfiguredAt {
            print("🕐 Button tap → Session configured: \(String(format: "%.0f", configured.timeIntervalSince(scanTap) * 1000))ms")
        }
        if let started = sessionStartedAt {
            print("🕐 Button tap → Session running: \(String(format: "%.0f", started.timeIntervalSince(scanTap) * 1000))ms")
        }
        if let firstFrame = firstFrameReadyAt {
            print("🕐 Button tap → First frame ready: \(String(format: "%.0f", firstFrame.timeIntervalSince(scanTap) * 1000))ms")
        }
        print("🕐🕐🕐 ====================================")
    }
}

// MARK: - Focus Indicator View
struct FocusIndicatorView: View {
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            // Outer square
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)

            // Corner accents
            ForEach(0..<4) { index in
                CornerAccent()
                    .rotationEffect(.degrees(Double(index) * 90))
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            // Animate focus indicator
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
            }
            // Pulse animation
            withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
                opacity = 0.7
            }
            withAnimation(.easeInOut(duration: 0.3).delay(0.5)) {
                opacity = 1.0
            }
        }
    }
}

// Corner accent for focus indicator
private struct CornerAccent: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: -40, y: -40))
            path.addLine(to: CGPoint(x: -40, y: -28))
            path.move(to: CGPoint(x: -40, y: -40))
            path.addLine(to: CGPoint(x: -28, y: -40))
        }
        .stroke(Color.yellow, lineWidth: 3)
    }
}

struct CameraView: View {
    @Binding var isPresented: Bool
    let onPhotoTaken: (UIImage) -> Void
    let onCancel: () -> Void

    // Use the shared pre-warmed camera manager for instant camera access
    @ObservedObject private var cameraManager = CameraManager.shared
    @State private var showCaptureFlash = false

    // Focus state
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusIndicator = false

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea(.all)

            // Camera preview with tap-to-focus
            GeometryReader { geometry in
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea(.all)
                    .onTapGesture { location in
                        // Convert tap location to normalized point (0-1 range)
                        let normalizedPoint = CGPoint(
                            x: location.x / geometry.size.width,
                            y: location.y / geometry.size.height
                        )

                        // Set focus point for indicator
                        focusPoint = location

                        // Show focus indicator with animation
                        withAnimation(.easeOut(duration: 0.15)) {
                            showFocusIndicator = true
                        }

                        // Trigger focus on camera
                        cameraManager.focus(at: normalizedPoint)

                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        // Hide focus indicator after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showFocusIndicator = false
                            }
                        }
                    }
            }
            .ignoresSafeArea(.all)

            // Focus indicator
            if showFocusIndicator, let point = focusPoint {
                FocusIndicatorView()
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
            }

            // Capture flash overlay (white like a camera shutter)
            if showCaptureFlash {
                Color.white
                    .ignoresSafeArea(.all)
                    .transition(.opacity)
            }
            
            // Camera controls overlay
            VStack {
                // Top controls
                HStack {
                    Button {
                        onCancel()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cameraManager.toggleFlash()
                        }
                    } label: {
                        Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(cameraManager.isFlashOn ? Color.yellow.opacity(0.2) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .scaleEffect(cameraManager.isFlashOn ? 1.1 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Bottom capture controls
                VStack(spacing: 20) {
                    // Capture button
                    Button {
                        let captureButtonTapped = Date()
                        print("🕐 DEBUG TIMING: ==== CAPTURE BUTTON TAPPED ====")

                        // CRITICAL: Mark as capturing BEFORE anything else
                        cameraManager.isCapturing = true

                        // Brief white flash for visual feedback (like taking a photo)
                        withAnimation(.easeIn(duration: 0.1)) {
                            showCaptureFlash = true
                        }
                        // Flash fades quickly, camera preview stays frozen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeOut(duration: 0.1)) {
                                showCaptureFlash = false
                            }
                        }

                        // Capture photo - preview naturally freezes during capture
                        let photoCallback = onPhotoTaken
                        cameraManager.capturePhoto { [self] image in
                            let captureComplete = Date()
                            print("🕐 DEBUG TIMING: Photo capture complete, took \(String(format: "%.3f", captureComplete.timeIntervalSince(captureButtonTapped) * 1000))ms from button tap")
                            if let image = image {
                                print("📸 Camera: Photo captured successfully - Size: \(image.size)")
                                // Small delay to ensure image is fully processed for best quality
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    print("🕐 DEBUG TIMING: Calling onPhotoTaken callback after stabilization...")
                                    photoCallback(image)
                                    print("🕐 DEBUG TIMING: onPhotoTaken callback completed")
                                    // Dismiss after capture completes
                                    isPresented = false
                                }
                            } else {
                                print("❌ Camera: Photo capture returned nil image!")
                                DispatchQueue.main.async {
                                    isPresented = false
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                                .frame(width: 70, height: 70)
                        }
                    }
                    .disabled(cameraManager.isCapturing)
                    .opacity(cameraManager.isCapturing ? 0.6 : 1.0)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // 🕐 CAMERA LAG DEBUG - Track view appearance
            CameraLagDebug.shared.cameraViewAppearedAt = Date()
            print("🕐🕐🕐 CAMERA LAG DEBUG: CameraView.onAppear - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
            print("📸 Camera: View appeared - Using StateObject camera manager")
            print("📸 Camera: Manager configured: \(cameraManager.isConfigured), session running: \(cameraManager.session.isRunning)")

            // Always ensure camera starts properly, even for retakes
            if !cameraManager.session.isRunning {
                // 🕐 CAMERA LAG DEBUG - Track permission request
                CameraLagDebug.shared.permissionRequestedAt = Date()
                print("🕐 CAMERA LAG DEBUG: Requesting permission - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")

                // Use requestPermissionOrOpenSettings to handle denied case
                cameraManager.requestPermissionOrOpenSettings { granted in
                    // 🕐 CAMERA LAG DEBUG - Track permission granted
                    CameraLagDebug.shared.permissionGrantedAt = Date()
                    print("🕐 CAMERA LAG DEBUG: Permission callback received - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")

                    if granted {
                        print("📸 Camera: Permission granted, starting session")
                        cameraManager.startSession()
                        // OPTIMIZATION: Removed 1.5s refresh delay - no longer needed
                    } else {
                        // Permission denied - Settings was opened, dismiss camera
                        print("📸 Camera: Permission denied, Settings opened")
                        onCancel()
                        isPresented = false
                    }
                }
            } else {
                print("📸 Camera: Session already running - using pre-warmed session")
                // OPTIMIZATION: No refresh needed for pre-warmed session
            }
        }
        .onDisappear {
            print("📸 Camera: View disappearing")
            // OPTIMIZATION: Keep the shared session running for instant next use
            // The session will stay warm until the app is backgrounded
            print("📸 Camera: Keeping session warm for next use")
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        // 🕐 CAMERA LAG DEBUG - Track preview creation
        print("🕐 CAMERA LAG DEBUG: CameraPreview.makeUIView - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
        print("📸 CameraPreview: Creating view with session running: \(session.isRunning)")
        let view = UIView()
        view.backgroundColor = UIColor.black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        // Set rotation to 90 degrees for portrait mode (0 = landscape, 90 = portrait)
        previewLayer.connection?.videoRotationAngle = 90
        view.layer.addSublayer(previewLayer)

        print("📸 CameraPreview: Preview layer created and added")
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 🕐 CAMERA LAG DEBUG - Track preview updates (first update often means first frame)
        if CameraLagDebug.shared.firstFrameReadyAt == nil && session.isRunning {
            CameraLagDebug.shared.firstFrameReadyAt = Date()
            print("🕐🕐🕐 CAMERA LAG DEBUG: First frame ready! - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
            CameraLagDebug.shared.printSummary()
        }
        print("📸 CameraPreview: Updating view - session running: \(session.isRunning)")
        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
                print("📸 CameraPreview: Updated frame to \(uiView.bounds)")

                // Ensure the preview layer is connected to the current session
                if previewLayer.session != session {
                    print("📸 CameraPreview: Session mismatch, recreating layer")
                    previewLayer.removeFromSuperlayer()
                    let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                    newPreviewLayer.videoGravity = .resizeAspectFill
                    newPreviewLayer.connection?.videoRotationAngle = 90 // Portrait mode
                    newPreviewLayer.frame = uiView.bounds
                    uiView.layer.addSublayer(newPreviewLayer)
                }
            }
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    // MARK: - Shared Instance for Pre-warming
    /// Shared instance used for camera pre-warming. This allows the camera session
    /// to be started before the user taps "Scan" for instant camera access.
    static let shared = CameraManager()

    /// Pre-warm the camera session. Call this when HomePage appears.
    /// This starts the camera session in the background so it's ready when user taps Scan.
    static func prewarm() {
        print("🔥 Camera: Pre-warming camera session...")
        let prewarmStart = Date()

        shared.requestPermission { granted in
            if granted {
                print("🔥 Camera: Permission granted, starting pre-warm session")
                shared.startSession()

                // Track pre-warm completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let prewarmDuration = Date().timeIntervalSince(prewarmStart) * 1000
                    if shared.session.isRunning {
                        print("🔥✅ Camera: Pre-warm complete! Session ready in \(String(format: "%.0f", prewarmDuration))ms")
                    } else {
                        print("🔥⏳ Camera: Pre-warm still in progress...")
                    }
                }
            } else {
                print("🔥❌ Camera: Pre-warm skipped - no permission")
            }
        }
    }

    /// Check if the shared camera is pre-warmed and ready
    static var isPrewarmed: Bool {
        return shared.isConfigured && shared.session.isRunning
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private(set) var isConfigured = false
    private var isConfiguring = false

    @Published var isCapturing = false
    @Published var isFlashOn = false

    private var photoCompletionHandler: ((UIImage?) -> Void)?

    // Private init for shared instance, but allow creation for non-shared use
    override init() {
        super.init()
    }

    deinit {
        print("📸 Camera: CameraManager deinit - cleaning up session")
        // Don't cleanup if still capturing - let capture complete first
        if !isCapturing {
            cleanupSession()
        } else {
            print("📸 Camera: Deinit while capturing - cleanup will happen after capture")
        }
    }

    func cleanupSession() {
        print("📸 Camera: Starting session cleanup (non-blocking)")

        // Don't clear completion handler if still capturing
        if !isCapturing {
            photoCompletionHandler = nil
        }

        // Clear state immediately on main thread
        isConfigured = false
        isConfiguring = false

        // Move heavy cleanup to background thread - this prevents 9+ second delays
        DispatchQueue.global(qos: .utility).async { [session] in
            print("📸 Camera: Background cleanup starting...")

            if session.isRunning {
                session.stopRunning()
                print("📸 Camera: Session stopped (background)")
            }
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            print("📸 Camera: Session cleanup completed")
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Request permission or open Settings if previously denied
    /// Returns true if permission granted, false if denied (Settings opened)
    func requestPermissionOrOpenSettings(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            // First time - show permission dialog
            requestPermission(completion: completion)

        case .denied, .restricted:
            // Previously denied - open Settings
            print("📸 Camera: Permission denied, opening Settings")
            DispatchQueue.main.async {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                completion(false)
            }

        case .authorized:
            // Already authorized
            completion(true)

        @unknown default:
            completion(false)
        }
    }

    /// Check if camera permission is currently authorized
    static var isAuthorized: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// Check permission and return status for UI handling (shows alert if denied)
    static func checkPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .notDetermined:
            // First time - request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted ? .granted : .denied)
                }
            }

        case .denied, .restricted:
            // Previously denied - let caller show alert
            completion(.denied)

        case .authorized:
            completion(.granted)

        @unknown default:
            completion(.denied)
        }
    }
    
    func startSession() {
        print("📸 Camera: Starting session - current running state: \(session.isRunning)")
        print("🕐 CAMERA LAG DEBUG: startSession called - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if !self.isConfigured {
                // 🕐 CAMERA LAG DEBUG - Track configuration start
                CameraLagDebug.shared.sessionConfigureStartedAt = Date()
                print("🕐 CAMERA LAG DEBUG: configureSession starting - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
                print("📸 Camera: Configuring session...")
                self.configureSession()
                // configureSession() will handle starting the session after configuration
            } else if !self.session.isRunning {
                print("📸 Camera: Starting already configured session...")
                DispatchQueue.global(qos: .userInitiated).async {
                    let startRunningStart = Date()
                    self.session.startRunning()
                    let startRunningDuration = Date().timeIntervalSince(startRunningStart) * 1000
                    print("📸 Camera: Session started successfully (took \(String(format: "%.0f", startRunningDuration))ms)")
                    print("🕐 CAMERA LAG DEBUG: Session running - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
                }
            } else {
                print("📸 Camera: Session was already running")
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { 
            print("📸 Camera: Session already stopped")
            return 
        }
        
        print("📸 Camera: Stopping session (non-blocking)...")
        // PERFORMANCE FIX: Make session stop non-blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.session.stopRunning()
            print("📸 Camera: Session stopped (background)")
        }
    }
    
    private func configureSession() {
        guard !isConfigured && !isConfiguring else {
            print("📸 Camera: Session already configured or currently configuring")
            return
        }

        // 🕐 CAMERA LAG DEBUG - Track each configuration step
        let configStartTime = Date()
        var stepStartTime = Date()

        isConfiguring = true
        print("📸 Camera: Beginning session configuration...")
        print("🕐 CAMERA LAG DEBUG: [STEP 1] beginConfiguration starting - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
        session.beginConfiguration()
        print("🕐 CAMERA LAG DEBUG: [STEP 1] beginConfiguration took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        // Set lower quality preset for faster capture
        stepStartTime = Date()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
            print("📸 Camera: Using .high preset for faster capture")
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
            print("📸 Camera: Using .medium preset for faster capture")
        } else {
            session.sessionPreset = .photo
            print("📸 Camera: Fallback to .photo preset")
        }
        print("🕐 CAMERA LAG DEBUG: [STEP 2] Set preset took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        // Remove any existing inputs and outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Add camera input
        stepStartTime = Date()
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("📸 Camera: Failed to get camera device")
            session.commitConfiguration()
            isConfiguring = false
            return
        }
        print("🕐 CAMERA LAG DEBUG: [STEP 3] Get camera device took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        captureDevice = camera

        // Configure camera device settings
        stepStartTime = Date()
        do {
            try camera.lockForConfiguration()

            // Set focus mode
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }

            // Set exposure mode
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }

            // Set white balance mode
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }

            camera.unlockForConfiguration()
        } catch {
            print("📸 Camera: Failed to configure camera device: \(error)")
        }
        print("🕐 CAMERA LAG DEBUG: [STEP 4] Device config (focus/exposure/WB) took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        // Create and add camera input
        stepStartTime = Date()
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                print("📸 Camera: Camera input added successfully")
            } else {
                print("📸 Camera: Cannot add camera input")
                session.commitConfiguration()
                isConfiguring = false
                return
            }
        } catch {
            print("📸 Camera: Failed to create camera input: \(error)")
            session.commitConfiguration()
            isConfiguring = false
            return
        }
        print("🕐 CAMERA LAG DEBUG: [STEP 5] Create + add input took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        // Configure and add photo output
        stepStartTime = Date()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            // Configure photo output for fast capture - disable high resolution
            if #available(iOS 16.0, *) {
                // Don't set maxPhotoDimensions - let it use session preset
                print("📸 Camera: Using session preset dimensions for fast capture")
            } else {
                // Disable high resolution for faster capture
                photoOutput.isHighResolutionCaptureEnabled = false
                print("📸 Camera: Disabled high resolution capture for speed")
            }

            // Configure connection if available
            if let connection = photoOutput.connection(with: .video) {
                if #available(iOS 13.0, *) {
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
            }

            print("📸 Camera: Photo output added and configured")
        } else {
            print("📸 Camera: Cannot add photo output")
            session.commitConfiguration()
            isConfiguring = false
            return
        }
        print("🕐 CAMERA LAG DEBUG: [STEP 6] Add output took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        stepStartTime = Date()
        session.commitConfiguration()
        print("🕐 CAMERA LAG DEBUG: [STEP 7] commitConfiguration took \(String(format: "%.0f", Date().timeIntervalSince(stepStartTime) * 1000))ms")

        isConfiguring = false
        isConfigured = true

        // 🕐 CAMERA LAG DEBUG - Track configuration complete
        CameraLagDebug.shared.sessionConfiguredAt = Date()
        print("📸 Camera: Session configured successfully")
        print("🕐 CAMERA LAG DEBUG: Total config time: \(String(format: "%.0f", Date().timeIntervalSince(configStartTime) * 1000))ms")
        print("🕐 CAMERA LAG DEBUG: Session configured - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")

        // Start the session after configuration is complete
        if !session.isRunning {
            print("📸 Camera: Starting session after configuration...")
            print("🕐 CAMERA LAG DEBUG: [STEP 8] startRunning starting - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
            stepStartTime = Date()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let runningStartTime = Date()
                self.session.startRunning()

                // 🕐 CAMERA LAG DEBUG - Track session started
                CameraLagDebug.shared.sessionStartedAt = Date()
                print("🕐 CAMERA LAG DEBUG: [STEP 8] session.startRunning() took \(String(format: "%.0f", Date().timeIntervalSince(runningStartTime) * 1000))ms")
                print("🕐 CAMERA LAG DEBUG: Session running - \(CameraLagDebug.shared.timeSinceScanButton())ms since scan button")
                print("📸 Camera: Session started successfully after configuration")

                // Print final summary
                DispatchQueue.main.async {
                    CameraLagDebug.shared.printSummary()
                }
            }
        }
    }
    
    func resetSession() {
        print("📸 Camera: Resetting session")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                DispatchQueue.global(qos: .utility).async {
                    self.session.stopRunning()
                    print("📸 Camera: Session stopped for reset")
                }
            }
            
            self.isConfigured = false
            self.isConfiguring = false
            
            // Wait a moment then restart on the same background queue
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if !self.isConfigured && !self.isConfiguring {
                    print("📸 Camera: Reconfiguring session after reset...")
                    self.configureSession()
                }
            }
        }
    }
    
    func checkSessionHealth() -> Bool {
        guard isConfigured else {
            print("📸 Camera: Session not configured")
            return false
        }
        
        guard session.isRunning else {
            print("📸 Camera: Session not running")
            return false
        }
        
        guard captureDevice != nil else {
            print("📸 Camera: No capture device")
            return false
        }
        
        guard !session.inputs.isEmpty else {
            print("📸 Camera: No session inputs")
            return false
        }
        
        guard !session.outputs.isEmpty else {
            print("📸 Camera: No session outputs")
            return false
        }
        
        return true
    }
    
    func refreshPreview() {
        print("📸 Camera: Refreshing preview")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                DispatchQueue.global(qos: .utility).async {
                    self.session.stopRunning()
                    
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.session.startRunning()
                        print("📸 Camera: Preview refreshed")
                    }
                }
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        // Note: isCapturing may already be true (set before calling this to prevent race conditions)
        guard photoCompletionHandler == nil else {
            print("📸 Camera: Already has pending completion handler, ignoring request")
            return
        }

        // Check session health before capture
        guard checkSessionHealth() else {
            print("📸 Camera: Session health check failed, attempting reset")
            isCapturing = false
            resetSession()
            completion(nil)
            return
        }

        // Ensure isCapturing is true (may already be set externally)
        isCapturing = true
        photoCompletionHandler = completion
        
        // Create photo settings
        let settings: AVCapturePhotoSettings
        
        // Use available photo codec types
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings()
        }
        
        // Configure flash safely
        if let device = captureDevice {
            if device.hasFlash && device.isFlashAvailable {
                settings.flashMode = isFlashOn ? .on : .off
            } else {
                settings.flashMode = .off
                if isFlashOn {
                    print("📸 Camera: Flash requested but not available")
                }
            }
        }
        
        // Configure capture settings for fastest possible capture
        if #available(iOS 16.0, *) {
            // Don't set maxPhotoDimensions - use session preset for speed
            print("📸 Camera: Using default dimensions for fast capture")
        } else {
            // Disable high resolution for fastest capture
            settings.isHighResolutionPhotoEnabled = false
            print("📸 Camera: Disabled high resolution in capture settings")
        }
        
        print("📸 Camera: Attempting photo capture with settings: \(settings)")
        
        // Ensure we're on the session queue for capture
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        print("📸 Camera: Flash toggled to \(isFlashOn ? "ON" : "OFF")")
    }

    /// Focus the camera at a specific point (normalized 0-1 coordinates)
    func focus(at point: CGPoint) {
        guard let device = captureDevice else {
            print("📸 Camera: No capture device for focus")
            return
        }

        do {
            try device.lockForConfiguration()

            // Convert point for camera orientation (camera is rotated 90 degrees)
            // For portrait mode, we need to swap and invert coordinates
            let focusPoint = CGPoint(x: point.y, y: 1.0 - point.x)

            // Set focus point if supported
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
                print("📸 Camera: Focus point set to (\(String(format: "%.2f", focusPoint.x)), \(String(format: "%.2f", focusPoint.y)))")
            }

            // Set exposure point if supported
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
                print("📸 Camera: Exposure point set")
            }

            device.unlockForConfiguration()

            // Reset to continuous auto focus after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.resetToContinuousAutoFocus()
            }

        } catch {
            print("📸 Camera: Failed to set focus: \(error.localizedDescription)")
        }
    }

    /// Reset camera to continuous auto focus mode
    private func resetToContinuousAutoFocus() {
        guard let device = captureDevice else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
            print("📸 Camera: Reset to continuous auto focus")
        } catch {
            print("📸 Camera: Failed to reset focus mode: \(error.localizedDescription)")
        }
    }

    @available(iOS 16.0, *)
    private func findBestPhotoDimension(from supportedDimensions: [CMVideoDimensions]) -> CMVideoDimensions? {
        // Target smaller dimensions for fast capture and reasonable memory usage
        let targetMaxPixels: Int32 = 1920 * 1080  // ~2MP (1080p quality)
        
        // Sort by total pixels and find the largest that's under our target
        let sortedDimensions = supportedDimensions.sorted { dimension1, dimension2 in
            let pixels1 = dimension1.width * dimension1.height
            let pixels2 = dimension2.width * dimension2.height
            return pixels1 < pixels2
        }
        
        print("📸 Camera: Available photo dimensions:")
        for dimension in sortedDimensions {
            let pixels = dimension.width * dimension.height
            print("  - \(dimension.width)x\(dimension.height) (\(pixels) pixels)")
        }
        
        // Find the largest dimension that's still reasonable for memory and speed
        for dimension in sortedDimensions.reversed() {
            let pixels = dimension.width * dimension.height
            if pixels <= targetMaxPixels {
                print("📸 Camera: Selected dimension: \(dimension.width)x\(dimension.height)")
                return dimension
            }
        }
        
        // If all are too large, use the smallest available
        let smallest = sortedDimensions.first
        if let smallest = smallest {
            print("📸 Camera: All dimensions too large, using smallest: \(smallest.width)x\(smallest.height)")
        }
        return smallest
    }
}

// MARK: - Photo Capture Delegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("📸 Camera: Will begin capture for settings: \(resolvedSettings)")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("📸 Camera: Will capture photo")
        
        // Add capture feedback (optional visual/haptic)
        DispatchQueue.main.async {
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Capture completion handler EARLY to ensure it survives manager deallocation
        let completionHandler = photoCompletionHandler

        if let error = error {
            print("📸 Camera: Photo capture error: \(error)")
            photoCompletionHandler = nil

            // Handle specific error types
            let nsError = error as NSError
            switch nsError.code {
            case -11803: // Cannot Record
                print("📸 Camera: Cannot record error - attempting session reset")
                DispatchQueue.main.async { [weak self] in
                    self?.resetSession()
                }
            case -11852: // Session not running
                print("📸 Camera: Session not running - restarting session")
                DispatchQueue.main.async { [weak self] in
                    self?.startSession()
                }
            default:
                print("📸 Camera: Unhandled capture error code: \(nsError.code)")
            }

            DispatchQueue.main.async { [weak self] in
                self?.isCapturing = false
                completionHandler?(nil)
                self?.stopSession()
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            print("📸 Camera: Failed to get photo data representation")
            photoCompletionHandler = nil
            DispatchQueue.main.async { [weak self] in
                self?.isCapturing = false
                completionHandler?(nil)
                self?.stopSession()
            }
            return
        }

        // Clear handler now that we've captured it
        photoCompletionHandler = nil

        // PERFORMANCE FIX: Move expensive UIImage creation to background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let image = UIImage(data: data) else {
                print("📸 Camera: Failed to convert photo data to UIImage")
                DispatchQueue.main.async {
                    self?.isCapturing = false
                    completionHandler?(nil)
                    self?.stopSession()
                }
                return
            }

            print("📸 Camera: Photo captured successfully - size: \(image.size)")

            // Return image on main thread (already captured at optimal size)
            DispatchQueue.main.async {
                self?.isCapturing = false
                completionHandler?(image)
                self?.stopSession()
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("📸 Camera: Capture finished with error: \(error)")
        } else {
            print("📸 Camera: Capture finished successfully")
        }
    }
}

// MARK: - Preview
#Preview {
    CameraView(
        isPresented: .constant(true),
        onPhotoTaken: { _ in print("Photo taken") },
        onCancel: { print("Cancelled") }
    )
}