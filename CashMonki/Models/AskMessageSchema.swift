//
//  AskMessageSchema.swift
//  CashMonki
//
//  Shared schema module for structured AI chat messages. The model's output is
//  constrained to a fixed menu of types ("text", "table", "transaction_draft");
//  anything unknown or malformed falls back to plain text — never a broken
//  widget. Future types (charts, stat cards) = new schema here + a renderer.
//

import Foundation

// MARK: - Structured message menu

enum AskStructuredMessage {
    case text(String)
    /// A question with tappable answer chips.
    case question(String, [String])
    case table(AskTableMessage)
    case transactionDraft(AskTransactionDraft)
    case transactionDraftBatch(AskTransactionDraftBatch)
    case transactionUpdate(AskTransactionUpdate)
    case transaction(AskTransactionRef)
    case transactionDelete(AskTransactionDelete)
    case chart(AskChartMessage)
    case stat(AskStatMessage)
    case categoryDraft(AskCategoryDraft)
    case budgetDraft(AskBudgetDraft)
    case budgetUpdate(AskBudgetUpdate)
    case budgetDelete(AskBudgetDelete)
    case subscriptionDraft(AskSubscriptionDraft)
    case subscriptionUpdate(AskSubscriptionUpdate)
    case subscriptionDelete(AskSubscriptionDelete)
}

// MARK: - Recurring / subscription drafts

/// Proposed recurring item ("Netflix 549 monthly"). Created ONLY after the user
/// confirms — and free accounts are capped, so the paywall can appear instead.
struct AskSubscriptionDraft: Codable {
    let type: String
    let name: String
    let amount: Double
    let currency: String?
    /// Category id from get_categories; nil falls back to "Subscriptions".
    let category_id: String?
    let category_name: String?
    /// "daily" | "weekly" | "monthly" | "quarterly" | "yearly"; nil = monthly.
    let frequency: String?
    /// ISO "yyyy-MM-dd" the series starts from; nil = today.
    let start_date: String?
    /// Whether each due date auto-creates a transaction. nil = true.
    let auto_add: Bool?
    let note: String?
}

/// Proposed edit to existing recurring items. Ids must come from
/// get_subscriptions. Only the supplied fields change.
struct AskSubscriptionUpdate: Codable {
    let type: String
    let subscription_id: String?
    let subscription_ids: [String]?
    let name: String?
    let amount: Double?
    let currency: String?
    let category_id: String?
    let frequency: String?
    let next_due_date: String?
    let auto_add: Bool?
    let is_active: Bool?
    let note: String?

    var ids: [String] {
        if let subscription_ids, !subscription_ids.isEmpty { return subscription_ids }
        if let subscription_id { return [subscription_id] }
        return []
    }

    var hasChanges: Bool {
        name != nil || amount != nil || currency != nil || category_id != nil
            || frequency != nil || next_due_date != nil || auto_add != nil
            || is_active != nil || note != nil
    }
}

/// Proposed deletion of 1-10 recurring items. Ids from get_subscriptions.
struct AskSubscriptionDelete: Codable {
    let type: String
    let subscription_id: String?
    let subscription_ids: [String]?

    var ids: [String] {
        if let subscription_ids, !subscription_ids.isEmpty { return subscription_ids }
        if let subscription_id { return [subscription_id] }
        return []
    }
}

// MARK: - Budget drafts

/// Proposed new budget for a category. Created ONLY after the user confirms.
/// `category_id` must come from get_categories; a subcategory id is folded up
/// to its parent client-side (budgets are parent-category scoped).
struct AskBudgetDraft: Codable {
    let type: String
    let category_id: String
    /// Display name from get_categories; re-resolved client-side either way.
    let category_name: String?
    let amount: Double
    let currency: String?
    /// "daily" | "weekly" | "monthly" | "quarterly" | "yearly"; nil = monthly.
    let period: String?
    let apply_to_all_periods: Bool?
}

/// Proposed edit to existing budgets. Ids must come from get_budgets. Only the
/// fields being changed are set. Applied ONLY after the user confirms.
struct AskBudgetUpdate: Codable {
    let type: String
    let budget_id: String?
    let budget_ids: [String]?
    let amount: Double?
    let currency: String?
    let period: String?
    let is_active: Bool?

    var ids: [String] {
        if let budget_ids, !budget_ids.isEmpty { return budget_ids }
        if let budget_id { return [budget_id] }
        return []
    }

