//
//  SubscriptionCard.swift
//  CashMonki
//
//  Card component for displaying subscriptions in a grid
//

import SwiftUI

struct SubscriptionCard: View {
    let subscription: Subscription
    let onTap: (() -> Void)?

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared

    init(subscription: Subscription, onTap: (() -> Void)? = nil) {
        self.subscription = subscription
        self.onTap = onTap
    }

    // Known merchant → domain mappings for Clearbit logos
    private static let merchantDomains: [String: String] = [
        // Streaming
        "spotify": "spotify.com",
        "netflix": "netflix.com",
        "hulu": "hulu.com",
        "disney+": "disneyplus.com",
        "disney plus": "disneyplus.com",
        "hbo": "hbomax.com",
        "hbo max": "hbomax.com",
        "apple music": "apple.com",
        "apple tv": "apple.com",
        "youtube": "youtube.com",
        "youtube premium": "youtube.com",
        "amazon prime": "amazon.com",
        "prime video": "amazon.com",
        "paramount+": "paramountplus.com",
        "peacock": "peacocktv.com",
        "crunchyroll": "crunchyroll.com",

        // Software/Apps
        "adobe": "adobe.com",
        "adobe suite": "adobe.com",
        "adobe creative cloud": "adobe.com",
        "microsoft": "microsoft.com",
        "microsoft 365": "microsoft.com",
        "office 365": "microsoft.com",
        "google": "google.com",
        "google one": "google.com",
        "dropbox": "dropbox.com",
        "icloud": "apple.com",
        "icloud storage": "apple.com",
        "notion": "notion.so",
        "slack": "slack.com",
        "zoom": "zoom.us",
        "canva": "canva.com",
        "figma": "figma.com",
        "github": "github.com",
        "chatgpt": "openai.com",
        "openai": "openai.com",

        // Learning
        "duolingo": "duolingo.com",
        "coursera": "coursera.org",
        "udemy": "udemy.com",
        "skillshare": "skillshare.com",
        "masterclass": "masterclass.com",
        "linkedin learning": "linkedin.com",

        // Gaming
        "playstation": "playstation.com",
        "ps plus": "playstation.com",
        "xbox": "xbox.com",
        "xbox game pass": "xbox.com",
        "nintendo": "nintendo.com",
        "steam": "steampowered.com",
        "epic games": "epicgames.com",

        // News/Reading
        "medium": "medium.com",
        "substack": "substack.com",
        "new york times": "nytimes.com",
        "nyt": "nytimes.com",
        "washington post": "washingtonpost.com",
        "wall street journal": "wsj.com",
        "wsj": "wsj.com",
        "kindle unlimited": "amazon.com",
        "audible": "audible.com",

        // Fitness
        "peloton": "onepeloton.com",
        "strava": "strava.com",
        "myfitnesspal": "myfitnesspal.com",
        "headspace": "headspace.com",
        "calm": "calm.com",

        // Cloud/Storage
        "aws": "aws.amazon.com",
        "amazon web services": "aws.amazon.com",
        "digitalocean": "digitalocean.com",
        "heroku": "heroku.com",
        "vercel": "vercel.com",
        "netlify": "netlify.com",

        // Other
        "patreon": "patreon.com",
        "twitch": "twitch.tv",
        "grammarly": "grammarly.com",
        "1password": "1password.com",
        "lastpass": "lastpass.com",
        "nordvpn": "nordvpn.com",
        "expressvpn": "expressvpn.com"
    ]

    // Get Clearbit logo URL for merchant
    private var logoURL: URL? {
        let merchantName = subscription.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchantName.isEmpty else {
            return nil
        }

        // Try hardcoded mapping first
        if let domain = Self.merchantDomains[merchantName] {
            return URL(string: "https://logo.clearbit.com/\(domain)")
        }

        // Auto-guess: convert merchant name to domain
        let guessedDomain = merchantName
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "+", with: "")
            + ".com"

