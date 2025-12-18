import Foundation
import UIKit

// MARK: - Receipt Analysis Models

struct ReceiptAnalysis {
    let merchantName: String
    let totalAmount: Double
    let date: Date
    let category: String
    let paymentMethod: String
    let currency: Currency
    let items: [ReceiptItem]
    let rawText: String
}

// MARK: - OpenRouter Integration

class AIReceiptAnalyzer {
    static let shared = AIReceiptAnalyzer()
    
    // Legacy direct API (deprecated)
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    
    // New secure backend service (lazy to prevent early Firebase access)
    private lazy var backendService = BackendAPIService.shared
    
    private init() {}
    
    // MARK: - Date Parsing
    
    /// Smart date parser that handles multiple receipt date/time formats
    static func parseReceiptDate(_ dateString: String, fallbackTime: Date? = nil) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let formatters: [(DateFormatter, String)] = [
            // Date + Time formats (24-hour)
            (createFormatter("yyyy-MM-dd HH:mm"), "Full date+time (24h)"),
            (createFormatter("yyyy-MM-dd HH:mm:ss"), "Full date+time with seconds"),
            (createFormatter("dd/MM/yyyy HH:mm"), "European date+time"),
            (createFormatter("MM/dd/yyyy HH:mm"), "US date+time"),
            (createFormatter("dd-MM-yyyy HH:mm"), "Dash European date+time"),
            (createFormatter("MM-dd-yyyy HH:mm"), "Dash US date+time"),
            
            // Date + Time formats (12-hour with AM/PM)
            (createFormatter("yyyy-MM-dd h:mm a"), "Date+time 12h AM/PM"),
            (createFormatter("dd/MM/yyyy h:mm a"), "European date+time 12h"),
            (createFormatter("MM/dd/yyyy h:mm a"), "US date+time 12h"),
            
            // Date only formats (will default to 12:00 PM for user visibility)
            (createFormatter("yyyy-MM-dd"), "ISO date only"),
            (createFormatter("dd/MM/yyyy"), "European date only"),
            (createFormatter("MM/dd/yyyy"), "US date only"),
            (createFormatter("dd-MM-yyyy"), "Dash European date only"),
            (createFormatter("MM-dd-yyyy"), "Dash US date only")
        ]
        
