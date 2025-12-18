//
//  RoastReceiptSheet.swift
//  CashMonki
//
//  Created by Claude Code on 12/11/24.
//

import SwiftUI
import Lottie

struct SimpleRoastLottie: UIViewRepresentable {
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: "roast")
        
        // Jitter's actual animation curves and timing
        animationView.loopMode = .loop
        animationView.animationSpeed = 1.0 // Normal speed for precise timing
        
        // Apply Jitter's signature entrance with simplified animation
        animationView.alpha = 0.0
        animationView.transform = CGAffineTransform.identity.scaledBy(x: 0.8, y: 0.8)
        
        // Animate with Jitter's spring curve using UIView animation
        UIView.animate(
            withDuration: 0.5,
            delay: 0.1,
            options: [.curveEaseOut],
            animations: {
                animationView.transform = .identity
                animationView.alpha = 1.0
            }
        )
        
        animationView.play()
        animationView.contentMode = .scaleAspectFit
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}

struct RoastReceiptSheet: View {
    @Binding var isPresented: Bool
    let roastMessage: String
    @State private var isFullHeight = false
    
    // Placeholder roast messages
    private static let placeholderRoasts = [
        "₱500 on Grab? Amazing. Paying premium just to sit in traffic with aircon.",
        "₱800 on coffee this week? Your caffeine addiction has its own credit score.",
        "₱1,200 on food delivery? The delivery fee costs more than cooking lessons.",
        "₱300 for bubble tea? That's some expensive sugar water with chewy bits.",
        "₱2,000 on shopping? Your wallet is crying harder than your bank account.",
        "₱150 on parking? You basically paid rent for your car to take a nap.",
        "₱600 on a single meal? Hope it came with a side of financial wisdom.",
        "₱400 on skincare? Your face better be glowing like your overspending habits.",
        "₱250 on a movie ticket? Netflix is laughing at your life choices.",
        "₱700 on a haircut? That better include a financial advisor consultation.",
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
            
            // Main roast message content
            VStack(spacing: 0) {
                Spacer()

                // Roast text
                Text(roastMessage)
                    .font(
                        Font.custom("Overused Grotesk", size: isFullHeight ? 34 : 28)
                            .weight(.semibold)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)

                Spacer()

                // Lottie animation - flush at bottom
                GeometryReader { geo in
                    SimpleRoastLottie()
                        .frame(width: geo.size.width, height: geo.size.width * (246/440))
                }
                .aspectRatio(440/246, contentMode: .fit)
            }
            .padding(.top, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
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