//
//  AskPage.swift
//  CashMonki
//
//  "Ask" tab — AI chat (Figma 1635-6605). Messages are structured
//  (AskMessageSchema): plain text, data tables (rows always from real local
//  data via AskChatService's tool layer), and transaction drafts. A draft
//  renders as the compact add-tile from Figma 1639-7891; tapping + expands an
//  editable confirmation card. The transaction is written ONLY on Confirm.
//

import SwiftUI
import UIKit

// MARK: - Display model

struct AskDisplayMessage: Identifiable, Codable {
    enum Content: Codable {
        case text(String)
        /// App-authored outcome line (e.g. "✅ Added…", "🗑️ Deleted…"). Looks
        /// identical to `.text` in the UI but is described to the model as a
        /// completed app action in history, so the model can't echo it to fake
        /// a save. Never used for model replies.
        case systemNote(String)
        case table(AskTableMessage)
        case draft(AskTransactionDraft)
        case update(AskTransactionUpdate)
        case single(AskTransactionRef)
        case deleteRequest(AskTransactionDelete)
        case chart(AskChartMessage)
        case stat(AskStatMessage)
        case question(String, [String])
        case categoryDraft(AskCategoryDraft)
    }

    let id: UUID
    let isUser: Bool
    var content: Content

    init(id: UUID = UUID(), isUser: Bool, content: Content) {
        self.id = id
        self.isUser = isUser
        self.content = content
    }

    /// App-side record of a past turn, sent back to the model as conversation
    /// history. Non-text turns are described as UI the APP already rendered — in
    /// parentheses, past tense — so the model never mistakes them for a reply
    /// template and echoes them back verbatim (see the systemPrompt rule).
    var historyText: String {
        switch content {
        case .text(let text): return text
        case .systemNote(let text): return "(App completed and recorded an action the user approved: \"\(text)\". You did not do this — never repeat or claim it.)"
        case .table(let table): return "(App rendered a data table titled \"\(table.title)\".)"
        case .draft(let draft): return "(App rendered a transaction confirmation card for \(draft.amount) \(draft.currency ?? "") \(draft.merchant ?? ""), awaiting the user's Confirm.)"
        case .update(let update): return "(App rendered an edit-confirmation card for transactions \(update.ids.joined(separator: ", ")).)"
        case .single(let ref): return "(App rendered transaction cards: \(ref.ids.joined(separator: ", ")).)"
        case .deleteRequest(let delete): return "(App rendered a delete-confirmation card for transactions \(delete.ids.joined(separator: ", ")).)"
        case .chart(let chart): return "(App rendered a chart titled \"\(chart.title)\".)"
        case .stat(let stat): return "(App rendered a stat: \(stat.title) = \(stat.value).)"
        case .question(let text, _): return text
        case .categoryDraft(let draft): return "(App rendered a new-category confirmation card for \"\(draft.name)\".)"
        }
    }
}

// MARK: - Chat manager

@MainActor
final class AskChatManager: ObservableObject {
    static let shared = AskChatManager()

    @Published var messages: [AskDisplayMessage] = []
    @Published var isThinking = false
    /// Draft lifecycle: message id → state.
    @Published var confirmedDrafts: Set<UUID> = []
    @Published var draftErrors: [UUID: String] = [:]
    /// Transaction opened in ReceiptDetailSheet from a chat card.
    @Published var detailTransaction: Txn? = nil

    /// Message currently receiving streamed text, if any.
    @Published private(set) var streamingMessageID: UUID? = nil

    /// Shown (ephemerally) when a free user hits the daily message limit. Never persisted —
    /// it reflects live daily state, so a stale copy must not survive into the next day's reset.
    static let limitMessageText = "You've used today's free messages. Upgrade to Pro for unlimited Ask, or come back tomorrow."

    private static func isLimitNotice(_ m: AskDisplayMessage) -> Bool {
        if case .text(let t) = m.content { return t == limitMessageText }
        return false
    }