    var hasChanges: Bool {
        amount != nil || currency != nil || period != nil || is_active != nil
    }
}

/// Proposed deletion of 1-10 existing budgets. Ids must come from get_budgets.
struct AskBudgetDelete: Codable {
    let type: String
    let budget_id: String?
    let budget_ids: [String]?

    var ids: [String] {
        if let budget_ids, !budget_ids.isEmpty { return budget_ids }
        if let budget_id { return [budget_id] }
        return []
    }
}

// MARK: - Category suggestion

/// Proposed new category or subcategory. Created ONLY after the user
/// confirms — and category creation is a Pro feature, so free users get
/// the paywall instead.
struct AskCategoryDraft: Codable {
    let type: String
    let name: String
    let emoji: String?
    /// Existing parent category name (from get_categories) for subcategories.
    let parent: String?
    /// "expense" (default) or "income".
    let category_type: String?
}

// MARK: - Stat card (hero number + trend)

struct AskStatMessage: Codable {
    let type: String
    let title: String
    /// Computed from tool data by the model; soft-validated against the
    /// cached rows client-side (see AskChatService).
    let value: Double
    let compare_value: Double?
    let compare_label: String?
    /// Which direction is good for this metric ("down" for spending).
    let good_direction: String?
    let source: String?
    /// 2-3 suggested next questions, shown as chips under the card.
    let followups: [String]?
}

// MARK: - Chart (horizontal bars)

struct AskChartItem: Codable {
    let label: String
    let value: Double
    /// Secondary figure shown right of the bar (e.g. transaction count).
    let count: String?
}

/// Horizontal bar chart. Like tables, items are NEVER trusted from the model —
/// the client builds them from the cached tool result rows.
struct AskChartMessage: Codable {
    let type: String
    let title: String
    let source: String?
    /// Optional cap ("top 5") — rows are already ranked by the tool.
    let limit: Int?
    /// 2-3 suggested next questions, shown as chips under the chart.
    let followups: [String]?

    /// Injected client-side; not part of the model's JSON.
    var items: [AskChartItem]? = nil

    private enum CodingKeys: String, CodingKey { case type, title, source, limit, items, followups }
}

/// Proposed deletion of 1-10 existing transactions. Ids must come from tool
/// results. Applied ONLY after the user confirms.
struct AskTransactionDelete: Codable {
    let type: String
    let transaction_id: String?
    let transaction_ids: [String]?

    var ids: [String] {
        if let transaction_ids, !transaction_ids.isEmpty { return transaction_ids }
        if let transaction_id { return [transaction_id] }
        return []
    }
}

/// Points at 1-3 existing transactions to display as cards (4+ should be a
/// table). Ids must come from tool results.
struct AskTransactionRef: Codable {
    let type: String
    let transaction_id: String?
    let transaction_ids: [String]?

    var ids: [String] {
        if let transaction_ids, !transaction_ids.isEmpty { return transaction_ids }
        if let transaction_id { return [transaction_id] }
        return []
    }
}

// MARK: - Table

struct AskTableColumn: Codable {
    let key: String
    let label: String
    /// "left" (default) or "right". Money columns are right-aligned.
    let align: String?
    /// "currency" formats the cell with the smart currency formatter.
    let format: String?

    var isRightAligned: Bool { align == "right" || format == "currency" }
    var isCurrency: Bool { format == "currency" }
}

struct AskTableMessage: Codable {
    let type: String
    let title: String
    let columns: [AskTableColumn]
    /// Optional cap ("top 5") — rows are already ranked by the tool.
    let limit: Int?
    /// 2-3 suggested next questions, shown as chips under the table.
    let followups: [String]?
    /// Rows are NEVER trusted from the model — the client injects them from
    /// the cached MCP-style tool result (see AskChatService). The model only
    /// chooses title + which columns to show.
    var rows: [[String: String]]?
    /// Tool-call id the rows come from; nil = most recent tool result.
    let source: String?
}

// MARK: - Transaction draft

struct AskSuggestedCategory: Codable, Identifiable {
    let id: String
    let name: String
    let confidence: Double
}

struct AskTransactionDraft: Codable {
    /// Absent on the entries inside a transaction_draft_batch — the envelope
    /// carries the type there, so this must stay optional or the batch fails
    /// to decode and the raw JSON leaks into the chat.
    let type: String?
    let amount: Double
    let currency: String?
    let merchant: String?
    /// ISO date "yyyy-MM-dd"; nil = today.
    let date: String?
    let note: String?
    let suggested_categories: [AskSuggestedCategory]?
}

