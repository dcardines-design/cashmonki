//
//  CameraView.swift
//  Cashooya Playground
//
//  Created by Claude on 10/18/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var isPresented: Bool
    let onPhotoTaken: (UIImage) -> Void
    let onCancel: () -> Void
    
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea(.all)
            
            // Camera preview
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea(.all)
            
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
                        // PERFORMANCE FIX: Dismiss camera IMMEDIATELY on tap
                        // Don't wait for photo capture to complete
                        print("🕐 DEBUG TIMING: ==== CAPTURE BUTTON TAPPED ====")
                        print("🕐 DEBUG TIMING: Capture button tapped at \(captureButtonTapped)")
                        print("📸 Camera: Dismissing camera immediately...")
                        isPresented = false
                        print("🕐 DEBUG TIMING: isPresented set to false in \(String(format: "%.3f", Date().timeIntervalSince(captureButtonTapped) * 1000))ms")

                        // Capture photo in background after dismissal starts
                        cameraManager.capturePhoto { image in
                            let captureComplete = Date()
                            print("🕐 DEBUG TIMING: Photo capture complete, took \(String(format: "%.3f", captureComplete.timeIntervalSince(captureButtonTapped) * 1000))ms from button tap")
                            if let image = image {
                                print("📸 Camera: Photo captured successfully - Size: \(image.size)")
                                print("🕐 DEBUG TIMING: Calling onPhotoTaken callback...")
                                let callbackStart = Date()
                                onPhotoTaken(image)
                                print("🕐 DEBUG TIMING: onPhotoTaken callback returned in \(String(format: "%.3f", Date().timeIntervalSince(callbackStart) * 1000))ms")
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
            print("📸 Camera: View appeared - Using StateObject camera manager")
            print("📸 Camera: Manager configured: \(cameraManager.isConfigured), session running: \(cameraManager.session.isRunning)")
            
            // Always ensure camera starts properly, even for retakes
            if !cameraManager.session.isRunning {
                cameraManager.requestPermission { granted in
                    if granted {
                        print("📸 Camera: Permission granted, starting session")
                        cameraManager.startSession()
                        
                        // Add a small delay to refresh preview if it's black
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            print("📸 Camera: Refreshing preview to prevent black screen")
                            cameraManager.refreshPreview()
                        }
                    } else {
                        print("📸 Camera: Permission denied")
                        onCancel()
                        isPresented = false
                    }
                }
            } else {
                print("📸 Camera: Session already running")
                // Still refresh preview in case it's black
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("📸 Camera: Refreshing preview for already running session")
                    cameraManager.refreshPreview()
                }
            }
        }
        .onDisappear {
            print("📸 Camera: View disappearing")
            // DON'T stop session here - let capture complete first
            // Session will be cleaned up when manager is deallocated
            // Only stop if NOT currently capturing
            if !cameraManager.isCapturing {
                print("📸 Camera: Not capturing, stopping session")
                DispatchQueue.global(qos: .userInitiated).async {
                    cameraManager.stopSession()
                }
            } else {
                print("📸 Camera: Still capturing, will stop after completion")
            }
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        print("📸 CameraPreview: Creating view with session running: \(session.isRunning)")
        let view = UIView()
        view.backgroundColor = UIColor.black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoRotationAngle = 0
        view.layer.addSublayer(previewLayer)
        
        print("📸 CameraPreview: Preview layer created and added")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
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
                    newPreviewLayer.frame = uiView.bounds
                    uiView.layer.addSublayer(newPreviewLayer)
                }
            }
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private(set) var isConfigured = false
    private var isConfiguring = false
    
    @Published var isCapturing = false
    @Published var isFlashOn = false
    
    private var photoCompletionHandler: ((UIImage?) -> Void)?
    
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
    
    func startSession() {
        print("📸 Camera: Starting session - current running state: \(session.isRunning)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if !self.isConfigured {
                print("📸 Camera: Configuring session...")
                self.configureSession()
                // configureSession() will handle starting the session after configuration
            } else if !self.session.isRunning {
                print("📸 Camera: Starting already configured session...")
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.startRunning()
                    print("📸 Camera: Session started successfully")
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
        
        isConfiguring = true
        print("📸 Camera: Beginning session configuration...")
        session.beginConfiguration()
        
        // Set lower quality preset for faster capture
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
        
        // Remove any existing inputs and outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("📸 Camera: Failed to get camera device")
            session.commitConfiguration()
            isConfiguring = false
            return
        }
        
        captureDevice = camera
        
        // Configure camera device settings
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
        
        // Create and add camera input
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
        
        // Configure and add photo output
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
        
        session.commitConfiguration()
        isConfiguring = false
        isConfigured = true
        print("📸 Camera: Session configured successfully")
        
        // Start the session after configuration is complete
        if !session.isRunning {
            print("📸 Camera: Starting session after configuration...")
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                print("📸 Camera: Session started successfully after configuration")
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
        guard !isCapturing else { 
            print("📸 Camera: Already capturing, ignoring request")
            return 
        }
        
        // Check session health before capture
        guard checkSessionHealth() else {
            print("📸 Camera: Session health check failed, attempting reset")
            resetSession()
            completion(nil)
            return
        }
        
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