//
//  RecurringTransactionCard.swift
//  CashMonki
//
//  Card component for displaying recurring transactions in a grid
//

import SwiftUI

struct RecurringTransactionCard: View {
    let transaction: Txn
    let onTap: (() -> Void)?

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared

    init(transaction: Txn, onTap: (() -> Void)? = nil) {
        self.transaction = transaction
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
        guard let merchantName = transaction.merchantName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !merchantName.isEmpty else {
            print("🖼️ Clearbit: No merchant name, using category icon")
            return nil
        }

        // Try hardcoded mapping first
        if let domain = Self.merchantDomains[merchantName] {
            print("🖼️ Clearbit: '\(merchantName)' → hardcoded domain '\(domain)'")
            return URL(string: "https://logo.clearbit.com/\(domain)")
        }

        // Auto-guess: convert merchant name to domain
        let guessedDomain = merchantName
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "+", with: "")
            + ".com"

        print("🖼️ Clearbit: '\(merchantName)' → auto-guessed domain '\(guessedDomain)'")
        return URL(string: "https://logo.clearbit.com/\(guessedDomain)")
    }

    // Calculate time until next renewal
    private func timeUntilRenewal(from currentDate: Date) -> (value: Int, unit: String) {
        guard let frequency = transaction.recurringFrequency else { return (0, "days") }

        // Use lastGeneratedDate if available, otherwise use transaction date
        let baseDate = transaction.lastGeneratedDate ?? transaction.date

        // Find the next occurrence that's in the future
        var nextDate = frequency.nextOccurrence(from: baseDate)
        while nextDate <= currentDate {
            nextDate = frequency.nextOccurrence(from: nextDate)
        }

        // For 5-minute frequency, show seconds (live countdown)
        if frequency == .fiveMinutes {
            let seconds = Calendar.current.dateComponents([.second], from: currentDate, to: nextDate).second ?? 0
            return (max(0, seconds), seconds == 1 ? "second" : "seconds")
        }

        // For other frequencies, show days
        let days = Calendar.current.dateComponents([.day], from: currentDate, to: nextDate).day ?? 0
        return (max(0, days), days == 1 ? "day" : "days")
    }

    // Format primary amount
    private var formattedPrimaryAmount: String {
        currencyPrefs.formatPrimaryAmount(abs(transaction.amount))
    }

    // Format secondary amount if different currency
    private var formattedSecondaryAmount: String? {
        guard let originalAmount = transaction.originalAmount,
              let originalCurrency = transaction.originalCurrency,
              originalCurrency != currencyPrefs.primaryCurrency else {
            return nil
        }
        return currencyPrefs.formatAmount(abs(originalAmount), currency: originalCurrency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Logo or category icon
            if let url = logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        let _ = print("🖼️ Clearbit: ✅ Logo loaded for '\(transaction.merchantName ?? "unknown")'")
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .background(AppColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        let _ = print("🖼️ Clearbit: ❌ Failed to load logo for '\(transaction.merchantName ?? "unknown")', using category icon")
                        TxnCategoryIcon(category: transaction.category, size: 44)
                    case .empty:
                        // Loading placeholder
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.surfacePrimary)
                            .frame(width: 44, height: 44)
                    @unknown default:
                        TxnCategoryIcon(category: transaction.category, size: 44)
                    }
                }
            } else {
                TxnCategoryIcon(category: transaction.category, size: 44)
            }

            // Merchant name + Frequency (grouped with 2px gap)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.category)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
                    .lineLimit(1)

                Text(transaction.recurringFrequency?.displayName.uppercased() ?? "MONTHLY")
                    .font(AppFonts.overusedGroteskSemiBold(size: 10))
                    .kerning(0.8)
                    .foregroundColor(AppColors.foregroundSecondary)
            }

            // Primary amount + secondary amount
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedPrimaryAmount)
                    .font(AppFonts.overusedGroteskMedium(size: 20))
                    .foregroundColor(AppColors.foregroundPrimary)

                if let secondary = formattedSecondaryAmount {
                    Text(secondary)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }

            // "Renews in X days/seconds" - live countdown for 5-minute frequency
            if transaction.recurringFrequency == .fiveMinutes {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let renewal = timeUntilRenewal(from: context.date)
                    HStack(spacing: 4) {
                        Text("Renews in")
                            .foregroundColor(AppColors.foregroundTertiary)
                        Text("\(renewal.value) \(renewal.unit)")
                            .foregroundColor(renewal.value <= 7 ? AppColors.foregroundSecondary : AppColors.foregroundTertiary)
                    }
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                }
            } else {
                let renewal = timeUntilRenewal(from: Date())
                HStack(spacing: 4) {
                    Text("Renews in")
                        .foregroundColor(AppColors.foregroundTertiary)
                    Text("\(renewal.value) \(renewal.unit)")
                        .foregroundColor(renewal.value <= 7 ? AppColors.foregroundSecondary : AppColors.foregroundTertiary)
                }
                .font(AppFonts.overusedGroteskMedium(size: 14))
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
            RecurringTransactionCard(
                transaction: Txn(
                    txID: UUID(),
                    accountID: UUID(),
                    walletID: nil,
                    category: "Subscriptions",
                    categoryId: nil,
                    amount: -588.79,
                    date: Date(),
                    createdAt: Date(),
                    receiptImage: nil,
                    hasReceiptImage: false,
                    merchantName: "Spotify",
                    paymentMethod: nil,
                    receiptNumber: nil,
                    invoiceNumber: nil,
                    items: [],
                    note: nil,
                    originalAmount: -10.0,
                    originalCurrency: .usd,
                    primaryCurrency: .php,
                    secondaryCurrency: nil,
                    exchangeRate: nil,
                    secondaryAmount: nil,
                    secondaryExchangeRate: nil,
                    userEnteredAmount: nil,
                    userEnteredCurrency: nil,
                    isRecurring: true,
                    recurringFrequency: .monthly,
                    recurringTemplateId: nil,
                    lastGeneratedDate: nil,
                    isRecurringActive: true
                )
            )

            RecurringTransactionCard(
                transaction: Txn(
                    txID: UUID(),
                    accountID: UUID(),
                    walletID: nil,
                    category: "Subscriptions",
                    categoryId: nil,
                    amount: -3490.23,
                    date: Calendar.current.date(byAdding: .day, value: -360, to: Date()) ?? Date(),
                    createdAt: Date(),
                    receiptImage: nil,
                    hasReceiptImage: false,
                    merchantName: "Adobe Suite",
                    paymentMethod: nil,
                    receiptNumber: nil,
                    invoiceNumber: nil,
                    items: [],
                    note: nil,
                    originalAmount: -60.0,
                    originalCurrency: .usd,
                    primaryCurrency: .php,
                    secondaryCurrency: nil,
                    exchangeRate: nil,
                    secondaryAmount: nil,
                    secondaryExchangeRate: nil,
                    userEnteredAmount: nil,
                    userEnteredCurrency: nil,
                    isRecurring: true,
                    recurringFrequency: .yearly,
                    recurringTemplateId: nil,
                    lastGeneratedDate: nil,
                    isRecurringActive: true
                )
            )
        }
        .padding(20)
    }
}
