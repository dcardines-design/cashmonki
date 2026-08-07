//
//  AskChatService.swift
//  CashMonki
//
//  Chat pipeline for the Ask tab. Talks to OpenRouter (same key path as
//  ReceiptAI's direct mode) with a tool-calling loop. The "tools" are a local
//  MCP-style layer over the app's managers — the model requests data, we
//  execute against real local data and feed results back. Table rows are
//  always taken from cached tool results, never from model output, so the
//  model cannot invent numbers. Writes (create_transaction) are NOT exposed
//  to the model at all — only the user's Confirm tap calls them.
//

import Foundation

final class AskChatService {
    static let shared = AskChatService()
    private init() {}

    // OpenRouter is reached via our proxy — the API key lives server-side
    // (Vercel: cashmonki-proxy). The app token is revocable, unlike a key.
    private let baseURL = "https://cashmonki-proxy.vercel.app/api/chat"
    private let appToken = "c0790e4ae381bb707d5fd21a7a7c6f0c37ec0aa1988aa129"
    private let model = "anthropic/claude-sonnet-4.5"
    private let maxToolLoops = 4

    /// Rows from tool calls this session, keyed by tool_call_id, plus the most
    /// recent result as a fallback when the model omits `source`.
    private var cachedRows: [String: [[String: String]]] = [:]
    private var lastRows: [[String: String]] = []

