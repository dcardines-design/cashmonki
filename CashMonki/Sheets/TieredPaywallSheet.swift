//
//  TieredPaywallSheet.swift
//  CashMonki
//
//  Two-tier (Plus / Pro) paywall. Approved design: scratchpad paywall-mockup-v4.
//  Plan toggle + features table (values from PlanTier) + Yearly/Monthly price tiles
//  (prices from the `cashmonki-tiers` offering) + one CTA.
//

import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

// MARK: - Pricing model

/// One purchasable term (e.g. Pro yearly) with the numbers the tiles need.
/// Built from a RevenueCat package, or from DEBUG sample data.
struct TierPrice {
    let packageID: TierPackageID
    /// Store-formatted price, e.g. "$39.99".
    let localizedPrice: String
    let price: Decimal
    /// The product's own formatter, so derived amounts use the right currency/locale.
    let formatter: NumberFormatter?
    /// Free-trial length in days from the product's intro offer; nil when there is none.
    let trialDays: Int?

    var isYearly: Bool { packageID == .plusYearly || packageID == .proYearly }

    func format(_ amount: Decimal) -> String {
        if let formatter, let string = formatter.string(from: amount as NSDecimalNumber) { return string }
        return localizedPrice
    }

    /// Yearly → price per month; monthly → price per year.
    var secondaryAmount: String {
        isYearly ? format(price / 12) : format(price * 12)
    }

    #if canImport(RevenueCat)
    init(package: Package, id: TierPackageID) {
        let product = package.storeProduct
        packageID = id
        localizedPrice = product.localizedPriceString
        price = product.price
        formatter = product.priceFormatter
        if let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial {
            let period = intro.subscriptionPeriod
            switch period.unit {
            case .day: trialDays = period.value
            case .week: trialDays = period.value * 7
            case .month: trialDays = period.value * 30
            default: trialDays = nil
            }
        } else {
            trialDays = nil
        }
    }
    #endif

    init(packageID: TierPackageID, localizedPrice: String, price: Decimal, formatter: NumberFormatter?, trialDays: Int?) {
        self.packageID = packageID
        self.localizedPrice = localizedPrice
        self.price = price
        self.formatter = formatter
        self.trialDays = trialDays
    }

    /// Whole-percent saving of yearly vs 12 × monthly, rounded down so we never overclaim.
    static func savingsPercent(yearly: TierPrice, monthly: TierPrice) -> Int? {
        let fullYear = monthly.price * 12
        guard fullYear > 0, yearly.price < fullYear else { return nil }
        let ratio = NSDecimalNumber(decimal: 1 - yearly.price / fullYear).doubleValue
        let percent = Int((ratio * 100).rounded(.down))
        return percent > 0 ? percent : nil
    }
}

// MARK: - Sheet

struct TieredPaywallSheet: View {
    @Binding var isPresented: Bool
    var mode: PaywallMode = .default

    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTier: PlanTier = .pro
    @State private var yearlySelected = true
    @State private var loadState: LoadState = .loading
    @State private var proTrialEligible = true
    @State private var isPurchasing = false
    @State private var isDismissing = false
    @State private var showingManageBilling = false

    private enum LoadState { case loading, loaded, failed }

    private static let termsURL = URL(string: "https://cashmonki.app/terms")!
    private static let privacyURL = URL(string: "https://cashmonki.app/privacy")!

    // MARK: Derived state

    private var currentTier: PlanTier { revenueCatManager.planTier }
    /// Plus users always get the upgrade variant (Plus shown as their current plan, no trial).
    private var isUpgrade: Bool { mode == .upgrade || currentTier == .plus }

    private func price(_ id: TierPackageID) -> TierPrice? {
        #if DEBUG
        if let sample = Self.debugSamplePrices[id] { return sample }
        #endif
        #if canImport(RevenueCat)
        guard let package = revenueCatManager.tierPackage(id) else { return nil }
        return TierPrice(package: package, id: id)
        #else
        return nil
        #endif
    }