/// Several proposed transactions in one card (e.g. "log my grocery run: 300
/// vegetables, 150 milk"). Each entry is a normal draft; the user adds them
/// row by row or all at once. Nothing is written until they tap.
struct AskTransactionDraftBatch: Codable {
    let type: String
    /// Short header, e.g. "Grocery run". Optional — the card falls back to a count.
    let title: String?
    let transactions: [AskTransactionDraft]
}

// MARK: - Transaction update

/// Proposed edit to an existing transaction. `transaction_id` must come from
/// a tool result (get_recent_transactions rows carry ids); only the fields
/// being changed are set. Applied ONLY after the user confirms.
struct AskTransactionUpdate: Codable {
    let type: String
    /// Single target, or `transaction_ids` for the same change applied to many.
    let transaction_id: String?
    let transaction_ids: [String]?
    let amount: Double?
    let currency: String?
    let merchant: String?
    let date: String?
    let note: String?
    let category_id: String?

    var ids: [String] {
        if let transaction_ids, !transaction_ids.isEmpty { return transaction_ids }
        if let transaction_id { return [transaction_id] }
        return []
    }

    var hasChanges: Bool {
        amount != nil || currency != nil || merchant != nil || date != nil || note != nil || category_id != nil
    }
}

// MARK: - Decoder with fallback

enum AskMessageDecoder {
    private struct Envelope: Codable { let type: String }