    private init() {
        Self.migrateLegacyFileIfNeeded()
        if let saved = Self.loadPersisted() {
            // Drop any limit notices persisted by older builds — they're daily-state, not history.
            messages = saved.messages.filter { !Self.isLimitNotice($0) }
            confirmedDrafts = Set(saved.confirmed)
        }
        // Follow the login the same way app data does: when a user signs in / the session
        // finishes loading, swap to that user's chat (local + cloud), and clear on sign-out.
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleUserChanged),
            name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)
    }

    @objc private func handleUserChanged() {
        reloadForCurrentUser()
    }

    // MARK: Persistence — per-user local file + cloud mirror (same model as transactions/wallets)

    private struct PersistedChat: Codable {
        let messages: [AskDisplayMessage]
        let confirmed: [UUID]
    }

    /// Identity that owns the chat — resolved exactly like UserManager's storage key so the chat
    /// follows the same account/guest the rest of the app data does.
    private static func currentUID() -> String {
        AuthenticationManager.shared.currentUser?.firebaseUID
            ?? UserDefaults.standard.string(forKey: "last_authenticated_firebase_uid")
            ?? "guest"
    }

    private static func chatFileURL(for uid: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ask_chat_\(uid).json")
    }

    private static var legacyURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ask_chat_v1.json")
    }

    /// One-time move of the old shared file into the current user's per-user file, so existing
    /// on-device chat isn't lost when we switch to per-user keying. The shared file is a
    /// cross-user leak, so it is removed after the copy.
    private static func migrateLegacyFileIfNeeded() {
        let legacy = legacyURL
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        let dest = chatFileURL(for: currentUID())
        if !FileManager.default.fileExists(atPath: dest.path),
           let data = try? Data(contentsOf: legacy) {
            try? data.write(to: dest, options: .atomic)
        }
        try? FileManager.default.removeItem(at: legacy)
    }

    private var syncEnabled: Bool { UserManager.shared.currentUser.enableFirebaseSync }

    private func persist() {
        let snapshot = PersistedChat(messages: Array(messages.suffix(100)).filter { !Self.isLimitNotice($0) }, confirmed: Array(confirmedDrafts))
        let uid = Self.currentUID()
        let url = Self.chatFileURL(for: uid)
        let pushToCloud = syncEnabled
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
            if pushToCloud {
                FirestoreService.shared.saveAskChat(data, userId: uid) { _ in }
            }
        }
    }

    private static func loadPersisted() -> PersistedChat? {
        guard let data = try? Data(contentsOf: chatFileURL(for: currentUID())) else { return nil }
        return try? JSONDecoder().decode(PersistedChat.self, from: data)
    }

    /// Swap the in-memory chat to the current identity's: load its local file, then merge the
    /// cloud copy (returning user on a fresh install). Called on login/logout via notification.
    func reloadForCurrentUser() {
        let uid = Self.currentUID()
        let local = Self.loadPersisted()
        messages = (local?.messages ?? []).filter { !Self.isLimitNotice($0) }
        confirmedDrafts = Set(local?.confirmed ?? [])
        objectWillChange.send()

        guard syncEnabled else { return }
        FirestoreService.shared.fetchAskChat(userId: uid) { [weak self] result in
            guard let self = self,
                  case .success(let data?) = result,
                  let cloud = try? JSONDecoder().decode(PersistedChat.self, from: data) else { return }
            Task { @MainActor in
                self.mergeCloud(cloud)
            }
        }
    }

    /// Union local + cloud chat by message id. No per-message timestamp exists, so the longer
    /// snapshot is treated as the base (usually the more complete history) and any messages the
    /// other side uniquely has are appended. Capped at 100.
    private func mergeCloud(_ cloud: PersistedChat) {
        let cloudMsgs = cloud.messages.filter { !Self.isLimitNotice($0) }
        let base = cloudMsgs.count > messages.count ? cloudMsgs : messages
        let other = cloudMsgs.count > messages.count ? messages : cloudMsgs
        let baseIDs = Set(base.map { $0.id })
        var merged = base
        merged.append(contentsOf: other.filter { !baseIDs.contains($0.id) })
        messages = Array(merged.suffix(100))
        confirmedDrafts.formUnion(cloud.confirmed)
        objectWillChange.send()
        persist()
    }

    /// Presents the paywall when a free user hits the daily message limit.
    @Published var showLimitPaywall = false

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        guard DailyUsageManager.shared.canSendChatMessage() else {
            messages.append(AskDisplayMessage(isUser: false, content: .text(Self.limitMessageText)))
            showLimitPaywall = true
            return
        }
        DailyUsageManager.shared.recordChatMessage()

        messages.append(AskDisplayMessage(isUser: true, content: .text(trimmed)))
        isThinking = true

        persist()

        // Cap context: only the last 20 messages go to the model.
        let history = messages.suffix(20).map { (isUser: $0.isUser, text: $0.historyText) }
        Task {
            do {
                let reply = try await AskChatService.shared.send(
                    history: history,
                    onDelta: { delta in
                        Task { @MainActor in self.handleStreamDelta(delta) }
                    },
                    onStreamReset: {
                        Task { @MainActor in self.handleStreamReset() }
                    }
                )
                await MainActor.run { self.finish(with: reply) }
            } catch {
                await MainActor.run {
                    self.isThinking = false
                    self.wordQueue = []
                    self.rawPending = ""
                    self.pendingFinalText = nil
                    self.removeStreamingMessage()
                    self.messages.append(AskDisplayMessage(isUser: false, content: .text("⚠️ \(error.localizedDescription)")))
                    self.persist()
                }
            }
        }
    }

    // MARK: Streaming handlers (words drain one by one for the typing feel)

    private var wordQueue: [String] = []
    private var rawPending = ""
    private var isDraining = false
    private var pendingFinalText: String? = nil

    private func handleStreamDelta(_ delta: String) {
        // Deltas can split words mid-token; only queue completed words.
        rawPending += delta
        while let spaceIndex = rawPending.firstIndex(of: " ") {
            wordQueue.append(String(rawPending[...spaceIndex]))
            rawPending.removeSubrange(...spaceIndex)
        }
        drainQueue()
    }

    private func drainQueue() {
        guard !isDraining else { return }
        isDraining = true
        Task { @MainActor in
            while !wordQueue.isEmpty {
                appendToken(wordQueue.removeFirst())
                try? await Task.sleep(nanoseconds: 60_000_000) // one word per 60ms
            }
            isDraining = false
            if let final = pendingFinalText {
                pendingFinalText = nil
                settleStreamedText(final)
            }
        }
    }

    private func appendToken(_ token: String) {
        if let id = streamingMessageID, let index = messages.firstIndex(where: { $0.id == id }) {
            if case .text(let current) = messages[index].content {
                messages[index].content = .text(current + token)
            }
        } else {
            isThinking = false
            let message = AskDisplayMessage(isUser: false, content: .text(token))
            streamingMessageID = message.id
            messages.append(message)
        }
    }

    private func settleStreamedText(_ cleaned: String) {
        if let id = streamingMessageID, let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].content = .text(cleaned)
        } else {
            messages.append(AskDisplayMessage(isUser: false, content: .text(cleaned)))
        }
        streamingMessageID = nil
        persist()
    }

    private func handleStreamReset() {
        wordQueue = []
        rawPending = ""
        pendingFinalText = nil
        removeStreamingMessage()
        isThinking = true
    }

    private func removeStreamingMessage() {
        if let id = streamingMessageID {
            messages.removeAll { $0.id == id }
        }
        streamingMessageID = nil
    }

    private func finish(with reply: AskStructuredMessage) {
        isThinking = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch reply {
        case .text(let text):
            // House style: no em dashes in assistant replies.
            let cleaned = text
                .replacingOccurrences(of: " — ", with: ", ")
                .replacingOccurrences(of: "—", with: ", ")
            if !rawPending.isEmpty { wordQueue.append(rawPending); rawPending = "" }
            if isDraining || !wordQueue.isEmpty {
                pendingFinalText = cleaned // settle after the last word lands
                drainQueue()
                return
            }
            settleStreamedText(cleaned)
            persist()
            return
        case .table(let table):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .table(table)))
        case .transactionDraft(let draft):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .draft(draft)))
        case .transactionUpdate(let update):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .update(update)))
        case .transaction(let ref):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .single(ref)))
        case .transactionDelete(let delete):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .deleteRequest(delete)))
        case .chart(let chart):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .chart(chart)))
        case .stat(let stat):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .stat(stat)))
        case .question(let text, let choices):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .question(text, choices)))
        case .categoryDraft(let draft):
            removeStreamingMessage()
            messages.append(AskDisplayMessage(isUser: false, content: .categoryDraft(draft)))
        }
        streamingMessageID = nil
        persist()
    }

    /// Writes the transaction with whatever the user confirmed. Only called
    /// from the draft card's Confirm button — never by the model.
    func confirmDraft(messageID: UUID, amount: Double, currency: Currency, merchant: String?, date: Date, note: String?, categoryId: UUID?, categoryName: String) {
        guard amount > 0 else {
            draftErrors[messageID] = "Enter a valid amount."
            return
        }
        AskChatService.shared.createTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            date: date,
            note: note,
            categoryId: categoryId
        )
        draftErrors[messageID] = nil
        confirmedDrafts.insert(messageID)
        let formatted = AskFormat.currency(amount, code: currency.rawValue)
        messages.append(AskDisplayMessage(isUser: false, content: .systemNote("✅ Added \(formatted)\(categoryName.isEmpty ? "" : " to \(categoryName)").")))
        persist()
    }

    func cancelDraft(messageID: UUID) {
        confirmedDrafts.insert(messageID) // collapses the card; no write
        messages.append(AskDisplayMessage(isUser: false, content: .text("Okay, I won't add it.")))
        persist()
    }

    /// Applies a confirmed edit to one or more transactions (Confirm tap only).
    func confirmUpdate(messageID: UUID, update: AskTransactionUpdate) {
        let currency = update.currency.flatMap { code in
            Currency.allCases.first { $0.rawValue.uppercased() == code.uppercased() }
        }
        let date: Date? = update.date.flatMap {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: $0)
        }

        var updatedCount = 0
        for id in update.ids {
            guard let txID = UUID(uuidString: id) else { continue }
            if AskChatService.shared.updateTransaction(
                txID: txID,
                amount: update.amount,
                currency: currency,
                merchant: update.merchant,
                date: date,
                note: update.note,
                categoryId: update.category_id.flatMap { UUID(uuidString: $0) }
            ) {
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            draftErrors[messageID] = nil
            confirmedDrafts.insert(messageID) // card itself shows the updated state
        } else {
            draftErrors[messageID] = "Those transactions no longer exist."
        }
        persist()
    }

    /// Deletes the confirmed transactions (Delete tap only).
    func confirmDelete(messageID: UUID, delete: AskTransactionDelete) {
        var deleted = 0
        for id in delete.ids {
            guard let txID = UUID(uuidString: id),
                  UserManager.shared.currentUser.transactions.contains(where: { $0.txID == txID })
            else { continue }
            UserManager.shared.removeTransaction(withId: txID)
            deleted += 1
        }
        if deleted > 0 {
            draftErrors[messageID] = nil
            confirmedDrafts.insert(messageID)
            messages.append(AskDisplayMessage(isUser: false, content: .systemNote(deleted > 1 ? "🗑️ Deleted \(deleted) transactions." : "🗑️ Transaction deleted.")))
        } else {
            draftErrors[messageID] = "Those transactions no longer exist."
        }
        persist()
    }

    func cancelDelete(messageID: UUID) {
        confirmedDrafts.insert(messageID)
        messages.append(AskDisplayMessage(isUser: false, content: .text("Okay, nothing deleted.")))
        persist()
    }

    /// Creates the suggested category (Confirm tap only). Category creation
    /// is a Pro feature — free users get the paywall instead.
    func confirmCategoryDraft(messageID: UUID, draft: AskCategoryDraft) {
        guard RevenueCatManager.shared.isProUser else {
            showLimitPaywall = true
            return
        }
        let type: CategoryType = (draft.category_type?.lowercased() == "income") ? .income : .expense
        let success = CategoriesManager.shared.addCategory(
            name: draft.name,
            emoji: draft.emoji ?? "📁",
            parentCategory: draft.parent,
            targetType: type
        )
        if success {
            draftErrors[messageID] = nil
            confirmedDrafts.insert(messageID)
            let label = draft.parent.map { "subcategory under \($0)" } ?? "category"
            messages.append(AskDisplayMessage(isUser: false, content: .systemNote("✅ Added \(draft.emoji ?? "") \(draft.name) as a new \(label).")))
        } else {
            draftErrors[messageID] = "That category couldn't be created."
        }
        persist()
    }

    func cancelCategoryDraft(messageID: UUID) {
        confirmedDrafts.insert(messageID)
        messages.append(AskDisplayMessage(isUser: false, content: .text("Okay, no new category.")))
        persist()
    }

    func cancelUpdate(messageID: UUID) {
        confirmedDrafts.insert(messageID)
        messages.append(AskDisplayMessage(isUser: false, content: .text("Okay, no changes made.")))
        persist()
    }
}

