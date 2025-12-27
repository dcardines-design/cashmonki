//
//  RoastReceiptSheet.swift
//  CashMonki
//
//  Created by Claude Code on 12/11/24.
//

import SwiftUI
import ImageIO

struct GIFAnimationView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.clipsToBounds = true

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // Load GIF from File Assets folder
        if let gifPath = Bundle.main.path(forResource: gifName, ofType: "gif"),
           let gifData = try? Data(contentsOf: URL(fileURLWithPath: gifPath)),
           let source = CGImageSourceCreateWithData(gifData as CFData, nil) {

            var images: [UIImage] = []
            var totalDuration: Double = 0

            let frameCount = CGImageSourceGetCount(source)

            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(UIImage(cgImage: cgImage))

                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                        if let delay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                            totalDuration += delay
                        } else if let delay = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                            totalDuration += delay
                        } else {
                            totalDuration += 0.1
                        }
                    }
                }
            }

            imageView.animationImages = images
            imageView.animationDuration = totalDuration
            imageView.animationRepeatCount = 0 // Loop forever
            imageView.startAnimating()
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct RoastReceiptSheet: View {
    @Binding var isPresented: Bool
    let roastMessage: String
    @State private var isFullHeight = false
    
    // Placeholder roast messages - brutally mean and unhinged
    private static let placeholderRoasts = [
        "₱500 on Grab because walking is for people with their life together. Your couch misses you already.",
        "₱800 on coffee this week? At this point your blood type is just 'iced latte'. Your organs are planning an intervention.",
        "₱1,200 on delivery? The rider knows your order by heart now. He's seen you in pajamas more than your family has.",
        "₱300 on bubble tea again? You're not treating yourself, you're funding a tapioca addiction you refuse to acknowledge.",
        "₱2,000 on shopping for clothes you'll wear once, photograph, then exile to the closet void. The landfill thanks you in advance.",
        "₱150 on parking? You paid your car to sit there and judge your life choices. At least someone's relaxing.",
        "₱600 on one meal? Your wallet just sent a distress signal. Your future self is already planning the instant noodle recovery arc.",
        "₱400 on skincare for a face that only sees phone screen glow. Bold investment for someone who hasn't touched grass this week.",
        "₱250 for a movie? At that price they should've let you direct it. Hope you at least stayed awake.",
        "₱700 haircut? They could've just burned your money in front of you for the same emotional experience.",
    ]
    
    init(isPresented: Binding<Bool>, roastMessage: String? = nil) {
        self._isPresented = isPresented
        self.roastMessage = roastMessage ?? Self.placeholderRoasts.randomElement() ?? Self.placeholderRoasts[0]
    }
    
    var body: some View {
        ZStack {
            // Custom drag indicator
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 6)
                    .padding(.top, 20)

                Spacer()
            }

            // Header with close button
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }

            // Main roast message content (text only)
            VStack(spacing: 0) {
                Spacer()

                // Roast text
                Text(roastMessage)
                    .font(
                        Font.custom("Overused Grotesk", size: isFullHeight ? 30 : 28)
                            .weight(.semibold)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)

                Spacer()

                // Spacer for GIF area
                Color.clear.frame(height: 220)
            }
            .padding(.top, 60)

            // GIF animation - fixed at bottom, full width, no padding
            GeometryReader { geo in
                VStack {
                    Spacer()
                    GIFAnimationView(gifName: "roast-animation-2")
                        .frame(width: geo.size.width, height: 220)
                        .clipped()
                        .offset(y: 30)
                }
            }
            .ignoresSafeArea(.all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geometry in
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .black, location: 0.00),
                        Gradient.Stop(color: Color(red: 0.17, green: 0.07, blue: 0), location: 1.00),
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
                .ignoresSafeArea(.all)
                .onAppear {
                    checkSheetHeight(geometry.size.height)
                }
                .onChange(of: geometry.size.height) { oldValue, newValue in
                    checkSheetHeight(newValue)
                }
            }
        )
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 44, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 44))
        .ignoresSafeArea(.all)
        .shadow(color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.18), radius: 24, x: 0, y: 24)
    }
    
    private func checkSheetHeight(_ height: CGFloat) {
        // Consider the sheet "full height" if it's more than 80% of typical screen height
        let screenHeight = UIScreen.main.bounds.height
        let threshold = screenHeight * 0.8
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isFullHeight = height > threshold
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            RoastReceiptSheet(
                isPresented: .constant(true),
                roastMessage: "₱500 on Grab? Amazing. Paying premium just to sit in traffic with aircon."
            )
            .frame(height: UIScreen.main.bounds.height * 0.5)
        }
    }
}