//
//  CustomPhotoPicker.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI
import PhotosUI

enum PhotoSource {
    case camera
    case upload
}

struct CustomPhotoPicker: View {
    @Binding var isPresented: Bool
    let onPhotoSelected: (UIImage) -> Void
    let onCancel: () -> Void
    let onRetake: () -> Void
    @Binding var preCapturedImage: UIImage?
    @Binding var source: PhotoSource
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoadingImage: Bool = false
    @State private var showingPhotoPicker: Bool = false
    
    // Use the actual source passed in
    private var isFromCamera: Bool {
        source == .camera
    }
    
    init(isPresented: Binding<Bool>, preCapturedImage: Binding<UIImage?>, source: Binding<PhotoSource>, onPhotoSelected: @escaping (UIImage) -> Void, onRetake: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._isPresented = isPresented
        self._preCapturedImage = preCapturedImage
        self._source = source
        self.onPhotoSelected = onPhotoSelected
        self.onRetake = onRetake
        self.onCancel = onCancel
        self._selectedImage = State(initialValue: preCapturedImage.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header - simplified without Done button
                HStack {
                    Button(action: {
                        onCancel()
                        isPresented = false
                    }) {
                        Image("chevron-left")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 24, height: 24)
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                    
                    Spacer()
                    
                    Text("Select Photo")
                        .font(AppFonts.overusedGroteskSemiBold(size: 18))
                        .foregroundColor(AppColors.foregroundPrimary)
                    
                    Spacer()
                    
                    // Empty space to balance the layout
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AppColors.backgroundWhite)
                
            // Main content area
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if let selectedImage = selectedImage {
                        // Show captured/selected image
                        VStack(spacing: 16) {
                            Text(isFromCamera ? "Captured Photo" : "Uploaded Photo")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 500)
                                .background(AppColors.surfacePrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.linePrimary, lineWidth: 1)
                                )
                            
                            Text("Tap 'Done' to analyze this receipt")
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                    } else if isLoadingImage {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading photo...")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else {
                        // Photo picker option
                        VStack(spacing: 32) {
                            VStack(spacing: 24) {
                                AppIcon(assetName: "camera", fallbackSystemName: "camera.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppColors.foregroundSecondary)
                                
                                VStack(spacing: 8) {
                                    Text("Select a Receipt")
                                        .font(AppFonts.overusedGroteskSemiBold(size: 20))
                                        .foregroundColor(AppColors.foregroundPrimary)
                                    
                                    Text("Choose a photo from your library to analyze")
                                        .font(AppFonts.overusedGroteskMedium(size: 16))
                                        .foregroundColor(AppColors.foregroundSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            ZStack {
                                AppButton.primary("Choose from Photos", size: .small, leftIcon: "photo") {
                                    // This action won't be called due to overlay
                                }
                                
                                PhotosPicker(
                                    selection: $selectedPhoto,
                                    matching: .images,
                                    label: {
                                        Color.clear
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                )
                            }
                        }
                        .padding(.top, 40)
                    }
                    
                    // Add bottom spacing for the fixed buttons
                    Spacer()
                        .frame(height: 150)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // Fixed bottom buttons
            VStack(spacing: 12) {
                // Done button
                AppButton.primary("Done", size: .extraSmall) {
                    if let image = selectedImage {
                        onPhotoSelected(image)
                        isPresented = false
                    }
                }
                .disabled(selectedImage == nil)
                .opacity(selectedImage != nil ? 1.0 : 0.6)
                
                // Retake/Choose Another button
                AppButton.secondary(isFromCamera ? "Retake" : "Choose Another Photo", size: .extraSmall) {
                    print("🐛 DEBUG: Button tapped - source: \(source), isFromCamera: \(isFromCamera)")
                    if isFromCamera {
                        // Camera flow - retake photo
                        onRetake()
                        isPresented = false
                    } else {
                        // Upload flow - open photo picker
                        showingPhotoPicker = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(AppColors.backgroundWhite)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .background(AppColors.backgroundWhite)
        .onAppear {
            print("📸 CustomPhotoPicker: onAppear called")
            print("🐛 DEBUG: PhotoSource = \(source), isFromCamera = \(isFromCamera)")
            print("📸 CustomPhotoPicker: preCapturedImage is \(preCapturedImage != nil ? "NOT nil" : "nil")")
            // PERFORMANCE FIX: Only set selectedImage if it's not already set from init
            if selectedImage == nil, let capturedImg = preCapturedImage {
                // Use background thread for image assignment to prevent main thread blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    DispatchQueue.main.async {
                        selectedImage = capturedImg
                        print("📸 CustomPhotoPicker: Pre-captured image loaded successfully (async)")
                    }
                }
            } else if selectedImage != nil {
                print("📸 CustomPhotoPicker: Image already loaded from init, skipping duplicate assignment")
            } else {
                print("📸 CustomPhotoPicker: No pre-captured image to load")
            }
        }
        .onChange(of: preCapturedImage) { _, newImage in
            print("📸 CustomPhotoPicker: preCapturedImage changed - new image: \(newImage != nil)")
            if let newImage = newImage {
                // Use background thread for image assignment to prevent main thread blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    DispatchQueue.main.async {
                        selectedImage = newImage
                        print("📸 CustomPhotoPicker: Updated selectedImage from binding (async)")
                    }
                }
            }
        }
        .onChange(of: selectedPhoto) {
            if let selectedPhoto = selectedPhoto {
                loadPhoto(selectedPhoto)
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
    }
    
    private func loadPhoto(_ item: PhotosPickerItem) {
        isLoadingImage = true
        
        item.loadTransferable(type: Data.self) { result in
            // Use background thread for image processing
            DispatchQueue.global(qos: .userInitiated).async {
                switch result {
                case .success(let data):
                    if let data = data, let uiImage = UIImage(data: data) {
                        DispatchQueue.main.async {
                            selectedImage = uiImage
                            isLoadingImage = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            isLoadingImage = false
                            selectedPhoto = nil
                        }
                    }
                case .failure(let error):
                    print("Error loading image: \(error)")
                    DispatchQueue.main.async {
                        isLoadingImage = false
                        selectedPhoto = nil
                    }
                }
            }
        }
    }
}