    private var yearlyID: TierPackageID { selectedTier == .plus ? .plusYearly : .proYearly }
    private var monthlyID: TierPackageID { selectedTier == .plus ? .plusMonthly : .proMonthly }
    private var selectedID: TierPackageID { yearlySelected ? yearlyID : monthlyID }
    private var selectedPrice: TierPrice? { price(selectedID) }

    /// Free trial applies only to Pro, for users StoreKit says are eligible, and never to an upgrade.
    private var showsTrial: Bool {
        selectedTier == .pro && !isUpgrade && proTrialEligible && selectedPrice?.trialDays != nil
    }

    private var trialDays: Int { selectedPrice?.trialDays ?? 7 }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // The limit headline carries an extra line, so tighten the gaps to keep
                    // everything on one 852pt screen.
                    let gap: CGFloat = isLimitMode ? 10 : 14
                    lockup
                        .padding(.top, isLimitMode ? 4 : 10)
                    headline
                        .padding(.top, isLimitMode ? 8 : 12)
                    PromptMarquee(animate: !reduceMotion)
                        .padding(.top, gap)
                    planToggle
                        .padding(.top, gap)
                    featuresTable
                        .padding(.top, gap)
                        .padding(.horizontal, 20)
                    priceTiles
                        .padding(.top, gap)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)

            bottomActions
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: selectedTier)
        .animation(.easeInOut(duration: 0.2), value: yearlySelected)
        .fullScreenCover(isPresented: $showingManageBilling) {
            ManageBillingSheet(isPresented: $showingManageBilling)
                .environmentObject(toastManager)
        }
        .onAppear {
            if isUpgrade { selectedTier = .pro }
            AnalyticsManager.shared.trackPaywallViewed(
                source: mode.analyticsSource,
                hasUsedTrial: revenueCatManager.hasUsedTrialBefore
            )
        }
        .task { await loadPrices() }
    }

    private var background: some View {
        ZStack {
            AppColors.backgroundSecondary
            LinearGradient(
                stops: [
                    .init(color: AppColors.accentBackground.opacity(0.10), location: 0),
                    .init(color: AppColors.accentBackground.opacity(0.04), location: 0.2),
                    .init(color: AppColors.accentBackground.opacity(0), location: 0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.foregroundPrimary.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppColors.backgroundWhite))
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            Button {
                restorePurchases()
            } label: {
                Text("Restore")
                    .font(AppFonts.overusedGroteskMedium(size: 15))
                    .foregroundColor(AppColors.foregroundPrimary.opacity(0.75))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Capsule().fill(AppColors.backgroundWhite))
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore Purchases")
        }
    }

    // MARK: Lockup + headline

    private var lockup: some View {
        HStack(spacing: 8) {
            Image("cashmonki-wordmark")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 18)
                .foregroundColor(AppColors.foregroundPrimary)
                .accessibilityLabel("Cashmonki")
            PlanBadge(tier: selectedTier, shine: !reduceMotion)
        }
    }

    private var headlineText: String {
        switch mode {
        case .limitHit(.ask):
            return "You've used today's\n\(currentTier.dailyAskLimit) Ask messages"
        case .limitHit(.scan):
            return "You've used today's\n\(currentTier.dailyScanLimit ?? PlanTier.freeDailyScanLimit) receipt scans"
        default:
            return isUpgrade ? "Upgrade to\nCashmonki Pro" : "Know where\nyour money goes"
        }
    }

    private var isLimitMode: Bool {
        if case .limitHit = mode { return true }
        return false
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(headlineText)
                .font(AppFonts.overusedGroteskMedium(size: 26))
                .foregroundColor(AppColors.foregroundPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            if isLimitMode {
                // DailyUsageManager resets Ask and scan counts at local midnight.
                HStack(spacing: 6) {
                    Circle().fill(AppColors.accentOrange).frame(width: 6, height: 6)
                    Text("Resets at midnight")
                        .font(AppFonts.overusedGroteskSemiBold(size: 14))
                        .foregroundColor(AppColors.accentOrange)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Plan toggle (TabChip, as in Feedback Inbox)

    private var planToggle: some View {
        HStack(spacing: 8) {
            TabChip.basic(title: isUpgrade ? "Plus · Current" : "Plus", isSelected: selectedTier == .plus) {
                selectedTier = .plus
            }
            .disabled(isUpgrade)
            .opacity(isUpgrade ? 0.5 : 1)

            TabChip.basic(title: "Pro", isSelected: selectedTier == .pro) {
                selectedTier = .pro
            }
        }
        .padding(6)
        .frame(width: isUpgrade ? 250 : 220)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
    }

    // MARK: Features table

    private enum Cell {
        case text(String)
        case check
        case dash
    }

    private struct FeatureRow: Identifiable {
        let id: String
        let label: String
        let free: Cell
        let plan: Cell
        let isHit: Bool
    }

    private func limitCell(_ value: Int?, perDay: Bool) -> Cell {
        guard let value else { return .text("Unlimited") }
        return .text(perDay ? "\(value)/day" : "\(value)")
    }

    private var featureRows: [FeatureRow] {
        let free = PlanTier.free
        let plan = selectedTier
        // The orange "you hit this" cell only makes sense when the user is on Free.
        let hitAsk = mode == .limitHit(.ask) && currentTier == .free
        let hitScan = mode == .limitHit(.scan) && currentTier == .free
        return [
            FeatureRow(id: "ask", label: "Ask messages",
                       free: limitCell(free.dailyAskLimit, perDay: true),
                       plan: limitCell(plan.dailyAskLimit, perDay: true), isHit: hitAsk),
            FeatureRow(id: "scan", label: "Receipt scans",
                       free: limitCell(free.dailyScanLimit, perDay: true),
                       plan: limitCell(plan.dailyScanLimit, perDay: true), isHit: hitScan),
            FeatureRow(id: "wallets", label: "Wallets",
                       free: limitCell(free.walletLimit, perDay: false),
                       plan: limitCell(plan.walletLimit, perDay: false), isHit: false),
            FeatureRow(id: "recurring", label: "Recurring",
                       free: limitCell(free.recurringLimit, perDay: false),
                       plan: limitCell(plan.recurringLimit, perDay: false), isHit: false),
            FeatureRow(id: "categories", label: "Custom categories",
                       free: free.allowsCustomCategories ? .check : .dash,
                       plan: plan.allowsCustomCategories ? .check : .dash, isHit: false)
        ]
    }

    private let valueColumnWidth: CGFloat = 96
    private var planTint: Color { AppColors.accentBackground.opacity(0.05) }

    private var featuresTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Features")
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .frame(width: valueColumnWidth)
                Text(selectedTier == .plus ? "Plus" : "Pro")
                    .foregroundColor(AppColors.accentBackground)
                    .frame(width: valueColumnWidth, height: 36)
                    .background(planTint)
            }
            .font(AppFonts.overusedGroteskSemiBold(size: 12))
            .foregroundColor(AppColors.foregroundSecondary)
            .frame(height: 36)

            ForEach(featureRows) { row in
                HStack(spacing: 0) {
                    Text(row.label)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundPrimary)
                        .padding(.leading, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    cellView(row.free, color: row.isHit ? AppColors.accentOrange : AppColors.foregroundTertiary)
                        .frame(width: valueColumnWidth, height: 44)
                        .background(row.isHit ? AppColors.accentOrange.opacity(0.08) : Color.clear)
                    cellView(row.plan, color: AppColors.accentBackground)
                        .frame(width: valueColumnWidth, height: 44)
                        .background(planTint)
                }
                .frame(height: 44)
                .overlay(alignment: .top) {
                    // Full-width divider, lighter where it crosses the plan column.
                    HStack(spacing: 0) {
                        Rectangle().fill(AppColors.surfacePrimary)
                        Rectangle().fill(AppColors.accentBackground.opacity(0.08))
                            .frame(width: valueColumnWidth)
                    }
                    .frame(height: 1)
                }
            }
        }
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.linePrimary, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func cellView(_ cell: Cell, color: Color) -> some View {
        switch cell {
        case .text(let value):
            Text(value)
                .font(AppFonts.overusedGroteskSemiBold(size: 14))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color == AppColors.foregroundTertiary ? AppColors.foregroundPrimary : color)
        case .dash:
            Text("–")
                .font(AppFonts.overusedGroteskSemiBold(size: 14))
                .foregroundColor(AppColors.foregroundTertiary)
        }
    }

    // MARK: Price tiles

    @ViewBuilder
    private var priceTiles: some View {
        if let yearly = price(yearlyID), let monthly = price(monthlyID) {
            HStack(spacing: 12) {
                priceTile(title: "Yearly", price: yearly, unit: "/yr",
                          secondary: "\(yearly.secondaryAmount)/mo",
                          savings: TierPrice.savingsPercent(yearly: yearly, monthly: monthly),
                          isSelected: yearlySelected) { yearlySelected = true }
                priceTile(title: "Monthly", price: monthly, unit: "/mo",
                          secondary: "\(monthly.secondaryAmount)/yr",
                          savings: nil,
                          isSelected: !yearlySelected) { yearlySelected = false }
            }
        } else if loadState == .failed {
            VStack(spacing: 8) {
                Text("Prices couldn't load. Check your connection.")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(AppColors.foregroundSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await loadPrices(force: true) } }
                    .font(AppFonts.overusedGroteskSemiBold(size: 14))
                    .foregroundColor(AppColors.accentBackground)
            }
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.backgroundWhite))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.linePrimary, lineWidth: 1))
        } else {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.backgroundWhite)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.linePrimary, lineWidth: 1))
                        .overlay(ProgressView().tint(AppColors.foregroundTertiary))
                        .frame(height: 86)
                }
            }
        }
    }

    private func priceTile(title: String, price: TierPrice, unit: String, secondary: String,
                           savings: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(AppFonts.overusedGroteskSemiBold(size: 14))
                        .foregroundColor(AppColors.foregroundPrimary)
                    if let savings {
                        Text("−\(savings)%")
                            .font(AppFonts.overusedGroteskBold(size: 12))
                            .foregroundColor(AppColors.successForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.successBackground))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price.localizedPrice)
                        .font(AppFonts.overusedGroteskBold(size: 22))
                        .foregroundColor(AppColors.foregroundPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(unit)
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
                Text(secondary)
                    .font(AppFonts.overusedGroteskMedium(size: 13))
                    .foregroundColor(AppColors.foregroundSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.backgroundWhite))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .inset(by: isSelected ? 0.75 : 0.5)
                    .stroke(isSelected ? AppColors.accentBackground : AppColors.linePrimary, lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppColors.accentBackground))
                        .overlay(Circle().stroke(AppColors.backgroundSecondary, lineWidth: 2))
                        .offset(x: 7, y: -7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Bottom actions

    private var ctaTitle: String {
        if isPurchasing { return "Processing..." }
        if currentTier == .pro { return "Manage Billing" }
        if isUpgrade { return "Upgrade to Pro" }
        if selectedTier == .plus { return "Get Cashmonki Plus" }
        return showsTrial ? "Start \(trialDays)-day free trial" : "Continue with Pro"
    }

    private var finePrint: String {
        guard let selected = selectedPrice else { return " " }
        if isUpgrade { return "Starts today. Apple credits unused Plus time. Auto-renews." }
        let period = selected.isYearly ? "year" : "month"
        if showsTrial {
            return "\(trialDays) days free, then \(selected.localizedPrice)/\(period). Auto-renews, cancel anytime."
        }
        return "\(selected.localizedPrice) billed \(selected.isYearly ? "yearly" : "monthly"). Auto-renews, cancel anytime."
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            AppButton(
                title: ctaTitle,
                action: {
                    guard !isPurchasing else { return }
                    if currentTier == .pro { showingManageBilling = true } else { purchaseSelected() }
                },
                hierarchy: .primary,
                size: .extraSmall,
                state: isPurchasing ? .pressed : .active,
                isEnabled: currentTier == .pro || selectedPrice != nil
            )

            Text(finePrint)
                .font(AppFonts.overusedGroteskMedium(size: 13))
                .foregroundColor(AppColors.foregroundSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .padding(.top, 4)

            HStack(spacing: 10) {
                Link("Terms", destination: Self.termsURL)
                Circle().fill(AppColors.foregroundTertiary).frame(width: 3, height: 3)
                Link("Privacy", destination: Self.privacyURL)
            }
            .font(AppFonts.overusedGroteskMedium(size: 13))
            .foregroundColor(AppColors.foregroundSecondary)
        }
    }

    // MARK: - Loading

    private func loadPrices(force: Bool = false) async {
        #if DEBUG
        if !Self.debugSamplePrices.isEmpty { loadState = .loaded; return }
        #endif
        if force || revenueCatManager.tiersOffering == nil {
            loadState = .loading
            await revenueCatManager.loadOfferings()
        }
        loadState = revenueCatManager.tiersOffering == nil ? .failed : .loaded
        #if canImport(RevenueCat)
        if let package = revenueCatManager.tierPackage(.proYearly) {
            proTrialEligible = await revenueCatManager.isTrialEligible(for: package)
        }
        #endif
    }

    // MARK: - Purchase (mirrors CustomPaywallSheet)

    private func purchaseSelected() {
        #if canImport(RevenueCat)
        let id = selectedID
        guard let package = revenueCatManager.tierPackage(id) else {
            toastManager.showSubscriptionError(message: "Plans aren't available right now. Please try again later.")
            return
        }
        isPurchasing = true
        Task {
            let result = await revenueCatManager.purchase(package: package)
            await MainActor.run {
                if result.success {
                    AnalyticsManager.shared.track(.subscriptionStarted, properties: [
                        "plan": id.rawValue.hasSuffix("yearly") ? "yearly" : "monthly",
                        "tier": id.tier.rawValue,
                        "price": package.storeProduct.localizedPriceString,
                        "paywall_source": mode.analyticsSource
                    ])
                    isDismissing = true
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                    }
                    return
                }
                guard let error = result.error else {
                    isPurchasing = false // user cancelled
                    return
                }
                let nsError = error as NSError
                let isUserCancellation = (nsError.domain == "SKErrorDomain" && nsError.code == 2) ||
                    (nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 1) ||
                    (nsError.domain == "SKErrorDomain" && nsError.code == 19) ||
                    error.localizedDescription.lowercased().contains("cancel")
                if isUserCancellation {
                    isPurchasing = false
                    return
                }
                let message = (nsError.domain == "RevenueCat.ErrorDomain" && nsError.code == 10)
                    ? "Network error. Please check your connection and try again."
                    : "Something went wrong with your subscription. Please try again later."
                isDismissing = true
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .subscriptionFailed, object: nil,
                                                    userInfo: ["errorMessage": message])
                }
            }
        }
        #endif
    }

    private func restorePurchases() {
        #if canImport(RevenueCat)
        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                let hasActiveEntitlements = !customerInfo.entitlements.active.isEmpty
                await revenueCatManager.forceRefreshCustomerInfo()
                await MainActor.run {
                    if hasActiveEntitlements {
                        isDismissing = true
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: .subscriptionSucceeded, object: nil)
                        }
                    } else {
                        toastManager.showSubscriptionError(message: "No previous purchases found")
                    }
                }
            } catch {
                await MainActor.run {
                    toastManager.showSubscriptionError(message: "Restore failed. Please try again.")
                }
            }
        }
        #endif
    }

    // MARK: - DEBUG sample prices

    #if DEBUG
    /// `-paywallSamplePrices YES`: fixed USD prices so the layout can be checked when the
    /// `cashmonki-tiers` offering isn't available (simulator / before App Store Connect setup).
    static var debugSamplePrices: [TierPackageID: TierPrice] {
        guard UserDefaults.standard.bool(forKey: "paywallSamplePrices") else { return [:] }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        func make(_ id: TierPackageID, _ value: String, trial: Int?) -> TierPrice {
            let decimal = Decimal(string: value)!
            return TierPrice(packageID: id, localizedPrice: formatter.string(from: decimal as NSDecimalNumber)!,
                             price: decimal, formatter: formatter, trialDays: trial)
        }
        return [
            .plusMonthly: make(.plusMonthly, "2.99", trial: nil),
            .plusYearly: make(.plusYearly, "19.99", trial: nil),
            .proMonthly: make(.proMonthly, "6.99", trial: 7),
            .proYearly: make(.proYearly, "39.99", trial: 7)
        ]
    }
    #endif
}