    /// Strictly validates against the known schemas; any failure returns the
    /// raw string as a plain text message.
    static func decode(_ raw: String) -> AskStructuredMessage {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Models sometimes wrap JSON in markdown fences despite instructions —
        // strip ```json ... ``` (or plain ```) before validating.
        if trimmed.hasPrefix("```") {
            var lines = trimmed.components(separatedBy: .newlines)
            lines.removeFirst() // ``` or ```json
            if let last = lines.last, last.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                lines.removeLast()
            }
            trimmed = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Models sometimes prefix prose before the JSON ("Here they are: {…}").
        if !trimmed.hasPrefix("{") {
            // A complete embedded structured object → use it.
            if let embedded = extractJSONObject(from: trimmed) {
                let decoded = decode(embedded)
                if case .text = decoded {} else { return decoded }
            } else if let marker = trimmed.range(of: "{\"type\"", options: .backwards)
                        ?? trimmed.range(of: "{ \"type\"", options: .backwards) {
                // The model tacked a TRUNCATED envelope onto its prose (stream cut mid-JSON).
                // Show only the prose so raw JSON never leaks into the chat.
                let prose = String(trimmed[..<marker.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !prose.isEmpty { return .text(prose) }
            }
        }

        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else {
            return .text(trimmed)
        }
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            return .text(trimmed)
        }

        switch envelope.type {
        case "table":
            guard let table = try? decoder.decode(AskTableMessage.self, from: data),
                  !table.title.isEmpty,
                  !table.columns.isEmpty,
                  table.columns.allSatisfy({ !$0.key.isEmpty && !$0.label.isEmpty })
            else { return malformed(trimmed) }
            return .table(table)

        case "transaction_draft":
            guard let draft = try? decoder.decode(AskTransactionDraft.self, from: data),
                  draft.amount > 0
            else { return malformed(trimmed) }
            return .transactionDraft(draft)

        case "transaction_draft_batch":
            guard let batch = try? decoder.decode(AskTransactionDraftBatch.self, from: data) else {
                return malformed(trimmed)
            }
            let valid = batch.transactions.filter { $0.amount > 0 }
            guard (1...10).contains(valid.count) else { return malformed(trimmed) }
            // A single survivor is a plain draft — no batch chrome for one row.
            if valid.count == 1 { return .transactionDraft(valid[0]) }
            return .transactionDraftBatch(
                AskTransactionDraftBatch(type: batch.type, title: batch.title, transactions: valid)
            )

        case "budget_draft":
            guard let draft = try? decoder.decode(AskBudgetDraft.self, from: data),
                  draft.amount > 0,
                  UUID(uuidString: draft.category_id) != nil
            else { return malformed(trimmed) }
            return .budgetDraft(draft)

        case "budget_update":
            guard let update = try? decoder.decode(AskBudgetUpdate.self, from: data),
                  (1...10).contains(update.ids.count),
                  update.ids.allSatisfy({ UUID(uuidString: $0) != nil }),
                  update.hasChanges,
                  (update.amount ?? 1) > 0
            else { return malformed(trimmed) }
            return .budgetUpdate(update)

        case "budget_delete":
            guard let delete = try? decoder.decode(AskBudgetDelete.self, from: data),
                  (1...10).contains(delete.ids.count),
                  delete.ids.allSatisfy({ UUID(uuidString: $0) != nil })
            else { return malformed(trimmed) }
            return .budgetDelete(delete)

        case "subscription_draft":
            guard let draft = try? decoder.decode(AskSubscriptionDraft.self, from: data),
                  draft.amount > 0,
                  !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            else { return malformed(trimmed) }
            return .subscriptionDraft(draft)

        case "subscription_update":
            guard let update = try? decoder.decode(AskSubscriptionUpdate.self, from: data),
                  (1...10).contains(update.ids.count),
                  update.ids.allSatisfy({ UUID(uuidString: $0) != nil }),
                  update.hasChanges,
                  (update.amount ?? 1) > 0
            else { return malformed(trimmed) }
            return .subscriptionUpdate(update)

        case "subscription_delete":
            guard let delete = try? decoder.decode(AskSubscriptionDelete.self, from: data),
                  (1...10).contains(delete.ids.count),
                  delete.ids.allSatisfy({ UUID(uuidString: $0) != nil })
            else { return malformed(trimmed) }
            return .subscriptionDelete(delete)

        case "transaction":
            guard let ref = try? decoder.decode(AskTransactionRef.self, from: data),
                  (1...3).contains(ref.ids.count),
                  ref.ids.allSatisfy({ UUID(uuidString: $0) != nil })
            else { return malformed(trimmed) }
            return .transaction(ref)

        case "category_draft":
            guard let draft = try? decoder.decode(AskCategoryDraft.self, from: data),
                  !draft.name.trimmingCharacters(in: .whitespaces).isEmpty,
                  draft.name.count <= 40
            else { return malformed(trimmed) }
            return .categoryDraft(draft)

        case "stat":
            guard let stat = try? decoder.decode(AskStatMessage.self, from: data),
                  !stat.title.isEmpty,
                  stat.value.isFinite
            else { return malformed(trimmed) }
            return .stat(stat)

        case "chart":
            guard let chart = try? decoder.decode(AskChartMessage.self, from: data),
                  !chart.title.isEmpty
            else { return malformed(trimmed) }
            return .chart(chart)

        case "transaction_delete":
            guard let delete = try? decoder.decode(AskTransactionDelete.self, from: data),
                  (1...10).contains(delete.ids.count),
                  delete.ids.allSatisfy({ UUID(uuidString: $0) != nil })
            else { return malformed(trimmed) }
            return .transactionDelete(delete)

        case "transaction_update":
            guard let update = try? decoder.decode(AskTransactionUpdate.self, from: data),
                  (1...10).contains(update.ids.count),
                  update.ids.allSatisfy({ UUID(uuidString: $0) != nil }),
                  update.hasChanges
            else { return malformed(trimmed) }
            return .transactionUpdate(update)

        case "text":
            struct TextMessage: Codable { let text: String; let choices: [String]? }
            guard let message = try? decoder.decode(TextMessage.self, from: data) else {
                return malformed(trimmed)
            }
            if let choices = message.choices, !choices.isEmpty {
                return .question(message.text, Array(choices.prefix(4)))
            }
            return .text(message.text)

        default:
            // An envelope we don't render: still JSON, so never show it raw.
            return malformed(trimmed)
        }
    }

    /// A structured reply that didn't survive validation. The raw JSON goes to
    /// the console, never to the chat — a leaked envelope reads as gibberish and
    /// hides whatever the model was actually trying to say.
    private static func malformed(_ raw: String) -> AskStructuredMessage {
        print("🔴 AskMessageDecoder: unrenderable reply — \(raw.prefix(500))")
        return .text("I couldn't put that answer together. Try asking again.")
    }

    /// Pulls the first balanced `{…}` block out of mixed prose+JSON content.
    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var previous: Character = " "
        for index in text.indices[start...] {
            let char = text[index]
            if inString {
                if char == "\"" && previous != "\\" { inString = false }
            } else {
                switch char {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 { return String(text[start...index]) }
                default: break
                }
            }
            previous = char
        }
        return nil
    }
}