// MARK: - Formatting helpers

enum AskFormat {
    /// Smart currency formatting per app rules: hide .00, show .01, group thousands.
    static func currency(_ value: Double, code: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        if let code, !code.isEmpty { return "\(code) \(number)" }
        return number
    }

    /// Currency with the user's primary symbol ("₱1,300") for chart/table cells.
    static func currencyWithSymbol(_ value: Double) -> String {
        CurrencyPreferences.shared.primaryCurrency.symbol + currency(value)
    }

    /// Inline markdown (**bold**, *italic*) with plain-text fallback.
    /// Presentation intents don't auto-style custom fonts in SwiftUI, so the
    /// bold/italic runs get explicit Overused Grotesk faces.
    static func markdown(_ text: String) -> AttributedString {
        guard var attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else { return AttributedString(text) }

        for run in attributed.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.stronglyEmphasized) {
                attributed[run.range].font = AppFonts.overusedGroteskSemiBold(size: 16)
            } else if intent.contains(.emphasized) {
                attributed[run.range].font = AppFonts.overusedGroteskMedium(size: 16).italic()
            }
        }
        return attributed
    }

    /// Hide a trailing *dangling* markdown marker mid-stream so "**partial" doesn't flash the
    /// raw asterisks before its closer streams in. Balanced markers render normally (live bold/italic).
    static func sanitizedStreaming(_ text: String) -> String {
        var s = text
        // Odd number of ** → the last one is an unclosed open marker; drop it.
        if (s.components(separatedBy: "**").count - 1) % 2 == 1,
           let r = s.range(of: "**", options: .backwards) {
            s.removeSubrange(r)
        }
        // Same for single-* italic (ignoring the *s inside remaining ** pairs).
        if (s.replacingOccurrences(of: "**", with: "").components(separatedBy: "*").count - 1) % 2 == 1,
           let r = s.range(of: "*", options: .backwards) {
            s.removeSubrange(r)
        }
        return s
    }
}

// MARK: - Page