// MARK: - PRO / PLUS badge

/// Gradient plan badge with a hard 2pt shadow and a periodic shine (off with Reduce Motion).
private struct PlanBadge: View {
    let tier: PlanTier
    let shine: Bool

    @State private var shinePhase: CGFloat = -1

    private var colors: [Color] {
        tier == .plus
            ? [Color(hex: "2F6BFF") ?? .blue, Color(hex: "1FA7E8") ?? .blue, Color(hex: "22C3A6") ?? .green]
            : [Color(hex: "542EFF") ?? .purple, Color(hex: "9B3CFF") ?? .purple, Color(hex: "E15BD8") ?? .pink]
    }

    private var edgeColor: Color {
        tier == .plus ? (Color(hex: "0F5FC2") ?? .blue) : (Color(hex: "2C06D7") ?? .purple)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text(tier == .plus ? "PLUS" : "PRO")
            .font(AppFonts.overusedGroteskBold(size: 13))
            .tracking(1.2)
            .foregroundColor(.white)
            .padding(.leading, 8)
            .padding(.trailing, 6.8)
            .padding(.vertical, 3)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.45)
                        .rotationEffect(.degrees(20))
                        .offset(x: shinePhase * proxy.size.width * 1.4)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .allowsHitTesting(false)
            }
            .clipShape(shape)
            .overlay(shape.stroke(edgeColor, lineWidth: 1))
            .background(shape.fill(edgeColor).offset(y: 2))
            .padding(.bottom, 2)
            .animation(.easeInOut(duration: 0.2), value: tier)
            .task(id: shine) {
                guard shine else { shinePhase = -1; return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_700_000_000)
                    if Task.isCancelled { break }
                    withAnimation(.easeInOut(duration: 0.5)) { shinePhase = 1 }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { shinePhase = -1 }
                }
            }
            .accessibilityLabel(tier == .plus ? "Plus" : "Pro")
    }
}