        return URL(string: "https://logo.clearbit.com/\(guessedDomain)")
    }

    // Format primary amount (converted from subscription currency to user's primary currency)
    private var formattedPrimaryAmount: String {
        // Convert subscription amount to user's primary currency
        let convertedAmount = CurrencyRateManager.shared.convertAmount(
            abs(subscription.amount),
            from: subscription.currency,
            to: currencyPrefs.primaryCurrency
        )
        return currencyPrefs.formatPrimaryAmount(convertedAmount)
    }

    // Format original amount in subscription's currency (shown as secondary when different from primary)
    private var formattedSecondaryAmount: String? {
        guard subscription.currency != currencyPrefs.primaryCurrency else {
            return nil
        }
        // Show original amount in subscription's currency as reference
        return currencyPrefs.formatAmount(abs(subscription.amount), currency: subscription.currency)
    }

    // Human-readable renewal text (with minute precision for 5-minute frequency)
    // Takes currentDate parameter for real-time countdown support
    private func renewsText(from currentDate: Date) -> String {
        // For 5-minute frequency, show precise time with live countdown
        if subscription.frequency == .fiveMinutes {
            let seconds = Int(subscription.nextDueDate.timeIntervalSince(currentDate))
            if seconds <= 0 {
                return "Renews now"
            } else if seconds < 60 {
                return "Renews in \(seconds)s"
            } else {
                let minutes = Int(ceil(Double(seconds) / 60.0))
                return "Renews in \(minutes)m"
            }
        }

        // For other frequencies, show days
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: currentDate, to: subscription.nextDueDate)
        let days = max(0, components.day ?? 0)

        if days == 0 {
            return "Renews today"
        } else if days == 1 {
            return "Renews tomorrow"
        } else if days <= 7 {
            return "Renews in \(days) days"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Renews \(formatter.string(from: subscription.nextDueDate))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Logo or category icon
            if let url = logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .background(AppColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        TxnCategoryIcon(category: subscription.category, size: 44)
                    case .empty:
                        // Loading placeholder
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.surfacePrimary)
                            .frame(width: 44, height: 44)
                    @unknown default:
                        TxnCategoryIcon(category: subscription.category, size: 44)
                    }
                }
            } else {
                TxnCategoryIcon(category: subscription.category, size: 44)
            }

            // Subscription name + Frequency (grouped with 2px gap)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
                    .lineLimit(1)

                Text(subscription.frequency.displayName.uppercased())
                    .font(AppFonts.overusedGroteskSemiBold(size: 10))
                    .kerning(0.8)
                    .foregroundColor(AppColors.foregroundTertiary)
            }

            // Primary amount + secondary amount
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedPrimaryAmount)
                    .font(AppFonts.overusedGroteskMedium(size: 20))
                    .foregroundColor(AppColors.foregroundPrimary)

                if let secondary = formattedSecondaryAmount {
                    Text(secondary)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundTertiary)
                }
            }

            // "Renews in X days" / "Renews today" / "Renews tomorrow"
            // Use TimelineView for real-time countdown on 5-minute frequency
            if subscription.frequency == .fiveMinutes {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(renewsText(from: context.date))
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            } else {
                Text(renewsText(from: Date()))
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundWhite)
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.surfacePrimary.ignoresSafeArea()

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SubscriptionCard(
                subscription: Subscription(
                    name: "Spotify",
                    amount: 149,
                    currency: .php,
                    category: "Entertainment",
                    frequency: .monthly,
                    nextDueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!
                )
            )

            SubscriptionCard(
                subscription: Subscription(
                    name: "Netflix",
                    amount: 549,
                    currency: .php,
                    category: "Entertainment",
                    frequency: .monthly,
                    nextDueDate: Calendar.current.date(byAdding: .day, value: 12, to: Date())!
                )
            )

            SubscriptionCard(
                subscription: Subscription(
                    name: "iCloud Storage",
                    amount: 49,
                    currency: .php,
                    category: "Utilities",
                    frequency: .monthly,
                    nextDueDate: Calendar.current.date(byAdding: .day, value: 20, to: Date())!
                )
            )
        }
        .padding(20)
    }
}