struct AskPage: View {
    @ObservedObject private var chat = AskChatManager.shared
    @State private var composeText: String = ""
    @State private var showScrollToBottom = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        // Composer floats above the thread; messages scroll behind it.
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                if chat.messages.isEmpty {
                    // Empty-state hero (centered greeting, per mock)
                    VStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Text("👋 Hey \(heroName)")
                                .font(AppFonts.overusedGroteskMedium(size: 30))
                                .foregroundColor(AppColors.foregroundPrimary)
                            Text("Wanna’ know anything about your finances?")
                                .font(AppFonts.overusedGroteskMedium(size: 16))
                                .foregroundColor(AppColors.foregroundSecondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        Spacer()
                        Spacer() // biased above the composer
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { composerFocused = false }
                } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(chat.messages) { message in
                            AskMessageView(message: message)
                                .id(message.id)
                                .transition(.opacity)
                        }
                        if chat.isThinking {
                            AskThinkingDots()
                                .transition(.opacity)
                        }

                    }
                    .animation(.easeOut(duration: 0.18), value: chat.messages.count)
                    .animation(.easeOut(duration: 0.15), value: chat.isThinking)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Clearance for the floating composer; scrolling to this
                    // marker keeps the last message visible above it.
                    Color.clear
                        .frame(height: 180)
                        .id("bottomAnchor")
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: chat.messages.count) { _, _ in
                    // Defer one runloop so the new message is laid out, then ease down.
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chat.isThinking) { _, thinking in
                    guard thinking else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Land at the latest message when the Ask tab opens.
                    DispatchQueue.main.async {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture { composerFocused = false }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y, 0)
                } action: { _, distance in
                    showScrollToBottom = distance > 240
                }
                }

            VStack(spacing: 0) {
                // Starter chips above the input, horizontally scrollable
                if chat.messages.isEmpty && !chat.isThinking {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            starterChip("📊 Show my recent transactions")
                            starterChip("💸 What did I spend this month?")
                            starterChip("📈 Chart my spending this month")
                            starterChip("➕ Add 120 for lunch at Jollibee")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4) // room for the hard shadow
                    }
                    .padding(.bottom, 12) // gap between chips and the input
                    .transition(.opacity)
                }

                composerBar

                // Disclaimer + free-tier counter (Figma 1643-8075)
                VStack(spacing: 2) {
                    Text("AI can make mistakes. Please double-check responses.")
                    let remainingText = DailyUsageManager.shared.getChatUsageDisplayText()
                    if !remainingText.isEmpty {
                        Text(remainingText)
                    }
                }
                .font(AppFonts.overusedGroteskMedium(size: 10))
                .foregroundColor(AppColors.foregroundSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
            }
            .animation(.easeOut(duration: 0.15), value: chat.messages.isEmpty)
            .overlay(alignment: .top) {
                // Scroll-to-bottom (Figma 1643-8006): 40pt circle straddling
                // the composer's top edge, shown when scrolled up.
                if showScrollToBottom {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .padding(10)
                            .background(AppColors.backgroundWhite)
                            .cornerRadius(200)
                            .shadow(color: AppColors.line1stLine, radius: 0, x: 0, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 200)
                                    .inset(by: 0.5)
                                    .stroke(AppColors.line1stLine, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(y: -48) // fully above the input with an 8pt gap
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: showScrollToBottom)
                .background {
                    // Hugs the container: blur fades in over its top third.
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.35),
                                    .init(color: .black, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .background(AppColors.backgroundWhite)
        .fullScreenCover(isPresented: $chat.showLimitPaywall) {
            CustomPaywallSheet(isPresented: $chat.showLimitPaywall)
        }
        .sheet(item: $chat.detailTransaction) { transaction in
            ReceiptDetailSheet(
                transaction: transaction,
                onTransactionUpdate: { UserManager.shared.updateTransaction($0) },
                onTransactionDelete: { deleted in
                    UserManager.shared.removeTransaction(withId: deleted.id)
                    chat.detailTransaction = nil
                },
                onDismiss: { chat.detailTransaction = nil }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
        }
    }

    /// First name for the hero greeting; falls back to a plain greeting.
    private var heroName: String {
        let name = UserManager.shared.currentUser.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = name.components(separatedBy: " ").first ?? ""
        return first.isEmpty || first == "Cashmonki" ? "there" : first
    }

    private func starterChip(_ text: String) -> some View {
        // Rounded-square secondary button: white, border, hard offset shadow.
        AppButton(
            title: text,
            action: { chat.send(String(text.dropFirst(2))) }, // strip the emoji prefix
            hierarchy: .secondary,
            size: .tripleExtraSmall
        )
        .fixedSize()
    }

    // MARK: Composer — white card on grey (Figma 1639-7821)

    private var composerBar: some View {
        // Single line: input + send. Plus/mic hidden until those features land.
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask anything", text: $composeText, axis: .vertical)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)
                .accentColor(AppColors.accentBackground)
                .lineLimit(1...4)
                .focused($composerFocused)
                .submitLabel(.done)
                .onChange(of: composeText) { _, newValue in
                    // Vertical-axis fields insert newlines on Return: send the
                    // message (if any) and dismiss the keyboard.
                    if newValue.contains("\n") {
                        let text = newValue.replacingOccurrences(of: "\n", with: "")
                        composeText = text
                        composerFocused = false
                        if !text.trimmingCharacters(in: .whitespaces).isEmpty && !chat.isThinking {
                            chat.send(text)
                            composeText = ""
                        }
                    }
                }
                .padding(.vertical, 10)

            // Bare icon, no button chrome — keeps the input lean.
            Button {
                // Clear first (avoids autocorrect re-inserting), then send.
                let text = composeText
                composeText = ""
                guard !chat.isThinking else { composeText = text; return }
                chat.send(text)
            } label: {
                AppIcon(assetName: "send-01", fallbackSystemName: "paperplane.fill", size: 22)
                    .foregroundColor(AppColors.accentBackground)
                    .opacity(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isThinking ? 0.5 : 1)
                    .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white)
        .cornerRadius(16)
        .shadow(color: Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.06), radius: 16, x: 0, y: 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 10) // footer text sits just below
    }

}

// MARK: - Message rendering

private struct AskMessageView: View {
    let message: AskDisplayMessage

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 60)
                if case .text(let text) = message.content {
                    Text(text)
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                        .cornerRadius(12)
                }
            }
        } else {
            switch message.content {
            case .text(let text):
                if AskChatManager.shared.streamingMessageID == message.id {
                    AskStreamingWordsView(text: text)
                } else {
                    Text(AskFormat.markdown(text))
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)
                }
            case .systemNote(let text):
                // Renders identically to a settled text bubble — the distinction
                // is only in how it's fed back to the model (see historyText).
                Text(AskFormat.markdown(text))
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
            case .table(let table):
                VStack(alignment: .leading, spacing: 12) {
                    AskTableMessageView(table: table)
                    AskSuggestionChipsRow(messageID: message.id, choices: table.followups ?? [])
                }
            case .draft(let draft):
                AskDraftCard(messageID: message.id, draft: draft)
            case .update(let update):
                AskUpdateCard(messageID: message.id, update: update)
            case .single(let ref):
                AskSingleTransactionCard(ref: ref)
            case .deleteRequest(let delete):
                AskDeleteCard(messageID: message.id, delete: delete)
            case .chart(let chart):
                VStack(alignment: .leading, spacing: 12) {
                    AskChartMessageView(chart: chart)
                    AskSuggestionChipsRow(messageID: message.id, choices: chart.followups ?? [])
                }
            case .stat(let stat):
                VStack(alignment: .leading, spacing: 12) {
                    AskStatCardView(stat: stat)
                    AskSuggestionChipsRow(messageID: message.id, choices: stat.followups ?? [])
                }
            case .question(let text, let choices):
                AskQuestionView(messageID: message.id, text: text, choices: choices)
            case .categoryDraft(let draft):
                AskCategoryDraftCard(messageID: message.id, draft: draft)
            }
        }
    }
}

// MARK: - Table message (schema-driven; rows are real tool data)

private struct AskTableMessageView: View {
    let table: AskTableMessage

    /// Estimated natural width per column (max of header/longest cell), used
    /// to decide full-width vs horizontal scroll from the data itself.
    private var columnWidths: [CGFloat] {
        let charWidth: CGFloat = 7.5 // ~14pt Overused Grotesk medium
        return table.columns.map { column in
            let headerLength = column.label.count
            let longestCell = (table.rows ?? []).map { ($0[column.key] ?? "").count }.max() ?? 0
            return CGFloat(max(headerLength, longestCell)) * charWidth + 16
        }
    }

    private var fitsFullWidth: Bool {
        columnWidths.reduce(0, +) <= UIScreen.main.bounds.width - 40
    }