// MARK: - Prompt marquee

/// Example Ask prompts scrolling slowly, edges faded. Static when Reduce Motion is on.
private struct PromptMarquee: View {
    let animate: Bool

    private static let prompts: [(String, String)] = [
        ("💬", "How much on food this month?"),
        ("☕", "Coffee 4.50"),
        ("📊", "Compare to last month"),
        ("🧾", "Scan a receipt"),
        ("🛒", "45 groceries and 6 for milk")
    ]

    @State private var contentWidth: CGFloat = 0
    private let speed: CGFloat = 22 // points per second

    var body: some View {
        // The strip lives in an overlay so its (very wide) content never widens the layout.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .overlay(alignment: .leading) {
                TimelineView(.animation(paused: !animate || contentWidth == 0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let offset = (animate && contentWidth > 0)
                        ? -CGFloat(t * Double(speed)).truncatingRemainder(dividingBy: contentWidth)
                        : 0
                    HStack(spacing: 8) {
                        row
                        row
                    }
                    .fixedSize()
                    .offset(x: offset + 12)
                }
            }
            .clipped()
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        )
        .accessibilityHidden(true)
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(Self.prompts, id: \.1) { emoji, text in
                HStack(spacing: 6) {
                    Text(emoji).font(.system(size: 14))
                    Text(text)
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(AppColors.foregroundPrimary.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(AppColors.backgroundWhite))
                .overlay(Capsule().stroke(AppColors.surfaceSecondary, lineWidth: 1))
                .fixedSize()
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { contentWidth = proxy.size.width + 8 }
            }
        )
    }
}

#Preview {
    TieredPaywallSheet(isPresented: .constant(true))
        .environmentObject(ToastManager())
}