        for (formatter, description) in formatters {
            if let parsedDate = formatter.date(from: trimmed) {
                print("📅 AIReceiptAnalyzer: Successfully parsed '\(trimmed)' using \(description) -> \(parsedDate)")
                
                // If it's a date-only format (no time component), use fallback time or noon
                if description.contains("date only") {
                    let calendar = Calendar.current
                    let dateComponents = calendar.dateComponents([.year, .month, .day], from: parsedDate)
                    
                    if let fallbackTime = fallbackTime {
                        // Use the time from fallback (creation time) with the receipt date
                        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: fallbackTime)
                        var newComponents = dateComponents
                        newComponents.hour = timeComponents.hour
                        newComponents.minute = timeComponents.minute
                        newComponents.second = timeComponents.second
                        let adjustedDate = calendar.date(from: newComponents) ?? parsedDate
                        print("📅 AIReceiptAnalyzer: Using receipt date with creation time: \(adjustedDate)")
                        return adjustedDate
                    } else {
                        // Default to noon if no fallback provided
                        var newComponents = dateComponents
                        newComponents.hour = 12
                        newComponents.minute = 0
                        let adjustedDate = calendar.date(from: newComponents) ?? parsedDate
                        print("📅 AIReceiptAnalyzer: Adjusted date-only to noon: \(adjustedDate)")
                        return adjustedDate
                    }
                }
                
                return parsedDate
            }
        }
        
        print("⚠️ AIReceiptAnalyzer: Could not parse date '\(trimmed)', using current date/time")
        return nil
    }
    
    /// Helper to create a date formatter with locale settings
    private static func createFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX") // Consistent parsing
        formatter.timeZone = TimeZone.current // Use user's timezone
        return formatter
    }
    
    private var apiKey: String? {
        return Config.openRouterAPIKey
    }
    
    /// Analyze receipt using secure backend (recommended for production)
    func analyzeReceiptSecure(image: UIImage, creationTime: Date = Date()) async throws -> ReceiptAnalysis {
        print("🔒 Starting secure receipt analysis via backend...")
        print("📸 Image dimensions: \(image.size.width) x \(image.size.height)")

        // Resize image more aggressively for backend (smaller = faster upload, less "message too long" errors)
        let resizedImage = resizeImageForBackend(image)

        // Use more aggressive compression for network transfer
        // Start with 0.5 quality and reduce if still too large
        var compressionQuality: CGFloat = 0.5
        var imageData = resizedImage.jpegData(compressionQuality: compressionQuality)

        // If image is still too large (>500KB), compress more aggressively
        let maxSizeBytes = 500_000 // 500KB limit for reliable network transfer
        while let data = imageData, data.count > maxSizeBytes, compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
            print("📐 Reducing compression to \(compressionQuality): \(data.count) bytes")
        }

        guard let finalImageData = imageData else {
            throw ReceiptAIError.imageProcessingFailed
        }

        print("📦 Final image size: \(finalImageData.count) bytes (\(String(format: "%.1f", Double(finalImageData.count) / 1024))KB) at \(String(format: "%.0f", compressionQuality * 100))% quality")

        // Use secure backend service
        let backendResult = try await backendService.analyzeReceipt(imageData: finalImageData)
        
        // Convert backend result to ReceiptAnalysis
        // Parse detected currency from backend or fallback to user's primary currency
        let detectedCurrency = Currency.allCases.first { $0.rawValue.uppercased() == (backendResult.currency?.uppercased() ?? "") } ?? CurrencyPreferences.shared.primaryCurrency
        
        print("💱 AIReceiptAnalyzer: Backend detected currency: '\(backendResult.currency ?? "none")'")
        print("💱 AIReceiptAnalyzer: Mapped to Currency enum: \(detectedCurrency.rawValue)")
        
        let analysis = ReceiptAnalysis(
            merchantName: backendResult.merchantName,
            totalAmount: backendResult.amount,
            date: backendResult.date,
            category: backendResult.category,
            paymentMethod: "Unknown", // Backend doesn't provide this yet
            currency: detectedCurrency,
            items: backendResult.items.map { ReceiptItem(description: $0.name, quantity: $0.quantity, unitPrice: $0.price, totalPrice: $0.price * Double($0.quantity)) },
            rawText: "Processed via secure backend"
        )
        
        print("✅ Secure receipt analysis completed: \(analysis.merchantName) - \(analysis.totalAmount)")
        return analysis
    }
    
    /// Legacy direct API method (deprecated - use analyzeReceiptSecure instead)
    func analyzeReceipt(image: UIImage, creationTime: Date = Date(), completion: @escaping (Result<ReceiptAnalysis, Error>) -> Void) {
        print("⚠️ Using legacy direct API - consider switching to analyzeReceiptSecure()")
        print("🚀 Starting receipt analysis...")
        print("📸 Image dimensions: \(image.size.width) x \(image.size.height)")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("🔴 API key missing or empty")
            print("🔍 Checking API key sources:")
            print("   - Keychain: \(KeychainManager.shared.exists(for: .openRouterAPIKey) ? "EXISTS" : "MISSING")")
            print("   - Environment: \(ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] != nil ? "EXISTS" : "MISSING")")
            print("   - Info.plist: \(Bundle.main.object(forInfoDictionaryKey: "OpenRouterAPIKey") != nil ? "EXISTS" : "MISSING")")
            completion(.failure(ReceiptAIError.missingAPIKey))
            return
        }
        print("✅ API key found: \(apiKey.prefix(10))...")
        
        // Resize image to reduce memory usage and API payload size
        let resizedImage = resizeImageForAPI(image)
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            print("🔴 Failed to convert image to JPEG data")
            completion(.failure(ReceiptAIError.imageProcessingFailed))
            return
        }
        print("✅ Image converted to JPEG (\(imageData.count) bytes)")
        
        let base64Image = imageData.base64EncodedString()
        
        let prompt = """
        Analyze this receipt image and return ONLY valid JSON in this exact format:

        {
            "merchantName": "exact business name from receipt",
            "totalAmount": 20.50,
            "currency": "USD",
            "date": "2025-09-06",
            "category": "Technology",
            "paymentMethod": "Card",
            "items": [
                {
                    "description": "item or service name",
                    "quantity": 1,
                    "unitPrice": 20.50,
                    "totalPrice": 20.50
                }
            ]
        }

        If no date is visible on receipt, use:
        "date": "TODAY"

        IMPORTANT:
        - Return ONLY the JSON object, no other text
        - Use numbers for amounts, not strings
        - Date and time format: YYYY-MM-DD HH:MM (24-hour format) if time is available on receipt, or just YYYY-MM-DD if only date is shown
        - Extract the EXACT timestamp from the receipt when available (e.g., "2024-11-16 14:30" for 2:30 PM)
        - If only date is visible, use format: YYYY-MM-DD
        - CRITICAL: If NO DATE is found on the receipt, return "TODAY" as the date value
        - IMPORTANT: Always prioritize extracting time when visible on receipt. If no time found, the app will use creation time automatically.
        - Currency should be the 3-letter ISO code (USD, EUR, GBP, PHP, VND, etc.)
        - Detect the currency from currency symbols, text, or context on the receipt
        
        CURRENCY-SPECIFIC NUMBER FORMATTING:
        - For Vietnamese Dong (VND) receipts: Convert period-separated numbers to standard format
          Examples: "60.000" → 60000, "1.234.567" → 1234567, "23.450.000" → 23450000
        - For VND amounts, periods are thousands separators, NOT decimal points
        - Return clean numbers without formatting: 60000 instead of "60.000"
        - If you see ₫ symbol or Vietnamese text, use VND currency code
        - Vietnamese examples: "60.000 ₫" = 60000, "1.234.567 VND" = 1234567
        - Available categories (ONLY use these exact categories, do NOT create new ones):
          * Home: "Home", "Rent/Mortgage", "Property Tax", "Repairs"
          * Utilities: "Utilities", "Electricity", "Water", "Internet"
          * Food: "Food", "Groceries", "Snacks", "Meal Prep"
          * Dining: "Dining", "Restaurants", "Cafes", "Takeout"
          * Transport: "Transport", "Fuel", "Car Payments", "Rideshare"
          * Insurance: "Insurance", "Auto Insurance", "Home Insurance", "Life Insurance"
          * Health: "Health", "Doctor Visits", "Medications", "Therapy"
          * Debt: "Debt", "Credit Cards", "Loans", "Interest"
          * Fun: "Fun", "Movies", "Concerts", "Games"
          * Clothes: "Clothes", "Work Attire", "Casual Wear", "Shoes"
          * Personal: "Personal", "Haircuts", "Skincare", "Hygiene"
          * Learning: "Learning", "Tuition", "Books", "Courses"
          * Kids: "Kids", "Childcare", "Toys", "Activities"
          * Pets: "Pets", "Vet Care", "Pet Food", "Grooming"
          * Gifts: "Gifts", "Presents", "Donations", "Cards"
          * Travel: "Travel", "Flights", "Hotels", "Rental Cars"
          * Subscriptions: "Subscriptions", "Streaming", "Software", "Memberships"
          * Household: "Household", "Cleaning", "Furniture", "Decor"
          * Services: "Services", "Legal", "Accounting", "Consulting"
          * Supplies: "Supplies", "Office", "Crafts", "Packaging"
          * Fitness: "Fitness", "Gym", "Equipment", "Classes"
          * Tech: "Tech", "Devices", "Accessories", "Repairs"
          * Business: "Business", "Marketing", "Inventory", "Workspace"
          * Taxes: "Taxes", "Income Tax", "Sales Tax", "Filing Fees"
          * Savings: "Savings", "Emergency Fund", "Retirement", "Investments"
          * Auto: "Auto", "Maintenance", "Registration", "Parking"
          * Drinks: "Drinks", "Coffee", "Alcohol", "Beverages"
          * Hobbies: "Hobbies", "Supplies", "Equipment", "Events"
          * Events: "Events", "Parties", "Tickets", "Ceremonies"
          * Other: "Other", "Fees", "Miscellaneous", "Uncategorized"
        - IMPORTANT: ONLY use categories from the list above. Do NOT create or suggest new categories.
        - Choose the MOST SPECIFIC subcategory that matches the receipt (e.g., "Groceries" instead of "Food")
        - If uncertain, use the closest matching category or "Other"
        """
        
        let payload: [String: Any] = [
            "model": "openai/gpt-4o", // Using GPT-4 Vision for better receipt analysis
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(ReceiptAIError.requestCreationFailed))
            return
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Cashooya-iOS", forHTTPHeaderField: "HTTP-Referer") // OpenRouter requires this
        request.setValue("Cashooya Receipt Scanner", forHTTPHeaderField: "X-Title") // Optional: app name
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔴 Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Log HTTP response details
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Response Status: \(httpResponse.statusCode)")
                print("📡 HTTP Headers: \(httpResponse.allHeaderFields)")
                
                if httpResponse.statusCode != 200 {
                    print("🔴 Non-200 status code: \(httpResponse.statusCode)")
                    if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                        print("🔴 Error response body: \(errorBody)")
                    }
                }
            }
            
            guard let data = data else {
                print("🔴 No data received from API")
                completion(.failure(ReceiptAIError.noDataReceived))
                return
            }
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 Raw API Response: \(responseString.prefix(500))...")
            }
            
            do {
                let result = try self.parseOpenRouterResponse(data, creationTime: creationTime)
                print("✅ Successfully parsed receipt analysis")
                completion(.success(result))
            } catch {
                print("🔴 Parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Force refresh API key and test connection
    func refreshAndTestAPIKey(completion: @escaping (Result<String, Error>) -> Void) {
        print("🔄 TESTING: Force refreshing API key...")
        Config.forceRefreshOpenRouterKey()
        testAPIConnection(completion: completion)
    }
    
    /// Test API connection with a simple text-only request
    func testAPIConnection(completion: @escaping (Result<String, Error>) -> Void) {
        print("🧪 Testing API connection...")
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(ReceiptAIError.missingAPIKey))
            return
        }
        
        let payload: [String: Any] = [
            "model": "openai/gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": "Say 'API connection working' in exactly 3 words."
                ]
            ],
            "max_tokens": 10
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(ReceiptAIError.requestCreationFailed))
            return
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Cashooya-iOS", forHTTPHeaderField: "HTTP-Referer")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔴 API test network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧪 API Test Response Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                completion(.failure(ReceiptAIError.noDataReceived))
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("🧪 API Test Response: \(responseString)")
                completion(.success(responseString))
            } else {
                completion(.failure(ReceiptAIError.invalidResponse))
            }
        }.resume()
    }
    
    private func parseOpenRouterResponse(_ data: Data, creationTime: Date) throws -> ReceiptAnalysis {
        let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let choices = response?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("🔴 Invalid response structure: \(String(describing: response))")
            throw ReceiptAIError.invalidResponse
        }
        
        print("📄 AI Response content: \(content)")
        
        // Try to parse content as direct JSON first
        var receiptData: [String: Any]?
        
        if let directData = content.data(using: .utf8),
           let directJSON = try? JSONSerialization.jsonObject(with: directData) as? [String: Any] {
            receiptData = directJSON
            print("✅ Parsed content as direct JSON")
        } else {
            // Extract JSON from the response content
            guard let jsonStart = content.range(of: "{"),
                  let jsonEnd = content.range(of: "}", options: .backwards, range: jsonStart.lowerBound..<content.endIndex) else {
                print("🔴 Could not find JSON in response: \(content)")
                throw ReceiptAIError.jsonExtractionFailed
            }
            
            let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])
            print("🔍 Extracted JSON: \(jsonString)")
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let extractedJSON = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("🔴 Failed to parse extracted JSON")
                throw ReceiptAIError.jsonExtractionFailed
            }
            receiptData = extractedJSON
        }
        
        guard let merchantName = receiptData?["merchantName"] as? String,
              let totalAmount = receiptData?["totalAmount"] as? Double,
              let currencyString = receiptData?["currency"] as? String,
              let dateString = receiptData?["date"] as? String,
              let category = receiptData?["category"] as? String,
              let paymentMethod = receiptData?["paymentMethod"] as? String,
              let itemsArray = receiptData?["items"] as? [[String: Any]] else {
            throw ReceiptAIError.missingRequiredFields
        }
        
        // Enhanced date parsing that handles "TODAY" keyword and date+time formats
        let date: Date
        if dateString.uppercased() == "TODAY" {
            // AI detected no date on receipt, use today at current time
            date = Date()
            print("📅 AIReceiptAnalyzer: AI found no date on receipt, using TODAY: \(date)")
        } else {
            // Try to parse the actual date from receipt
            let parsedDate = Self.parseReceiptDate(dateString, fallbackTime: creationTime)
            date = parsedDate ?? Date()
            print("📅 AIReceiptAnalyzer: Parsed date from '\(dateString)' as: \(date)")
            if parsedDate == nil {
                print("📅 AIReceiptAnalyzer: Failed to parse date '\(dateString)', defaulting to TODAY: \(date)")
            }
        }
        
        // Parse currency from string with debugging
        print("🪙 AIReceiptAnalyzer: Parsing currency from AI response: '\(currencyString)'")
        print("🪙 AIReceiptAnalyzer: Available currencies: \(Currency.allCases.map { $0.rawValue }.joined(separator: ", "))")
        
        let currency = Currency.allCases.first { $0.rawValue.uppercased() == currencyString.uppercased() }
        
        if let foundCurrency = currency {
            print("✅ AIReceiptAnalyzer: Successfully parsed currency: \(foundCurrency.rawValue)")
        } else {
            print("❌ AIReceiptAnalyzer: Currency '\(currencyString)' not found, defaulting to USD")
            print("🔍 AIReceiptAnalyzer: Exact comparison checks:")
            for curr in Currency.allCases {
                let matches = curr.rawValue.uppercased() == currencyString.uppercased()
                print("   - \(curr.rawValue) vs '\(currencyString)': \(matches)")
            }
        }
        
        let finalCurrency = currency ?? .usd
        
        let items = itemsArray.compactMap { itemDict -> ReceiptItem? in
            guard let description = itemDict["description"] as? String,
                  let quantity = itemDict["quantity"] as? Int,
                  let unitPrice = itemDict["unitPrice"] as? Double,
                  let totalPrice = itemDict["totalPrice"] as? Double else {
                return nil
            }
            return ReceiptItem(description: description, quantity: quantity, unitPrice: unitPrice, totalPrice: totalPrice)
        }
        
        return ReceiptAnalysis(
            merchantName: merchantName,
            totalAmount: totalAmount,
            date: date,
            category: category,
            paymentMethod: paymentMethod,
            currency: finalCurrency,
            items: items,
            rawText: content
        )
    }
    
    // Resize image to reduce memory usage and API payload size (for legacy direct API)
    private func resizeImageForAPI(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024 // Reasonable size for API
        let size = image.size

        // If image is already small enough, return as-is
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // Resize the image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        print("📐 Image resized from \(size) to \(newSize)")
        return resizedImage
    }

    /// Resize image more aggressively for backend API (smaller to avoid "message too long" errors)
    private func resizeImageForBackend(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800 // Smaller for reliable network transfer
        let size = image.size

        // If image is already small enough, return as-is
        if size.width <= maxDimension && size.height <= maxDimension {
            print("📐 Image already small enough: \(size)")
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // Resize the image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        print("📐 Backend: Image resized from \(size) to \(newSize)")
        return resizedImage
    }
}

// MARK: - Error Types

enum ReceiptAIError: Error, LocalizedError {
    case missingAPIKey
    case imageProcessingFailed
    case requestCreationFailed
    case noDataReceived
    case invalidResponse
    case jsonExtractionFailed
    case missingRequiredFields
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured. Please check your setup."
        case .imageProcessingFailed:
            return "Failed to process image"
        case .requestCreationFailed:
            return "Failed to create API request"
        case .noDataReceived:
            return "No data received from API"
        case .invalidResponse:
            return "Invalid response from API"
        case .jsonExtractionFailed:
            return "Failed to extract JSON from response"
        case .missingRequiredFields:
            return "Missing required fields in response"
        }
    }
}