    // Scroll position drives the edge fades so they never cover content at rest.
    @State private var scrollOffsetX: CGFloat = 0
    @State private var maxScrollX: CGFloat = 0


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(table.title)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)

            if fitsFullWidth {
                // Columns share the chat width; continuous dividers.
                tableGrid(flexible: true)
                    .frame(maxWidth: .infinity)
            } else {
                // Prose-heavy data: natural column widths, scrolls sideways,
                // with white fade-out gradients on both edges (Figma 1639-7736/7738).
                // Clipped to the message width, natural column widths; white
                // fades appear only on edges that have hidden content.
                ScrollView(.horizontal, showsIndicators: false) {
                    tableGrid(flexible: false)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.x
                } action: { _, newValue in
                    scrollOffsetX = newValue
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(geometry.contentSize.width - geometry.containerSize.width, 0)
                } action: { _, newValue in
                    maxScrollX = newValue
                }
                .overlay(alignment: .leading) {
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .white, location: 0.00),
                            Gradient.Stop(color: .white.opacity(0), location: 1.00)
                        ],
                        startPoint: UnitPoint(x: 0, y: 0.5),
                        endPoint: UnitPoint(x: 1, y: 0.5)
                    )
                    .frame(width: 20)
                    .opacity(scrollOffsetX > 2 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: scrollOffsetX > 2)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: .white, location: 0.00),
                            Gradient.Stop(color: .white.opacity(0), location: 1.00)
                        ],
                        startPoint: UnitPoint(x: 1, y: 0.5),
                        endPoint: UnitPoint(x: 0, y: 0.5)
                    )
                    .frame(width: 20)
                    .opacity(scrollOffsetX < maxScrollX - 2 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: scrollOffsetX < maxScrollX - 2)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func tableGrid(flexible: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: flexible ? 0 : 10) {
                ForEach(Array(table.columns.enumerated()), id: \.offset) { index, column in
                    Text(column.label.uppercased())
                        .font(AppFonts.overusedGroteskSemiBold(size: 10))
                        .kerning(0.5)
                        .foregroundColor(AppColors.foregroundTertiary)
                        .modifier(AskCellFrame(flexible: flexible, width: columnWidths[index], alignment: cellAlignment(column)))
                }
            }
            .padding(.bottom, 10)

            ForEach(Array((table.rows ?? []).enumerated()), id: \.offset) { _, row in
                VStack(spacing: 0) {
                    Divider().background(AppColors.line1stLine)
                    HStack(alignment: .top, spacing: flexible ? 0 : 10) {
                        ForEach(Array(table.columns.enumerated()), id: \.offset) { index, column in
                            Text(cellText(row[column.key] ?? "", column: column))
                                .font(AppFonts.overusedGroteskMedium(size: 14))
                                .foregroundColor(AppColors.foregroundPrimary)
                                .lineLimit(flexible ? 2 : 1)
                                .modifier(AskCellFrame(flexible: flexible, width: columnWidths[index], alignment: cellAlignment(column)))
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    /// Right-aligned when the model hints it OR when every cell is numeric.
    private func cellAlignment(_ column: AskTableColumn) -> Alignment {
        (column.isRightAligned || isNumericColumn(column)) ? .trailing : .leading
    }

    private func isNumericColumn(_ column: AskTableColumn) -> Bool {
        let values = (table.rows ?? []).compactMap { $0[column.key] }.filter { !$0.isEmpty }
        guard !values.isEmpty else { return false }
        return values.allSatisfy { Double($0.replacingOccurrences(of: ",", with: "")) != nil }
    }

    private func cellText(_ raw: String, column: AskTableColumn) -> String {
        guard column.isCurrency, let value = Double(raw) else { return raw }
        return AskFormat.currencyWithSymbol(value)
    }
}

/// Flexible cells share the row width; fixed cells use the column's natural width.
private struct AskCellFrame: ViewModifier {
    let flexible: Bool
    let width: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        if flexible {
            content.frame(maxWidth: .infinity, alignment: alignment)
        } else {
            content.frame(width: width, alignment: alignment)
        }
    }
}

// MARK: - Transaction draft (collapsed add-tile per Figma 1639-7891, expands to confirm card)

private struct AskDraftCard: View {
    let messageID: UUID
    let draft: AskTransactionDraft

    @ObservedObject private var chat = AskChatManager.shared
    @State private var showingEditSheet = false

    // Editable fields, seeded from the draft
    @State private var amountText: String = ""
    @State private var merchant: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var currencyCode: String = ""
    @State private var selectedCategoryID: UUID? = nil
    @State private var selectedCategoryName: String = ""
    @State private var showingCategoryPicker = false
    @State private var pickerCategoryId: UUID? = nil

    private var isConfirmed: Bool { chat.confirmedDrafts.contains(messageID) }

    /// Suggested categories validated against the user's real category list.
    private var validSuggestions: [(id: UUID, name: String)] {
        (draft.suggested_categories ?? []).compactMap { suggestion in
            guard let uuid = UUID(uuidString: suggestion.id),
                  CategoriesManager.shared.findCategoryOrSubcategoryById(uuid) != nil
            else { return nil }
            return (uuid, suggestion.name)
        }
    }

    private var currency: Currency {
        Currency.allCases.first { $0.rawValue.uppercased() == currencyCode.uppercased() }
            ?? CurrencyPreferences.shared.primaryCurrency
    }

    /// Emoji of the currently selected category (Figma shows e.g. "☕️ Add 100 for coffee?").
    private var tileEmoji: String {
        if let id = selectedCategoryID {
            return TxnCategoryIcon.emojiFor(categoryId: id, categoryName: selectedCategoryName)
        }
        return "➕"
    }

    private var tileTitle: String {
        let amount = currency.symbol + AskFormat.currency(draft.amount)
        let target = selectedCategoryName.isEmpty ? (draft.note ?? draft.merchant ?? "") : selectedCategoryName.lowercased()
        return "\(tileEmoji) Add \(amount)\(target.isEmpty ? "" : " under \(target)")?"
    }

    /// "EXPENSE" / "INCOME" from the selected category's type.
    private var tileTypeLabel: String {
        if let id = selectedCategoryID, let result = CategoriesManager.shared.findCategoryOrSubcategoryById(id) {
            let type = result.subcategory?.type ?? result.category?.type
            return type == .income ? "INCOME" : "EXPENSE"
        }
        return "EXPENSE"
    }

    private var tileMetaDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collapsed tile — the "add button" (Figma 1639-7891)
            Button {
                guard !isConfirmed else { return }
                showingEditSheet = true
            } label: {
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tileTypeLabel)
                            .font(AppFonts.overusedGroteskSemiBold(size: 11))
                            .kerning(0.8)
                            .foregroundColor(AppColors.foregroundTertiary)

                        Text(isConfirmed ? "✅ Added" : tileTitle)
                            .font(AppFonts.overusedGroteskSemiBold(size: 16))
                            .foregroundColor(AppColors.foregroundPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        HStack(spacing: 8) {
                            Text(tileMetaDate)
                            if let merchant = draft.merchant, !merchant.isEmpty {
                                Text("·")
                                Text(merchant)
                            }
                        }
                        .font(AppFonts.overusedGroteskMedium(size: 15))
                        .foregroundColor(AppColors.foregroundSecondary)
                    }
                    Spacer(minLength: 0)
                    if !isConfirmed {
                        // One-tap add with the current selection; tile body expands the editor.
                        AppButton(
                            title: "",
                            action: confirm,
                            hierarchy: .secondary,
                            size: .doubleExtraSmall,
                            leftIcon: "plus"
                        )
                        .fixedSize()
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 30)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.backgroundWhite)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .inset(by: 0.5)
                        .stroke(AppColors.line1stLine, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

        }
        .onAppear(perform: seedFromDraft)
        .sheet(isPresented: $showingEditSheet) {
            AddTransactionSheet(
                isPresented: $showingEditSheet,
                primaryCurrency: CurrencyPreferences.shared.primaryCurrency,
                prefillAmount: amountText,
                prefillMerchant: merchant,
                prefillNote: note,
                prefillCategoryId: selectedCategoryID,
                prefillDate: date,
                prefillCurrency: currency
            ) { newTxn in
                UserManager.shared.addTransaction(newTxn)
                chat.draftErrors[messageID] = nil
                chat.confirmedDrafts.insert(messageID)
                chat.messages.append(AskDisplayMessage(isUser: false, content: .systemNote("✅ Added \(AskFormat.currencyWithSymbol(abs(newTxn.amount)))\(newTxn.category.isEmpty ? "" : " to \(newTxn.category)").")))
            }
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.thinMaterial)
            .presentationCornerRadius(20)
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(
                selectedCategoryId: $pickerCategoryId,
                isPresented: $showingCategoryPicker,
                initialTab: .expense
            )
            .presentationDetents([.fraction(0.98)])
            .presentationCornerRadius(20)
        }
        .onChange(of: pickerCategoryId) { _, newId in
            guard let newId, let result = CategoriesManager.shared.findCategoryOrSubcategoryById(newId) else { return }
            selectedCategoryID = newId
            selectedCategoryName = result.category?.name ?? result.subcategory?.name ?? ""
        }
    }

    // MARK: Confirmation card — parsed fields editable, category chips, Confirm/Cancel

    private var confirmCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppInputField.text(title: "Amount (\(currency.rawValue))", text: $amountText, placeholder: "0")
            AppInputField.text(title: "Merchant", text: $merchant, placeholder: "Optional")
            AppInputField.date(title: "Date", dateValue: $date)
            AppInputField.text(title: "Note", text: $note, placeholder: "Optional")

            // Category chips: top suggestion pre-selected, "Other…" opens the full picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(validSuggestions, id: \.id) { suggestion in
                            categoryChip(name: suggestion.name, isSelected: selectedCategoryID == suggestion.id) {
                                selectedCategoryID = suggestion.id
                                selectedCategoryName = suggestion.name
                            }
                        }
                        if !validSuggestions.contains(where: { $0.name == selectedCategoryName }) && !selectedCategoryName.isEmpty {
                            categoryChip(name: selectedCategoryName, isSelected: true) {}
                        }
                        categoryChip(name: "Other…", isSelected: false) {
                            showingCategoryPicker = true
                        }
                    }
                }
            }

            if let error = chat.draftErrors[messageID] {
                Text(error)
                    .font(AppFonts.overusedGroteskMedium(size: 13))
                    .foregroundColor(AppColors.destructiveForeground)
            }

            HStack(spacing: 12) {
                AppButton(
                    title: "Cancel",
                    action: { chat.cancelDraft(messageID: messageID) },
                    hierarchy: .secondary,
                    size: .doubleExtraSmall
                )
                AppButton(
                    title: "Confirm",
                    action: confirm,
                    hierarchy: .primary,
                    size: .doubleExtraSmall
                )
            }
        }
        .padding(16)
        .background(AppColors.surfacePrimary)
        .cornerRadius(12)
    }

    private func categoryChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(AppFonts.overusedGroteskMedium(size: 13))
                .foregroundColor(isSelected ? .white : AppColors.foregroundPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? AppColors.accentBackground : AppColors.backgroundWhite)
                )
                .overlay(
                    Capsule().inset(by: 0.5).stroke(isSelected ? Color.clear : AppColors.line1stLine, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func seedFromDraft() {
        guard amountText.isEmpty else { return } // already seeded
        amountText = String(format: "%.2f", draft.amount)
        merchant = draft.merchant ?? ""
        note = draft.note ?? ""
        currencyCode = draft.currency ?? CurrencyPreferences.shared.primaryCurrency.rawValue
        if let dateString = draft.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.date(from: dateString) ?? Date()
        }
        if let top = validSuggestions.first {
            selectedCategoryID = top.id
            selectedCategoryName = top.name
        }
    }

    private func confirm() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        chat.confirmDraft(
            messageID: messageID,
            amount: amount,
            currency: currency,
            merchant: merchant.isEmpty ? nil : merchant,
            date: date,
            note: note.isEmpty ? nil : note,
            categoryId: selectedCategoryID,
            categoryName: selectedCategoryName
        )
    }
}