    enum AskChatError: LocalizedError {
        case missingAPIKey
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "OpenRouter API key not configured."
            case .badResponse(let detail): return detail
            }
        }
    }

    // MARK: - Public entry

    /// Sends the conversation and returns the assistant's structured message.
    /// Plain-text replies stream through `onDelta` as they generate;
    /// `onStreamReset` fires if already-streamed text must be withdrawn
    /// (another tool round started). Structured JSON is never streamed —
    /// it buffers silently and arrives complete in the return value.
    func send(
        history: [(isUser: Bool, text: String)],
        onDelta: @escaping @Sendable (String) -> Void = { _ in },
        onStreamReset: @escaping @Sendable () -> Void = {}
    ) async throws -> AskStructuredMessage {
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for turn in history {
            messages.append(["role": turn.isUser ? "user" : "assistant", "content": turn.text])
        }

        for _ in 0..<maxToolLoops {
            let response = try await streamCompletion(messages: messages, onDelta: onDelta, onStreamReset: onStreamReset)

            if !response.toolCalls.isEmpty {
                messages.append(response.rawAssistantMessage)
                for call in response.toolCalls {
                    let result = executeTool(name: call.name, argumentsJSON: call.arguments, callID: call.id)
                    messages.append([
                        "role": "tool",
                        "tool_call_id": call.id,
                        "content": result
                    ])
                }
                continue
            }

            let content = response.content
            var structured = AskMessageDecoder.decode(content)

            // Inject real rows into table messages from the cached tool data.
            if case .table(var table) = structured {
                let rows = table.source.flatMap { cachedRows[$0] } ?? lastRows
                guard !rows.isEmpty else {
                    return .text("I couldn't fetch the data for that table. Try asking again.")
                }
                table.rows = table.limit.map { Array(rows.prefix(max($0, 1))) } ?? rows
                structured = .table(table)
            }

            // Stat values are soft-checked against the cached tool rows: a
            // value larger than the data's own total is likely invented.
            if case .stat(let stat) = structured {
                let rows = stat.source.flatMap { cachedRows[$0] } ?? lastRows
                guard !rows.isEmpty else {
                    return .text("I couldn't fetch the data for that stat. Try asking again.")
                }
                let total = rows.compactMap { Double($0["amount"] ?? $0["value"] ?? "") }.reduce(0) { $0 + abs($1) }
                if abs(stat.value) > total * 1.05 + 1 {
                    return .text("I couldn't verify that number against your data. Try asking again.")
                }
            }

            // Charts likewise: bars are built from tool rows, never model output.
            if case .chart(var chart) = structured {
                let rows = chart.source.flatMap { cachedRows[$0] } ?? lastRows
                let items: [AskChartItem] = rows.compactMap { row in
                    guard let label = row["category"] ?? row["merchant"] ?? row["label"],
                          let raw = row["amount"] ?? row["value"],
                          let value = Double(raw)
                    else { return nil }
                    return AskChartItem(label: label, value: abs(value), count: row["count"])
                }
                guard !items.isEmpty else {
                    return .text("I couldn't fetch the data for that chart. Try asking again.")
                }
                chart.items = chart.limit.map { Array(items.prefix(max($0, 1))) } ?? items
                structured = .chart(chart)
            }
            return structured
        }

        throw AskChatError.badResponse("The assistant got stuck fetching data. Try again.")
    }

    // MARK: - OpenRouter call (SSE streaming)

    private struct CompletionResponse {
        struct ToolCall { let id: String; let name: String; let arguments: String }
        let content: String
        let toolCalls: [ToolCall]
        let rawAssistantMessage: [String: Any]
    }

    private func streamCompletion(
        messages: [[String: Any]],
        onDelta: @escaping @Sendable (String) -> Void,
        onStreamReset: @escaping @Sendable () -> Void
    ) async throws -> CompletionResponse {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(appToken, forHTTPHeaderField: "x-app-token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": toolDefinitions,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("🔴 AskChat: OpenRouter error \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw AskChatError.badResponse("The assistant is unavailable right now. Please try again.")
        }

        var content = ""
        var pending = ""          // held until we know it's not structured JSON
        var decidedPlainText = false
        var suppress = false      // structured/tool round: never stream to UI
        var forwardedAny = false

        struct ToolAccumulator { var id = ""; var name = ""; var arguments = "" }
        var tools: [Int: ToolAccumulator] = [:]

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let chunk = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if chunk == "[DONE]" { break }
            guard let data = chunk.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let delta = (json["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any]
            else { continue }

            if let calls = delta["tool_calls"] as? [[String: Any]] {
                if forwardedAny { onStreamReset(); forwardedAny = false }
                suppress = true
                for call in calls {
                    let index = call["index"] as? Int ?? 0
                    var accumulator = tools[index] ?? ToolAccumulator()
                    if let id = call["id"] as? String { accumulator.id = id }
                    if let function = call["function"] as? [String: Any] {
                        if let name = function["name"] as? String { accumulator.name += name }
                        if let arguments = function["arguments"] as? String { accumulator.arguments += arguments }
                    }
                    tools[index] = accumulator
                }
            }

            if let piece = delta["content"] as? String, !piece.isEmpty {
                content += piece
                guard !suppress else { continue }
                if decidedPlainText {
                    // Guard: if the model appends a JSON envelope after prose (mixed output),
                    // forward the prose head and stop — don't stream raw JSON to the UI.
                    if let brace = piece.range(of: "{\"") {
                        let head = String(piece[..<brace.lowerBound])
                        if !head.isEmpty { onDelta(head) }
                        suppress = true
                    } else {
                        forwardedAny = true
                        onDelta(piece)
                    }
                } else {
                    pending += piece
                    let head = pending.trimmingCharacters(in: .whitespacesAndNewlines)
                    if head.hasPrefix("{") || head.hasPrefix("`") {
                        suppress = true // structured JSON: buffer silently
                    } else if !head.isEmpty {
                        decidedPlainText = true
                        forwardedAny = true
                        onDelta(pending)
                        pending = ""
                    }
                }
            }
        }

        let sortedTools = tools.sorted { $0.key < $1.key }.map(\.value)
        var rawAssistant: [String: Any] = ["role": "assistant", "content": content]
        if !sortedTools.isEmpty {
            rawAssistant["tool_calls"] = sortedTools.map {
                ["id": $0.id, "type": "function", "function": ["name": $0.name, "arguments": $0.arguments]]
            }
        }

        return CompletionResponse(
            content: content,
            toolCalls: sortedTools.map { CompletionResponse.ToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            rawAssistantMessage: rawAssistant
        )
    }

    // MARK: - Tool layer (local MCP-style tools over real app data)

    private var toolDefinitions: [[String: Any]] {
        func tool(_ name: String, _ description: String, _ properties: [String: Any], required: [String] = []) -> [String: Any] {
            [
                "type": "function",
                "function": [
                    "name": name,
                    "description": description,
                    "parameters": [
                        "type": "object",
                        "properties": properties,
                        "required": required
                    ]
                ]
            ]
        }
        return [
            tool("get_recent_transactions",
                 "Search the user's transactions (real data). Filter by category, merchant, or date range to find older transactions — do not assume something doesn't exist until you've searched with filters.",
                 [
                    "limit": ["type": "integer", "description": "Max rows, default 10, max 200"],
                    "category": ["type": "string", "description": "Only transactions whose category contains this text"],
                    "merchant": ["type": "string", "description": "Only transactions whose merchant contains this text"],
                    "from": ["type": "string", "description": "Only on/after this date, yyyy-MM-dd"],
                    "to": ["type": "string", "description": "Only on/before this date, yyyy-MM-dd"]
                 ]),
            tool("get_spending_by_category",
                 "Fetch the user's spending totals grouped by category (real data, full history available). Use before showing a spending table or chart.",
                 [
                    "period": ["type": "string", "enum": ["week", "month", "quarter", "year", "all"], "description": "Period to aggregate, default month"],
                    "from": ["type": "string", "description": "Custom range start, yyyy-MM-dd (overrides period)"],
                    "to": ["type": "string", "description": "Custom range end, yyyy-MM-dd"]
                 ]),
            tool("get_categories",
                 "Fetch the user's transaction categories (id, name, type). Use to suggest categories for a transaction draft.",
                 [:]),
            tool("compare_spending",
                 "Sum the user's spending for each named period (real data), optionally filtered to one category. Use for any comparison across time (this month vs last month, monthly trend). Returns one row per period; chart or stat the result.",
                 [
                    "category": ["type": "string", "description": "Only transactions whose category contains this text (optional)"],
                    "periods": [
                        "type": "array",
                        "description": "2-12 periods to compare",
                        "items": [
                            "type": "object",
                            "properties": [
                                "label": ["type": "string", "description": "Short display label, e.g. 'Aug 2025'"],
                                "from": ["type": "string", "description": "yyyy-MM-dd inclusive"],
                                "to": ["type": "string", "description": "yyyy-MM-dd inclusive"]
                            ],
                            "required": ["label", "from", "to"]
                        ]
                    ]
                 ],
                 required: ["periods"]),
            tool("get_budgets",
                 "Fetch the user's budgets (id, category, limit, period, currency, active, spent so far this period, remaining). Paused budgets are included with active=false. Real data — use before answering any budget question, and before proposing a budget edit or deletion (its \"id\" is the only valid target).",
                 [:]),
            tool("get_subscriptions",
                 "Fetch the user's recurring items / subscriptions (id, name, amount, currency, category, frequency, next due date, active, auto_add). Paused ones are included with active=false. Real data — use before answering any recurring/subscription question, and before proposing an edit or deletion (its \"id\" is the only valid target).",
                 [:]),
            tool("convert_currency",
                 "Convert an amount between currencies using the app's live rates. Use for any currency question — never estimate rates yourself.",
                 [
                    "amount": ["type": "number", "description": "Amount to convert"],
                    "from": ["type": "string", "description": "Source currency code, e.g. PHP"],
                    "to": ["type": "string", "description": "Target currency code, e.g. USD"]
                 ],
                 required: ["amount", "from", "to"])
        ]
    }

    private func executeTool(name: String, argumentsJSON: String, callID: String) -> String {
        let args = (try? JSONSerialization.jsonObject(with: Data(argumentsJSON.utf8)) as? [String: Any]) ?? [:]
        print("🛠️ AskChat: tool \(name) \(args)")

        switch name {
        case "get_recent_transactions":
            let limit = (args["limit"] as? Int) ?? 10
            let rows = recentTransactionRows(
                limit: min(max(limit, 1), 200),
                category: args["category"] as? String,
                merchant: args["merchant"] as? String,
                from: args["from"] as? String,
                to: args["to"] as? String
            )
            cachedRows[callID] = rows
            lastRows = rows
            return encodeRows(rows)

        case "get_spending_by_category":
            let period = (args["period"] as? String) ?? "month"
            let rows = spendingByCategoryRows(period: period, from: args["from"] as? String, to: args["to"] as? String)
            cachedRows[callID] = rows
            lastRows = rows
            return encodeRows(rows)

        case "get_categories":
            return encodeCategories()

        case "compare_spending":
            let category = args["category"] as? String
            let periods = (args["periods"] as? [[String: Any]]) ?? []
            let rows = comparisonRows(periods: periods, category: category)
            cachedRows[callID] = rows
            lastRows = rows
            return encodeRows(rows)

        case "get_budgets":
            let rows = budgetRows()
            cachedRows[callID] = rows
            lastRows = rows
            return encodeRows(rows)

        case "get_subscriptions":
            let rows = subscriptionRows()
            cachedRows[callID] = rows
            lastRows = rows
            return encodeRows(rows)

        case "convert_currency":
            guard let amount = args["amount"] as? Double,
                  let fromCode = args["from"] as? String,
                  let toCode = args["to"] as? String,
                  let from = Currency.allCases.first(where: { $0.rawValue.uppercased() == fromCode.uppercased() }),
                  let to = Currency.allCases.first(where: { $0.rawValue.uppercased() == toCode.uppercased() })
            else { return "{\"error\": \"unknown currency or missing amount\"}" }
            let converted = CurrencyRateManager.shared.convertAmount(amount, from: from, to: to)
            return "{\"amount\": \(amount), \"from\": \"\(from.rawValue)\", \"to\": \"\(to.rawValue)\", \"converted\": \(String(format: "%.2f", converted))}"

        default:
            return "{\"error\": \"unknown tool\"}"
        }
    }

    private func encodeRows(_ rows: [[String: String]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: ["rows": rows]),
              let string = String(data: data, encoding: .utf8) else { return "{\"rows\": []}" }
        return string
    }

    private func recentTransactionRows(limit: Int, category: String? = nil, merchant: String? = nil, from: String? = nil, to: String? = nil) -> [[String: String]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dayParser = DateFormatter()
        dayParser.dateFormat = "yyyy-MM-dd"
        let fromDate = from.flatMap { dayParser.date(from: $0) }
        // "to" is inclusive: push to the end of that day.
        let toDate = to.flatMap { dayParser.date(from: $0) }.map { $0.addingTimeInterval(86_399) }

        return UserManager.shared.currentUser.transactions
            .filter { txn in
                if let category, !txn.category.localizedCaseInsensitiveContains(category) { return false }
                if let merchant, !(txn.merchantName ?? "").localizedCaseInsensitiveContains(merchant) { return false }
                if let fromDate, txn.date < fromDate { return false }
                if let toDate, txn.date > toDate { return false }
                return true
            }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { txn in
                [
                    "id": txn.txID.uuidString,
                    "date": formatter.string(from: txn.date),
                    "merchant": txn.merchantName ?? txn.category,
                    "category": txn.category,
                    "amount": String(format: "%.2f", txn.amount)
                ]
            }
    }

    private func spendingByCategoryRows(period: String, from: String? = nil, to: String? = nil) -> [[String: String]] {
        let calendar = Calendar.current
        let dayParser = DateFormatter()
        dayParser.dateFormat = "yyyy-MM-dd"

        let cutoff: Date
        switch period.lowercased() {
        case "week": cutoff = calendar.date(byAdding: .day, value: -7, to: Date())!
        case "quarter": cutoff = calendar.date(byAdding: .month, value: -3, to: Date())!
        case "year": cutoff = calendar.date(byAdding: .year, value: -1, to: Date())!
        case "all": cutoff = .distantPast
        default: cutoff = calendar.date(byAdding: .month, value: -1, to: Date())!
        }
        let fromDate = from.flatMap { dayParser.date(from: $0) } ?? cutoff
        let toDate = to.flatMap { dayParser.date(from: $0) }.map { $0.addingTimeInterval(86_399) } ?? .distantFuture

        let expenses = UserManager.shared.currentUser.transactions
            .filter { $0.date >= fromDate && $0.date <= toDate && $0.amount < 0 }
        var grouped = Dictionary(grouping: expenses, by: { $0.category })
            .mapValues { txns in (amount: txns.reduce(0) { $0 + abs($1.amount) }, count: txns.count) }
        // Fold in tracked subscriptions not already materialized as transactions.
        for occ in subscriptionOccurrences(from: fromDate, to: toDate, category: nil) {
            var entry = grouped[occ.category] ?? (amount: 0, count: 0)
            entry.amount += abs(occ.amount)
            entry.count += 1
            grouped[occ.category] = entry
        }
        return grouped
            .map { (category, agg) in (category, agg.amount, agg.count) }
            .sorted { $0.1 > $1.1 }
            .map { ["category": $0.0, "amount": String(format: "%.2f", $0.1), "count": "\($0.2)"] }
    }

    /// Virtual expense occurrences from tracked subscriptions that aren't already real transactions.
    /// Subscriptions live in SubscriptionManager, not in currentUser.transactions — only auto-add
    /// subs (once due) get materialized. This projects the rest (and any due-but-not-yet-generated
    /// dates) so AI spending sums include recurring subscription costs. Days already covered by a
    /// real subscription-linked txn are skipped (no double count). Occurrences after now are excluded
    /// to match materialized-transaction behavior.
    private func subscriptionOccurrences(from: Date, to: Date, category: String?) -> [(date: Date, category: String, amount: Double)] {
        let now = Date()
        let upperBound = min(to, now)
        guard from <= upperBound else { return [] }

        let calendar = Calendar.current
        let realTxns = UserManager.shared.currentUser.transactions
        var result: [(date: Date, category: String, amount: Double)] = []

        for sub in SubscriptionManager.persistedSubscriptions() {
            guard sub.isActive else { continue }
            if let category, !sub.category.localizedCaseInsensitiveContains(category) { continue }
            // Spending tools only sum expenses — skip income subscriptions.
            if subscriptionIsIncome(sub) { continue }

            // Days already materialized as real txns for this subscription.
            let coveredDays = Set(realTxns
                .filter { $0.subscriptionId == sub.id }
                .map { calendar.startOfDay(for: $0.date) })

            var occurrence = sub.createdAt
            var steps = 0
            while occurrence <= upperBound && steps < 2000 {
                steps += 1
                if occurrence >= from, !coveredDays.contains(calendar.startOfDay(for: occurrence)) {
                    result.append((date: occurrence, category: sub.category, amount: -abs(sub.amount)))
                }
                occurrence = sub.frequency.nextOccurrence(from: occurrence)
            }
        }
        return result
    }

    /// Mirror of SubscriptionManager's income detection (that method is private there).
    private func subscriptionIsIncome(_ sub: Subscription) -> Bool {
        let cm = CategoriesManager.shared
        if let catId = sub.categoryId, let r = cm.findCategoryOrSubcategoryById(catId) {
            if let c = r.category { return c.type == .income }
            if let s = r.subcategory { return s.type == .income }
        }
        let r = cm.findCategoryOrSubcategory(by: sub.category)
        if let c = r.category { return c.type == .income }
        if let s = r.subcategory { return s.type == .income }
        return false
    }

    private func comparisonRows(periods: [[String: Any]], category: String?) -> [[String: String]] {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let transactions = UserManager.shared.currentUser.transactions
        return periods.prefix(12).compactMap { period in
            guard let label = period["label"] as? String,
                  let fromString = period["from"] as? String, let from = parser.date(from: fromString),
                  let toString = period["to"] as? String, let to = parser.date(from: toString)?.addingTimeInterval(86_399)
            else { return nil }
            let matching = transactions.filter { txn in
                guard txn.amount < 0, txn.date >= from, txn.date <= to else { return false }
                if let category, !txn.category.localizedCaseInsensitiveContains(category) { return false }
                return true
            }
            let subs = subscriptionOccurrences(from: from, to: to, category: category)
            let total = matching.reduce(0) { $0 + abs($1.amount) } + subs.reduce(0) { $0 + abs($1.amount) }
            return ["label": label, "amount": String(format: "%.2f", total), "count": "\(matching.count + subs.count)"]
        }
    }

    private func budgetRows() -> [[String: String]] {
        let calendar = Calendar.current
        let now = Date()
        // Paused budgets are listed too (with active=false) — otherwise the model
        // could pause one and never see it again to resume it.
        return UserManager.shared.currentUser.budgets
            .map { budget in
                // Spent = expenses in this budget's category over the current period.
                let periodStart: Date
                switch budget.period.rawValue.lowercased() {
                case "daily": periodStart = calendar.startOfDay(for: now)
                case "weekly": periodStart = calendar.date(byAdding: .day, value: -7, to: now)!
                case "yearly": periodStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
                default: periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                }
                let spent = UserManager.shared.currentUser.transactions
                    .filter { $0.categoryId == budget.categoryId && $0.amount < 0 && $0.date >= periodStart }
                    .reduce(0) { $0 + abs($1.amount) }
                return [
                    "id": budget.id.uuidString,
                    "category": budget.categoryName,
                    "category_id": budget.categoryId.uuidString,
                    "period": budget.period.rawValue,
                    "currency": budget.currency.rawValue,
                    "active": budget.isActive ? "true" : "false",
                    "limit": String(format: "%.2f", budget.amount),
                    "spent": String(format: "%.2f", spent),
                    "remaining": String(format: "%.2f", budget.amount - spent)
                ]
            }
    }

    private func subscriptionRows() -> [[String: String]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return SubscriptionManager.persistedSubscriptions()
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .map { sub in
                [
                    "id": sub.id.uuidString,
                    "name": sub.name,
                    "amount": String(format: "%.2f", sub.amount),
                    "currency": sub.currency.rawValue,
                    "category": sub.category,
                    "frequency": sub.frequency.rawValue,
                    "next_due": formatter.string(from: sub.nextDueDate),
                    "active": sub.isActive ? "true" : "false",
                    "auto_add": sub.autoAddTransaction ? "true" : "false"
                ]
            }
    }

    private func encodeCategories() -> String {
        let categories = CategoriesManager.shared.categories
            .filter { !$0.isDeleted }
            .map { ["id": $0.id.uuidString, "name": $0.name, "type": $0.type.rawValue] }
        guard let data = try? JSONSerialization.data(withJSONObject: ["categories": categories]),
              let string = String(data: data, encoding: .utf8) else { return "{\"categories\": []}" }
        return string
    }

    // MARK: - Confirmed write (user-initiated only — never callable by the model)

    /// Creates the transaction after the user taps Confirm on a draft card.
    func createTransaction(amount: Double, currency: Currency, merchant: String?, date: Date, note: String?, categoryId: UUID?) {
        var categoryName = "No Category"
        var isIncome = false
        var finalCategoryId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // No Category (Expense)

        if let categoryId, let result = CategoriesManager.shared.findCategoryOrSubcategoryById(categoryId) {
            if let category = result.category {
                categoryName = category.name
                isIncome = category.type == .income
                finalCategoryId = categoryId
            } else if let subcategory = result.subcategory {
                categoryName = subcategory.name
                isIncome = subcategory.type == .income
                finalCategoryId = categoryId
            }
        }

        let walletID = AccountManager.shared.selectedSubAccountId ?? UserManager.shared.currentUser.defaultSubAccount?.id
        let transaction = CurrencyRateManager.shared.createTransaction(
            accountID: UserManager.shared.currentUser.id,
            walletID: walletID,
            category: categoryName,
            categoryId: finalCategoryId,
            originalAmount: amount,
            originalCurrency: currency,
            date: date,
            merchantName: merchant,
            note: note,
            isIncome: isIncome
        )
        UserManager.shared.addTransaction(transaction)
        print("✅ AskChat: transaction created — \(categoryName) \(amount) \(currency.rawValue)")
    }

    /// Applies a confirmed edit to an existing transaction. Rebuilds via the
    /// rate manager so amount sign and currency conversion stay correct, then
    /// preserves the original identity fields. Returns false if the target
    /// transaction no longer exists.
    func updateTransaction(txID: UUID, amount: Double?, currency: Currency?, merchant: String?, date: Date?, note: String?, categoryId: UUID?) -> Bool {
        guard let existing = UserManager.shared.currentUser.transactions.first(where: { $0.txID == txID }) else {
            return false
        }

        var categoryName = existing.category
        var finalCategoryId = existing.categoryId
        var isIncome = existing.amount > 0
        if let categoryId, let result = CategoriesManager.shared.findCategoryOrSubcategoryById(categoryId) {
            if let category = result.category {
                categoryName = category.name
                isIncome = category.type == .income
                finalCategoryId = categoryId
            } else if let subcategory = result.subcategory {
                categoryName = subcategory.name
                isIncome = subcategory.type == .income
                finalCategoryId = categoryId
            }
        }

        let newAmount = amount ?? abs(existing.originalAmount ?? existing.amount)
        let newCurrency = currency ?? existing.originalCurrency ?? existing.primaryCurrency

        let rebuilt = CurrencyRateManager.shared.createTransaction(
            accountID: existing.accountID,
            walletID: existing.walletID,
            category: categoryName,
            categoryId: finalCategoryId,
            originalAmount: newAmount,
            originalCurrency: newCurrency,
            date: date ?? existing.date,
            merchantName: merchant ?? existing.merchantName,
            note: note ?? existing.note,
            isIncome: isIncome
        )

        let updated = Txn(
            txID: existing.txID,
            accountID: existing.accountID,
            walletID: existing.walletID,
            category: rebuilt.category,
            categoryId: rebuilt.categoryId,
            amount: rebuilt.amount,
            date: rebuilt.date,
            createdAt: existing.createdAt,
            receiptImage: nil,
            hasReceiptImage: existing.hasReceiptImage,
            merchantName: rebuilt.merchantName,
            paymentMethod: existing.paymentMethod,
            receiptNumber: existing.receiptNumber,
            invoiceNumber: existing.invoiceNumber,
            items: existing.items,
            note: rebuilt.note,
            originalAmount: rebuilt.originalAmount,
            originalCurrency: rebuilt.originalCurrency,
            primaryCurrency: rebuilt.primaryCurrency,
            secondaryCurrency: rebuilt.secondaryCurrency,
            exchangeRate: rebuilt.exchangeRate,
            secondaryAmount: rebuilt.secondaryAmount,
            secondaryExchangeRate: rebuilt.secondaryExchangeRate,
            userEnteredAmount: rebuilt.userEnteredAmount,
            userEnteredCurrency: rebuilt.userEnteredCurrency,
            isRecurring: existing.isRecurring,
            recurringFrequency: existing.recurringFrequency,
            recurringTemplateId: existing.recurringTemplateId,
            lastGeneratedDate: existing.lastGeneratedDate,
            isRecurringActive: existing.isRecurringActive
        )
        UserManager.shared.updateTransaction(updated)
        print("✅ AskChat: transaction updated — \(updated.category) \(updated.amount)")
        return true
    }

    // MARK: - Confirmed budget writes (user-initiated only)

    enum BudgetWriteError: LocalizedError {
        case noWallet
        case unknownCategory
        case notFound

        var errorDescription: String? {
            switch self {
            case .noWallet: return "Pick a wallet first, then try again."
            case .unknownCategory: return "That category no longer exists."
            case .notFound: return "That budget no longer exists."
            }
        }
    }

    /// Budgets are scoped to a parent category — a subcategory id folds up to
    /// its parent so the budget covers the whole group (as the Budgets page does).
    func resolveBudgetCategory(_ categoryId: UUID) -> (id: UUID, name: String)? {
        guard let result = CategoriesManager.shared.findCategoryOrSubcategoryById(categoryId) else { return nil }
        if let category = result.category { return (category.id, category.name) }
        if let parent = result.parent { return (parent.id, parent.name) }
        if let subcategory = result.subcategory { return (subcategory.id, subcategory.name) }
        return nil
    }

    /// Creates the budget after the user taps Confirm on a budget draft card.
    func createBudget(categoryId: UUID, amount: Double, currency: Currency, period: BudgetPeriod, applyToAllPeriods: Bool) throws -> Budget {
        guard let walletId = AccountManager.shared.selectedSubAccountId ?? UserManager.shared.currentUser.defaultSubAccount?.id else {
            throw BudgetWriteError.noWallet
        }
        guard let category = resolveBudgetCategory(categoryId) else {
            throw BudgetWriteError.unknownCategory
        }

        let budget = Budget(
            walletId: walletId,
            categoryId: category.id,
            categoryName: category.name,
            amount: amount,
            currency: currency,
            period: period,
            applyToAllPeriods: applyToAllPeriods
        )
        UserManager.shared.addBudget(budget)
        AnalyticsManager.shared.track(.budgetCreated, properties: [
            "category": category.name,
            "amount": amount,
            "currency": currency.rawValue,
            "period": period.rawValue,
            "apply_to_all_periods": applyToAllPeriods,
            "source": "ask_chat"
        ])
        print("✅ AskChat: budget created — \(category.name) \(amount) \(currency.rawValue)/\(period.rawValue)")
        return budget
    }

    /// Applies a confirmed edit to an existing budget. Only the supplied fields change.
    @discardableResult
    func updateBudget(id: UUID, amount: Double?, currency: Currency?, period: BudgetPeriod?, isActive: Bool?) throws -> Budget {
        guard let existing = UserManager.shared.currentUser.budgets.first(where: { $0.id == id }) else {
            throw BudgetWriteError.notFound
        }
        let updated = Budget(
            id: existing.id,
            walletId: existing.walletId,
            categoryId: existing.categoryId,
            categoryName: existing.categoryName,
            amount: amount ?? existing.amount,
            currency: currency ?? existing.currency,
            period: period ?? existing.period,
            applyToAllPeriods: existing.applyToAllPeriods,
            isActive: isActive ?? existing.isActive,
            createdAt: existing.createdAt
        )
        UserManager.shared.updateBudget(updated)
        print("✅ AskChat: budget updated — \(updated.categoryName) \(updated.amount) \(updated.currency.rawValue)/\(updated.period.rawValue)")
        return updated
    }

    /// Deletes a confirmed budget. Returns the removed budget for the receipt line.
    @discardableResult
    func deleteBudget(id: UUID) throws -> Budget {
        guard let existing = UserManager.shared.currentUser.budgets.first(where: { $0.id == id }) else {
            throw BudgetWriteError.notFound
        }
        UserManager.shared.deleteBudget(withId: id)
        print("🗑️ AskChat: budget deleted — \(existing.categoryName)")
        return existing
    }

    // MARK: - Confirmed recurring/subscription writes (user-initiated only)

    enum SubscriptionWriteError: LocalizedError {
        case notFound

        var errorDescription: String? {
            switch self {
            case .notFound: return "That recurring item no longer exists."
            }
        }
    }

    /// Category for a recurring item: a real category if the id resolves, else
    /// the app's own "Subscriptions" bucket (what AddSubscriptionSheet defaults to).
    private func resolveSubscriptionCategory(_ categoryId: UUID?) -> (id: UUID?, name: String) {
        guard let categoryId, let result = CategoriesManager.shared.findCategoryOrSubcategoryById(categoryId) else {
            return (nil, "Subscriptions")
        }
        if let subcategory = result.subcategory { return (categoryId, subcategory.name) }
        if let category = result.category { return (categoryId, category.name) }
        return (nil, "Subscriptions")
    }

    /// Creates the recurring item after the user taps Confirm. Free-tier capacity
    /// is checked by the caller (it shows the paywall instead).
    @MainActor
    @discardableResult
    func createSubscription(
        name: String,
        amount: Double,
        currency: Currency,
        categoryId: UUID?,
        frequency: RecurringFrequency,
        startDate: Date,
        autoAdd: Bool,
        note: String?
    ) -> Subscription {
        let category = resolveSubscriptionCategory(categoryId)
        let subscription = Subscription(
            name: name,
            amount: amount,
            currency: currency,
            categoryId: category.id,
            category: category.name,
            frequency: frequency,
            // Same convention as AddSubscriptionSheet: the first charge lands on
            // the start date, so the NEXT one is one interval later.
            nextDueDate: frequency.nextOccurrence(from: startDate),
            autoAddTransaction: autoAdd,
            walletId: AccountManager.shared.selectedSubAccountId ?? AccountManager.shared.currentSubAccount?.id,
            note: note,
            createdAt: startDate
        )
        SubscriptionManager.shared.addSubscription(subscription)
        AnalyticsManager.shared.track(.subscriptionCreated, properties: [
            "name": name,
            "amount": amount,
            "currency": currency.rawValue,
            "frequency": frequency.rawValue,
            "auto_add": autoAdd,
            "source": "ask_chat"
        ])
        print("✅ AskChat: subscription created — \(name) \(amount) \(currency.rawValue)/\(frequency.rawValue)")
        return subscription
    }

    /// Applies a confirmed edit. Only the supplied fields change; changing the
    /// frequency re-bases the next due date so it can't sit in the old cadence.
    @MainActor
    @discardableResult
    func updateSubscription(
        id: UUID,
        name: String?,
        amount: Double?,
        currency: Currency?,
        categoryId: UUID?,
        frequency: RecurringFrequency?,
        nextDueDate: Date?,
        autoAdd: Bool?,
        isActive: Bool?,
        note: String?
    ) throws -> Subscription {
        guard var subscription = SubscriptionManager.shared.subscriptions.first(where: { $0.id == id }) else {
            throw SubscriptionWriteError.notFound
        }

        if let name { subscription.name = name }
        if let amount { subscription.amount = amount }
        if let currency { subscription.currency = currency }
        if let categoryId {
            let category = resolveSubscriptionCategory(categoryId)
            subscription.categoryId = category.id
            subscription.category = category.name
        }
        if let frequency, frequency != subscription.frequency {
            subscription.frequency = frequency
            subscription.nextDueDate = frequency.nextOccurrence(from: subscription.lastGeneratedDate ?? Date())
        }
        if let nextDueDate { subscription.nextDueDate = nextDueDate }
        if let autoAdd { subscription.autoAddTransaction = autoAdd }
        if let isActive { subscription.isActive = isActive }
        if let note { subscription.note = note }

        SubscriptionManager.shared.updateSubscription(subscription)
        print("✅ AskChat: subscription updated — \(subscription.name) \(subscription.amount) \(subscription.frequency.rawValue)")
        return subscription
    }

    /// Deletes a confirmed recurring item. Returns it for the receipt line.
    @MainActor
    @discardableResult
    func deleteSubscription(id: UUID) throws -> Subscription {
        guard let subscription = SubscriptionManager.shared.subscriptions.first(where: { $0.id == id }) else {
            throw SubscriptionWriteError.notFound
        }
        SubscriptionManager.shared.deleteSubscription(subscription)
        return subscription
    }

    // MARK: - System prompt

    private var systemPrompt: String {
        let today = ISO8601DateFormatter.askDateOnly.string(from: Date())
        let currency = CurrencyPreferences.shared.primaryCurrency.rawValue
        return """
        You are Cashmonki's finance assistant inside a personal expense-tracking app. Today's date is \(today). The user's primary currency is \(currency).

        Your replies must be EXACTLY ONE of these JSON message types (raw JSON only, no markdown fences, no extra prose):

        1. {"type": "text", "text": "..."} — normal answers, anything conversational. When you ask the user to DECIDE something (disambiguation, yes/no, picking between options), add "choices": ["...", "..."] with 2-4 short tappable answers.

        2. {"type": "table", "title": "...", "columns": [{"key": "...", "label": "...", "align": "left|right", "format": "currency"?}]} — when showing transactions or spending data. RULES: you MUST call a data tool first (get_recent_transactions or get_spending_by_category); pick column keys from the tool result's row keys; do NOT include rows — the app fills them from the tool result; money columns get "align": "right" and "format": "currency". Never invent, recall, or estimate numbers yourself — no tool result, no table.

        3. {"type": "transaction_draft", "amount": 12.5, "currency": "\(currency)", "merchant": "...", "date": "yyyy-MM-dd", "note": "...", "suggested_categories": [{"id": "...", "name": "...", "confidence": 0.9}]} — when the user asks to add/log a transaction (e.g. "add $12 lunch at Chipotle yesterday"). RULES: amount is required — if it's missing or ambiguous, reply with a short text question instead of guessing; date defaults to today, resolve words like "yesterday"; note only if the user said something worth keeping; call get_categories first and suggest the best 1-3 matches from the REAL list (use their exact ids and names — never make up categories). You never create the transaction yourself — the app asks the user to confirm.

        3b. {"type": "transaction_draft_batch", "title": "Grocery run", "transactions": [{...}, {...}]} — when the user asks to log SEVERAL transactions in one go (e.g. "add 300 vegetables, 150 milk and 90 bread"). Each entry follows the transaction_draft schema above (2-10 of them, each needs its own amount and suggested_categories). The app renders one card with a row per transaction, each addable on its own plus an Add all button. Use a single transaction_draft when there's only one.

        5. {"type": "transaction", "transaction_ids": ["...", "..."]} — when the user asks to see 1 to 3 specific transactions (e.g. "show my last grab ride"). Call get_recent_transactions first and use the exact "id" values from the tool result. The app renders the transaction cards itself. For 4 or more transactions use a table instead — never this type.

        4. {"type": "transaction_update", "transaction_id": "...", "amount": 150, "currency": "...", "merchant": "...", "date": "yyyy-MM-dd", "note": "...", "category_id": "..."} — when the user asks to change/edit existing transactions (e.g. "change that Jollibee lunch to 150"). For the SAME change applied to several transactions (e.g. "move all my Grab rides to Transportation"), use "transaction_ids": ["...", "..."] (max 10) instead of transaction_id. RULES: call get_recent_transactions first and use the exact "id" values from the tool result — never invent ids; include ONLY the fields being changed, omit everything else; if a category change is requested, also call get_categories and use its exact id; if it's unclear which transactions the user means, ask a short text question instead of guessing. Different changes to different transactions = separate turns. The app shows the change and asks the user to confirm — you never apply it yourself. Never include the "id" column when showing tables.

        6. {"type": "transaction_delete", "transaction_ids": ["...", "..."]} — when the user asks to delete/remove transactions (max 10). RULES: call get_recent_transactions first and use exact "id" values — never invent ids; if it's unclear which transactions the user means, ask a short text question. The app shows the transactions and asks the user to confirm — you never delete anything yourself.

        7. {"type": "chart", "title": "...", "limit": 5?} — when the user asks for a visual/chart/graph of spending, or when a ranked category/merchant comparison reads better as bars than a table. RULES: you MUST call a data tool first (usually get_spending_by_category); do NOT include items or values — the app builds the bars from the tool result. Keep the title short, e.g. "July spending". If the user asks for a top N ("top 5 categories"), set "limit": N — the app keeps the N largest rows. Tables support "limit" the same way. For comparisons across time periods, call compare_spending first — its rows chart as one bar per period (or use a stat for a simple two-period comparison).

        8. {"type": "stat", "title": "July spending", "value": 22722, "compare_value": 25900?, "compare_label": "June"?, "good_direction": "down"?} — when the user asks for a single headline number ("how much did I spend this month?", "am I overspending?"). RULES: call a data tool first and compute value (and compare_value if comparing periods) strictly from tool results; good_direction is "down" for spending metrics, "up" for income/savings; the app computes and renders the percentage itself.

        9. {"type": "category_draft", "name": "Fast Food", "emoji": "🍔", "parent": "Dining"?, "category_type": "expense"} — when the user asks for category ideas, wants to organize their spending, or a transaction clearly fits no existing category. RULES: call get_categories first and only suggest something that does NOT already exist; "parent" must be an EXACT existing category name (omit for a top-level category); one suggestion per message; pick a fitting emoji. The app asks the user to confirm and handles the Pro paywall — you never create it yourself.

        10. {"type": "budget_draft", "category_id": "...", "category_name": "Food", "amount": 5000, "currency": "\(currency)", "period": "monthly", "apply_to_all_periods": true} — when the user asks to set/create a budget (e.g. "budget 5000 a month for food"). RULES: call get_categories first and use an exact id from it; call get_budgets too and, if that category already has a budget, propose a budget_update instead of a second budget; period is one of daily, weekly, monthly, quarterly, yearly (default monthly); if the amount or the category is unclear, ask a short text question instead of guessing. The app asks the user to confirm — you never create it yourself.

        11. {"type": "budget_update", "budget_id": "...", "amount": 6000, "currency": "...", "period": "monthly", "is_active": true} — when the user asks to change an existing budget (e.g. "raise my food budget to 6000", "pause my shopping budget"). For the SAME change across several budgets use "budget_ids": ["...", "..."] (max 10). RULES: call get_budgets first and use its exact "id" values — never invent ids; include ONLY the fields being changed; is_active false pauses a budget instead of deleting it. The app asks the user to confirm.

        12. {"type": "budget_delete", "budget_ids": ["...", "..."]} — when the user asks to remove/delete budgets (max 10). RULES: call get_budgets first and use exact "id" values; if it's unclear which budget they mean, ask a short text question. The app asks the user to confirm — you never delete anything yourself. Prefer budget_update with "is_active": false when the user says pause or stop rather than delete.

        13. {"type": "subscription_draft", "name": "Netflix", "amount": 549, "currency": "\(currency)", "category_id": "...", "frequency": "monthly", "start_date": "yyyy-MM-dd", "auto_add": true, "note": "..."} — when the user asks to track something recurring (e.g. "add my Netflix, 549 monthly", "I pay 2000 rent every month"). RULES: call get_subscriptions first and, if that item already exists, propose a subscription_update instead of a duplicate; call get_categories and use an exact id (omit category_id and it files under Subscriptions); frequency is daily, weekly, monthly, quarterly or yearly (default monthly); start_date defaults to today; auto_add true means each due date creates the transaction for them. If the amount or how often is unclear, ask a short text question. The app asks the user to confirm and handles the free-plan limit.

        14. {"type": "subscription_update", "subscription_id": "...", "amount": 649, "name": "...", "frequency": "...", "next_due_date": "yyyy-MM-dd", "category_id": "...", "auto_add": true, "is_active": true, "note": "..."} — when the user asks to change a recurring item ("Netflix went up to 649", "move my rent to the 5th", "stop auto adding my gym"). For the SAME change across several use "subscription_ids": ["...", "..."] (max 10). RULES: call get_subscriptions first and use its exact "id" values — never invent ids; include ONLY the fields being changed; is_active false pauses it, which is what "pause", "stop tracking" or "cancel for now" should map to.

        15. {"type": "subscription_delete", "subscription_ids": ["...", "..."]} — when the user asks to remove recurring items for good (max 10). RULES: call get_subscriptions first and use exact "id" values; prefer subscription_update with "is_active": false unless they clearly want it gone. The app asks the user to confirm.

        For currency questions ("how much is 4600 PHP in USD?"), call convert_currency and answer with a text message using its result — never estimate exchange rates yourself.

        Table, chart, and stat messages may include "followups": ["...", "..."] — 2-3 short suggested next questions the user might tap (e.g. "Top 5 only", "Compare to last month"). Text replies may use simple markdown (**bold**, *italic*); no headings or code blocks.

        Anything you output that doesn't match these schemas will be shown as plain text. Keep text replies short and friendly. Never use em dashes (—) in your text; use commas or periods instead.

        CRITICAL: Output ONE JSON object and nothing else — no prose or explanation before or after it, and never repeat the same answer as both prose and a JSON object. When you ask a question, put ALL of your wording inside the "text" field of a single {"type": "text", "text": "...", "choices": ["...", "..."]} object; do not write the question as prose and then also emit JSON.

        CRITICAL: The conversation history may contain parenthetical app records like (App rendered a transaction confirmation card for 100 PHP Coffee, awaiting the user's Confirm.). These describe UI the app ALREADY showed — they are NOT a reply format and NOT an example for you to follow. NEVER copy, echo, or paraphrase them, and never write a bracketed or parenthetical draft marker yourself. To propose a transaction you MUST emit a fresh {"type": "transaction_draft", ...} JSON object with real values.

        CRITICAL: Never show a raw id ("id", "budget_id", "category_id") as a table column — ids are for targeting, not for reading.

        CRITICAL: History may contain PENDING card records like (App is showing a PENDING transaction card, not saved yet: 100 PHP Coffee.). Those propose something the user has NOT approved — nothing was written. If the user then asks to change one ("make it 150", "that's food not coffee", "drop the milk one"), emit a FRESH card of the same type carrying the FULL corrected proposal — every field the pending card had, not just the changed one, INCLUDING suggested_categories (call get_categories again if you need the ids). A revision that drops the category loses it. The app replaces the pending card with your new one. Never answer such a request with text alone claiming it was updated, and never treat a pending card as saved data.

        CRITICAL: History may also contain app confirmation lines like "✅ Added 100 PHP to Coffee.", "🗑️ Deleted 2 transactions.", or "✅ Added 🍔 Fast Food as a new category." — these are the APP's record of an action the user ALREADY approved by tapping Confirm on a card. You never complete actions yourself. NEVER write a "✅ Added...", "🗑️ Deleted...", or similar completion line — doing so falsely tells the user something was saved when nothing was. To act, emit the matching draft/update/delete JSON and let the app confirm and record it.
        """
    }
}

private extension ISO8601DateFormatter {
    static let askDateOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
