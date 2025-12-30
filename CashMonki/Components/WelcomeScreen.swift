//
//  WelcomeScreen.swift
//  CashMonki
//
//  Created by Claude on 1/26/25.
//

import SwiftUI

struct WelcomeScreen: View {
    @Binding var isPresented: Bool
    
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.8
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Primary accent color background
            Color(red: 0.33, green: 0.18, blue: 1)
                .ignoresSafeArea(.all)
            
            VStack(alignment: .center, spacing: 208) {
                // Logo with animation - safe image loading
                Group {
                    if let logoImage = UIImage(named: "cashooya-logo") {
                        Image(uiImage: logoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                    } else {
                        // Fallback if logo doesn't load
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Text("CM")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            }
                    }
                }
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .animation(.easeInOut(duration: 0.8), value: logoOpacity)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: logoScale)
                
                // Made with love section
                VStack(spacing: 8) {
                    Text("Made with ❤️ & ☕ by")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Rosebud Studio")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .opacity(textOpacity)
                .animation(.easeInOut(duration: 0.6).delay(0.7), value: textOpacity)
            }
            .padding(.horizontal, 0)
            .padding(.top, 323)
            .padding(.bottom, 128)
        }
        .onAppear {
            print("🎬 WelcomeScreen: Appeared - starting animations and timer")
            print("🎬 WelcomeScreen: Current isPresented state: \(isPresented)")
            
            // Start animations immediately
            withAnimation(.easeInOut(duration: 0.8)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
            
            // Use simple DispatchQueue - more reliable in SwiftUI
            print("⏰ WelcomeScreen: Setting up auto-dismiss timer for 1.8 seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                print("⏰ WelcomeScreen: Timer fired! Dismissing welcome screen")
                print("⏰ WelcomeScreen: isPresented before dismiss: \(isPresented)")
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    isPresented = false
                }
                print("✅ WelcomeScreen: Dismissed successfully")
            }
        }
        .onTapGesture {
            // Allow manual dismiss by tapping
            print("👆 WelcomeScreen: Tap detected - manually dismissing")
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeScreen(isPresented: .constant(true))
}