// MARK: - Transaction update card (before → after, Confirm/Cancel)

private struct AskUpdateCard: View {
    let messageID: UUID
    let update: AskTransactionUpdate

    @ObservedObject private var chat = AskChatManager.shared

    private var isConfirmed: Bool { chat.confirmedDrafts.contains(messageID) }

    private var targets: [Txn] {
        update.ids.compactMap { id in
            guard let txID = UUID(uuidString: id) else { return nil }
            return UserManager.shared.currentUser.transactions.first { $0.txID == txID }
        }
    }

    private var target: Txn? { targets.first }

    /// (label, before, after) rows for the changed fields only.
    private var changes: [(String, String, String)] {
        guard let txn = target else { return [] }
        var rows: [(String, String, String)] = []
        if let amount = update.amount {
            rows.append(("Amount", AskFormat.currency(abs(txn.originalAmount ?? txn.amount)), AskFormat.currency(amount)))
        }
        if let merchant = update.merchant {
            rows.append(("Merchant", txn.merchantName ?? "–", merchant))
        }
        if let dateString = update.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"
            let after = parser.date(from: dateString).map { formatter.string(from: $0) } ?? dateString
            rows.append(("Date", formatter.string(from: txn.date), after))
        }
        if let note = update.note {
            rows.append(("Note", txn.note ?? "–", note))
        }
        if let categoryId = update.category_id, let uuid = UUID(uuidString: categoryId),
           let result = CategoriesManager.shared.findCategoryOrSubcategoryById(uuid) {
            let name = result.category?.name ?? result.subcategory?.name ?? "?"
            rows.append(("Category", txn.category, name))
        }
        return rows
    }

    /// "Change ₱175 to ₱1,300?" for a single change; pluralized for batches.
    private var questionText: String {
        if targets.count > 1 {
            if changes.count == 1, let change = changes.first {
                return "Change \(change.0.lowercased()) to \(change.2) for \(targets.count) transactions?"
            }
            return "Apply these changes to \(targets.count) transactions?"
        }
        if changes.count == 1, let change = changes.first {
            if change.0 == "Amount" { return "Change \(change.1) to \(change.2)?" }
            return "Change \(change.0.lowercased()) to \(change.2)?"
        }
        return "Apply these changes?"
    }

    var body: some View {
        if !targets.isEmpty, isConfirmed {
            // Confirmed state: updated line items + "Transaction updated ✓".
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    ForEach(targets, id: \.txID) { txn in
                        UnifiedTransactionDisplay.row(transaction: txn, onTap: {})
                            .background(AppColors.backgroundWhite)
                            .cornerRadius(12)
                    }
                }
                .padding(8)

                HStack {
                    Text(targets.count > 1 ? "\(targets.count) transactions updated" : "Transaction updated")
                        .font(AppFonts.overusedGroteskMedium(size: 15))
                        .foregroundColor(AppColors.foregroundSecondary)
                    Spacer(minLength: 8)
                    AppIcon(assetName: "check", fallbackSystemName: "checkmark", size: 18)
                        .foregroundColor(AppColors.successForeground)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .background(AppColors.surfacePrimary)
            .cornerRadius(16)
        } else if !targets.isEmpty {
            // Grey permission container: existing transaction line item(s) on
            // top, question + Yes below (Figma 400×130 component).
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    ForEach(targets, id: \.txID) { txn in
                        UnifiedTransactionDisplay.row(transaction: txn, onTap: {})
                            .background(AppColors.backgroundWhite)
                            .cornerRadius(12)
                    }
                }
                .padding(8)

                if changes.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                            HStack(spacing: 6) {
                                Text(change.0)
                                    .foregroundColor(AppColors.foregroundSecondary)
                                Spacer()
                                Text(change.1)
                                    .foregroundColor(AppColors.foregroundTertiary)
                                    .strikethrough()
                                Text(change.2)
                                    .foregroundColor(AppColors.foregroundPrimary)
                            }
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                }

                if let error = chat.draftErrors[messageID] {
                    Text(error)
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.destructiveForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                HStack {
                    Text(questionText)
                        .font(AppFonts.overusedGroteskMedium(size: 17))
                        .foregroundColor(AppColors.foregroundPrimary)
                    Spacer(minLength: 8)
                    AppButton(
                        title: "Yes",
                        action: { chat.confirmUpdate(messageID: messageID, update: update) },
                        hierarchy: .textPrimary,
                        size: .tripleExtraSmall
                    )
                    .fixedSize()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .background(AppColors.surfacePrimary)
            .cornerRadius(16)
        } else if !isConfirmed {
            Text("That transaction couldn't be found anymore.")
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundColor(AppColors.foregroundSecondary)
        }
    }
}

