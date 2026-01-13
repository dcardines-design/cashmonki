//
//  SocialProofOnboardingView.swift
//  CashMonki
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

struct SocialProofOnboardingView: View {
    @Binding var isPresented: Bool
    let onContinue: () -> Void
    let onBack: (() -> Void)?

    // Animation states
    @State private var showRating = false
    @State private var showStats = false
    @State private var showFollowers = false
    @State private var showTestimonial = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 30)

                    // Rating and Stats Section (grouped with 20px spacing)
                    ratingAndStatsSection

                    // User Photos and Testimonial Section (grouped with 20px spacing)
                    userPhotosAndTestimonialSection

                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 30)
            }

            // Dynamic Progress Bar
            OnboardingProgressBar.dynamic(
                currentStep: .socialProof,
                isGmailUser: false
            )

            // Continue Button
            FixedBottomGroup.primary(
                title: "Continue",
                action: {
                    print("⭐ SocialProof: Continue tapped")
                    onContinue()
                }
            )
        }
        .background(
            LinearGradient(
                stops: [
                    Gradient.Stop(color: .white, location: 0.00),
                    Gradient.Stop(color: Color(red: 1, green: 0.97, blue: 0.92), location: 1.00),
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1)
            )
        )
        .navigationBarHidden(true)
        .onAppear {
            print("⭐ SocialProof: Showing social proof screen")

            // Track analytics
            AnalyticsManager.shared.track(.onboardingValueFeatureViewed, properties: [
                "feature_number": 0,
                "feature_name": "social_proof"
            ])

            // Staggered fade-in animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showRating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showStats = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showFollowers = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showTestimonial = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Back Button
            if let onBack = onBack {
                Button(action: onBack) {
                    Image("chevron-left")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.backgroundWhite)
    }

    // MARK: - Rating and Stats Section

    private var ratingAndStatsSection: some View {
        VStack(spacing: 20) {
            // Rating with laurel wreaths
            Image("wreath-rating")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 96)
                .opacity(showRating ? 1 : 0)
                .offset(y: showRating ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: showRating)

            // Stats text
            Text("Math says it's working. 82% of surveyed Cashmonki users report better net worth over time.")
                .font(
                    Font.custom("Overused Grotesk", size: 26)
                        .weight(.semibold)
                )
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.accentBackground)
                .frame(maxWidth: .infinity, alignment: .top)
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: showStats)
        }
    }

    // MARK: - User Photos and Testimonial Section

    private var userPhotosAndTestimonialSection: some View {
        VStack(spacing: 20) {
            // User photos with laurel wreaths
            Image("wreath-followers")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 96)
                .opacity(showFollowers ? 1 : 0)
                .offset(y: showFollowers ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: showFollowers)

            // Testimonial
            VStack(spacing: 12) {
                // Quote
                Text("\u{201C}Been having a hard time tracking down my expenses for each day. This made things easier for me.\u{201D}")
                    .font(
                        Font.custom("Overused Grotesk", size: 20)
                            .weight(.medium)
                            .italic()
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundPrimary)
                    .frame(maxWidth: .infinity, alignment: .top)

                // Attribution
                Text("- Nicole E. MD, Cashmonki user")
                    .font(
                        Font.custom("Overused Grotesk", size: 15)
                            .weight(.medium)
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.foregroundSecondary)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .opacity(showTestimonial ? 1 : 0)
            .offset(y: showTestimonial ? 0 : 20)
            .animation(.easeOut(duration: 0.5), value: showTestimonial)
        }
    }
}

// MARK: - Preview

#Preview {
    SocialProofOnboardingView(
        isPresented: .constant(true),
        onContinue: { print("Continue tapped") },
        onBack: { print("Back tapped") }
    )
}