// MARK: - Single transaction card

private struct AskSingleTransactionCard: View {
    let ref: AskTransactionRef

    private var targets: [Txn] {
        ref.ids.compactMap { id in
            guard let txID = UUID(uuidString: id) else { return nil }
            return UserManager.shared.currentUser.transactions.first { $0.txID == txID }
        }
    }

    var body: some View {
        if targets.isEmpty {
            Text("Those transactions couldn't be found anymore.")
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundColor(AppColors.foregroundSecondary)
        } else {
            VStack(spacing: 8) {
                ForEach(targets, id: \.txID) { txn in
                    UnifiedTransactionDisplay.row(transaction: txn, onTap: {
                        AskChatManager.shared.detailTransaction = txn
                    })
                        .askDataCard()
                }
            }
        }
    }
}

// MARK: - Transaction delete card (permission to delete, destructive)

private struct AskDeleteCard: View {
    let messageID: UUID
    let delete: AskTransactionDelete

    @ObservedObject private var chat = AskChatManager.shared

    private var isConfirmed: Bool { chat.confirmedDrafts.contains(messageID) }

    private var targets: [Txn] {
        delete.ids.compactMap { id in
            guard let txID = UUID(uuidString: id) else { return nil }
            return UserManager.shared.currentUser.transactions.first { $0.txID == txID }
        }
    }

    var body: some View {
        if !targets.isEmpty && !isConfirmed {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    ForEach(targets, id: \.txID) { txn in
                        UnifiedTransactionDisplay.row(transaction: txn, onTap: {})
                            .background(AppColors.backgroundWhite)
                            .cornerRadius(12)
                    }
                }
                .padding(8)

                if let error = chat.draftErrors[messageID] {
                    Text(error)
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.destructiveForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                HStack {
                    Text(targets.count > 1 ? "Delete these \(targets.count) transactions?" : "Delete this transaction?")
                        .font(AppFonts.overusedGroteskMedium(size: 15))
                        .foregroundColor(AppColors.foregroundPrimary)
                    Spacer(minLength: 8)
                    AppButton(
                        title: "Delete",
                        action: { chat.confirmDelete(messageID: messageID, delete: delete) },
                        hierarchy: .textPrimary,
                        size: .tripleExtraSmall,
                        textColorOverride: AppColors.destructiveForeground
                    )
                    .fixedSize()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .background(AppColors.surfacePrimary)
            .cornerRadius(16)
        } else if targets.isEmpty && !isConfirmed {
            Text("Those transactions couldn't be found anymore.")
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundColor(AppColors.foregroundSecondary)
        }
    }
}

// MARK: - Chart message (horizontal bars, Figma 1641-7816)

private struct AskChartMessageView: View {
    let chart: AskChartMessage

    private func barColor(at index: Int) -> Color { AskChartPalette.color(at: index) }

    private func barTextColor(at index: Int) -> Color { .white }


    private var items: [AskChartItem] { chart.items ?? [] }
    private var maxValue: Double { max(items.map(\.value).max() ?? 1, 0.01) }

    /// Width available for the longest bar (card minus paddings, label, n).
    private var maxBarWidth: CGFloat {
        UIScreen.main.bounds.width - 40 - 36 - 104 - 12 - 30 - 12
    }

    var body: some View {
        // Exactly two items = a period comparison: side-by-side cards
        // with vertical bars (Figma 1643-7958).
        if items.count == 2 {
            AskComparisonPairView(items: items)
        } else {
            barChart
        }
    }

    private var barChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chart.title.uppercased())
                .font(AppFonts.overusedGroteskMedium(size: 10))
                .kerning(1)
                .foregroundColor(AppColors.foregroundSecondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Text(item.label)
                            .font(AppFonts.overusedGroteskMedium(size: 15))
                            .foregroundColor(AppColors.foregroundSecondary)
                            .lineLimit(1)
                            .frame(width: 104, alignment: .leading)

                        Text(AskFormat.currencyWithSymbol(item.value))
                            .font(AppFonts.overusedGroteskMedium(size: 12))
                            .foregroundColor(barTextColor(at: index))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(width: barWidth(for: item), height: 28, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(barColor(at: index))
                            )

                        if let count = item.count {
                            Text(count)
                                .font(AppFonts.overusedGroteskMedium(size: 15))
                                .foregroundColor(AppColors.foregroundSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(height: 28)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .askDataCard()
    }

    private func barWidth(for item: AskChartItem) -> CGFloat {
        let ratio = CGFloat(item.value / maxValue)
        return max(64, ratio * maxBarWidth) // min width keeps the value legible
    }
}

// MARK: - Stat card (hero number + trend, per user mock)

private struct AskStatCardView: View {
    let stat: AskStatMessage

    /// Percent change vs the comparison value, if one was provided.
    private var percentChange: Double? {
        guard let compare = stat.compare_value, compare != 0 else { return nil }
        return (stat.value - compare) / abs(compare) * 100
    }

    private var isImprovement: Bool {
        guard let change = percentChange else { return true }
        let goodIsDown = (stat.good_direction ?? "down") == "down"
        return goodIsDown ? change <= 0 : change >= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stat.title.uppercased())
                .font(AppFonts.overusedGroteskMedium(size: 10))
                .kerning(1)
                .foregroundColor(AppColors.foregroundSecondary)

            Text(AskFormat.currencyWithSymbol(abs(stat.value)))
                .font(AppFonts.overusedGroteskMedium(size: 50))
                .foregroundColor(AppColors.foregroundPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let change = percentChange {
                HStack(spacing: 4) {
                    Image(systemName: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isImprovement ? AppColors.successForeground : AppColors.destructiveForeground)
                    Text("\(abs(Int(change.rounded())))%\(stat.compare_label.map { " vs \($0)" } ?? "")")
                        .font(AppFonts.overusedGroteskMedium(size: 15))
                        .foregroundColor(AppColors.foregroundSecondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .askDataCard()
    }
}

/// 20 chart tones — purple's complements plus earthy family: oranges,
/// yellows, blues, purples, greens, browns. One value level; families
/// rotate so adjacent bars always contrast. Labels carry identity.
enum AskChartPalette {
    private static let earthTones: [(Double, Double, Double)] = [
        (0xF0, 0x8A, 0x2E), // vivid amber
        (0x3D, 0x7F, 0xD9), // vivid blue
        (0x7C, 0x4D, 0xFF), // violet (brand-adjacent)
        (0xE8, 0xB0, 0x1F), // gold
        (0x3F, 0xA3, 0x5C), // green
        (0xB0, 0x6A, 0x32), // sienna
        (0xE8, 0x5D, 0x1F), // burnt orange
        (0x2E, 0x9C, 0xCE), // cyan steel
        (0xA8, 0x55, 0xD6), // orchid
        (0xD9, 0xB3, 0x25), // mustard
        (0x1F, 0xA8, 0x8A), // sea green
        (0x9A, 0x5A, 0x2E), // cocoa
        (0xF0, 0xA0, 0x45), // honey
        (0x2E, 0x6A, 0xCC), // denim
        (0x6A, 0x3E, 0xD9), // indigo
        (0xC9, 0xA6, 0x20), // brass
        (0x7C, 0xB0, 0x3D), // olive bright
        (0xC9, 0x7A, 0x3D), // caramel
        (0xE0, 0x53, 0x3D), // clay red
        (0x6E, 0x8A, 0xA8)  // stone blue
    ]

    static func color(at index: Int) -> Color {
        let tone = earthTones[index % earthTones.count]
        return Color(red: tone.0 / 255.0, green: tone.1 / 255.0, blue: tone.2 / 255.0)
    }
}

// MARK: - Comparison pair (two periods side by side, Figma 1643-7958)

private struct AskComparisonPairView: View {
    let items: [AskChartItem]

    private var maxValue: Double { max(items.map(\.value).max() ?? 1, 0.01) }

    /// Percent change of the second period vs the first.
    private var change: Double? {
        guard items.count == 2, items[0].value != 0 else { return nil }
        return (items[1].value - items[0].value) / abs(items[0].value) * 100
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            comparisonCard(index: 0, barColor: AskChartPalette.color(at: 0), showTrend: false)
            comparisonCard(index: 1, barColor: AskChartPalette.color(at: 4), showTrend: true)
        }
    }

    private func comparisonCard(index: Int, barColor: Color, showTrend: Bool) -> some View {
        let item = items[index]
        let ratio = CGFloat(item.value / maxValue)

        return VStack(alignment: .leading, spacing: 0) {
            Text(item.label.uppercased())
                .font(AppFonts.overusedGroteskMedium(size: 10))
                .kerning(1)
                .foregroundColor(AppColors.foregroundSecondary)
                .lineLimit(1)
                .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 8) {
                Text(AskFormat.currencyWithSymbol(item.value))
                    .font(AppFonts.overusedGroteskMedium(size: 20))
                    .foregroundColor(AppColors.foregroundPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if showTrend, let change {
                    let improvement = change <= 0
                    HStack(spacing: 4) {
                        Image(systemName: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(improvement ? AppColors.successForeground : AppColors.destructiveForeground)
                        Text("\(abs(Int(change.rounded())))%")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }
            }

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0xF2/255.0, green: 0xF4/255.0, blue: 0xF7/255.0))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(barColor)
                    .frame(height: max(8, ratio * 118))
            }
            .frame(height: 118)
            .padding(.top, 22)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .askDataCard()
    }
}

// MARK: - Shared data-card chrome (chart / stat / transaction cards)

private struct AskDataCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundWhite)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .inset(by: 2)
                    .stroke(Color(red: 0xF3/255.0, green: 0xF5/255.0, blue: 0xF8/255.0), lineWidth: 4)
            )
    }
}

private extension View {
    func askDataCard() -> some View { modifier(AskDataCardStyle()) }
}

// MARK: - Category suggestion card

private struct AskCategoryDraftCard: View {
    let messageID: UUID
    let draft: AskCategoryDraft

    @ObservedObject private var chat = AskChatManager.shared

    private var isConfirmed: Bool { chat.confirmedDrafts.contains(messageID) }

    var body: some View {
        if !isConfirmed {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(draft.parent == nil ? "NEW CATEGORY" : "NEW SUBCATEGORY")
                        .font(AppFonts.overusedGroteskMedium(size: 10))
                        .kerning(1)
                        .foregroundColor(AppColors.foregroundSecondary)

                    Text("\(draft.emoji ?? "📁") \(draft.name)")
                        .font(AppFonts.overusedGroteskSemiBold(size: 16))
                        .foregroundColor(AppColors.foregroundPrimary)

                    if let parent = draft.parent {
                        Text("Under \(parent)")
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(AppColors.backgroundWhite)
                .cornerRadius(12)
                .padding(8)

                if let error = chat.draftErrors[messageID] {
                    Text(error)
                        .font(AppFonts.overusedGroteskMedium(size: 13))
                        .foregroundColor(AppColors.destructiveForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }

                HStack {
                    Text("Add this \(draft.parent == nil ? "category" : "subcategory")?")
                        .font(AppFonts.overusedGroteskMedium(size: 15))
                        .foregroundColor(AppColors.foregroundPrimary)
                    Spacer(minLength: 8)
                    AppButton(
                        title: "Yes",
                        action: { chat.confirmCategoryDraft(messageID: messageID, draft: draft) },
                        hierarchy: .textPrimary,
                        size: .tripleExtraSmall
                    )
                    .fixedSize()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
            .background(AppColors.surfacePrimary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Suggestion chips (shared: questions + follow-ups under widgets)

private struct AskSuggestionChipsRow: View {
    let messageID: UUID
    let choices: [String]

    @ObservedObject private var chat = AskChatManager.shared

    /// Chips only while this is the latest message.
    private var isActive: Bool {
        !choices.isEmpty && chat.messages.last?.id == messageID && !chat.isThinking
    }

    var body: some View {
        if isActive {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(choices, id: \.self) { choice in
                        AppButton(
                            title: choice,
                            action: { chat.send(choice) },
                            hierarchy: .secondary,
                            size: .tripleExtraSmall
                        )
                        .fixedSize()
                    }
                }
                .padding(.horizontal, 20) // chips align with text; last one scrolls off the edge cleanly
                .padding(.bottom, 4) // room for the hard shadow
            }
            .padding(.horizontal, -20) // full-bleed: cancel the message list's 20pt inset
            .transition(.opacity)
        }
    }
}

// MARK: - Question with answer chips

private struct AskQuestionView: View {
    let messageID: UUID
    let text: String
    let choices: [String]

    @ObservedObject private var chat = AskChatManager.shared

    /// Chips only while this is the latest message — once answered (or the
    /// conversation moved on) they disappear.
    private var isAwaitingAnswer: Bool {
        chat.messages.last?.id == messageID && !chat.isThinking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AskFormat.markdown(text))
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundColor(AppColors.foregroundPrimary)

            AskSuggestionChipsRow(messageID: messageID, choices: choices)
        }
        .animation(.easeOut(duration: 0.15), value: isAwaitingAnswer)
    }
}

// MARK: - Streaming text (words fade in as they arrive)

private struct AskStreamingWordsView: View {
    let text: String

    var body: some View {
        // Render markdown live off the growing text so bold/italic style as words stream in.
        Text(AskFormat.markdown(AskFormat.sanitizedStreaming(text)))
            .font(AppFonts.overusedGroteskMedium(size: 16))
            .foregroundColor(AppColors.foregroundPrimary)
            .animation(.easeOut(duration: 0.2), value: text)
    }
}

// MARK: - Thinking indicator (three pulsing dots)

private struct AskThinkingDots: View {
    @State private var activeDot = 0
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.foregroundTertiary)
                    .frame(width: 7, height: 7)
                    .opacity(activeDot == index ? 1 : 0.3)
                    .scaleEffect(activeDot == index ? 1.15 : 1)
            }
        }
        .padding(.vertical, 6)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                activeDot = (activeDot + 1) % 3
            }
        }
    }
}

#Preview {
    AskPage()
}
