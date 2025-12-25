import Foundation
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Secure backend API service for all external API calls
class BackendAPIService: ObservableObject {
    static let shared = BackendAPIService()
    
    // Firebase Functions base URL
    private let baseURL = "https://us-central1-cashmonki-app.cloudfunctions.net/api/api"
    
    private var session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Receipt Analysis (OpenRouter Proxy)
    
    /// Analyze receipt through secure backend proxy using JSON
    func analyzeReceipt(imageData: Data, categories: [[String: Any]]? = nil) async throws -> BackendReceiptAnalysisResult {
        print("🔒 BACKEND: Starting secure receipt analysis...")

        // Validate image data
        guard !imageData.isEmpty else {
            print("❌ BACKEND: Image data is empty")
            throw BackendAPIError.invalidResponse
        }

        // Convert to base64 - simple and reliable
        let base64Image = imageData.base64EncodedString()
        print("🔒 BACKEND: Converted image to base64: \(base64Image.count) chars")

        var request = URLRequest(url: URL(string: "\(baseURL)/analyze-receipt")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Firebase ID token for authentication
        if let idToken = await getCurrentFirebaseIDToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        // Create JSON payload with image and optional categories
        var payload: [String: Any] = ["image": base64Image]
        if let categories = categories {
            payload["categories"] = categories
            print("🔒 BACKEND: Including \(categories.count) local categories in request")
        }
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = jsonData
        
        print("🔒 BACKEND: JSON payload size: \(jsonData.count) bytes")
        print("🔒 BACKEND: Content-Type: application/json")
        
        do {
            print("🔒 BACKEND: Sending JSON request to backend...")
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendAPIError.invalidResponse
            }
            
            print("🔒 BACKEND: Received response with status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                // Configure decoder to handle string dates from backend
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Try different date formats that the backend might return
                    let formatters: [DateFormatter] = [
                        createBackendDateFormatter("yyyy-MM-dd"),  // "2025-12-08"
                        createBackendDateFormatter("yyyy-MM-dd HH:mm:ss"),  // "2025-12-08 14:30:00"
                        createBackendDateFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'"),  // ISO format
                        createBackendDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")  // ISO with milliseconds
                    ]
                    
                    for formatter in formatters {
                        if let date = formatter.date(from: dateString) {
                            print("📅 BACKEND: Successfully parsed date '\(dateString)' as \(date)")
                            return date
                        }
                    }
                    
                    // If all else fails, return current date
                    print("⚠️ BACKEND: Could not parse date '\(dateString)', using current date")
                    return Date()
                }
                
                let result = try decoder.decode(BackendReceiptAnalysisResult.self, from: data)
                print("✅ BACKEND: Receipt analysis successful")
                return result
                
            case 401:
                throw BackendAPIError.unauthorized
                
            case 429:
                throw BackendAPIError.rateLimited
                
            case 500...599:
                throw BackendAPIError.serverError
                
            default:
                print("❌ BACKEND: Unexpected status code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ BACKEND: Response body: \(responseString)")
                }
                throw BackendAPIError.unexpectedError(httpResponse.statusCode)
            }
            
        } catch {
            print("❌ BACKEND: Receipt analysis failed: \(error)")
            throw error
        }
    }
    
    // MARK: - App Configuration (RevenueCat Keys)
    
    /// Fetch secure app configuration from backend
    func fetchAppConfiguration() async throws -> AppConfiguration {
        print("🔒 BACKEND: Fetching secure app configuration...")
        
        var request = URLRequest(url: URL(string: "\(baseURL)/app-config")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase ID token for authentication
        if let idToken = await getCurrentFirebaseIDToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Add device/app info for validation
        let deviceInfo = BackendDeviceInfo.current()
        let deviceData = try JSONEncoder().encode(deviceInfo)
        request.httpBody = deviceData
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw BackendAPIError.configurationFailed
            }
            
            let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
            print("✅ BACKEND: App configuration received")
            return config
            
        } catch {
            print("❌ BACKEND: Failed to fetch app configuration: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String? {
        // Get current authenticated user ID
        return AuthenticationManager.shared.currentUser?.firebaseUID
    }
    
    private func getCurrentFirebaseIDToken() async -> String? {
        // Get Firebase ID token for backend authentication (safe for TestFlight)
        #if canImport(FirebaseAuth)
        do {
            // Check if Firebase is configured before accessing Auth
            guard FirebaseApp.app() != nil else {
                print("🔒 BACKEND: Firebase not configured - skipping auth token for security")
                return nil
            }
            
            if let currentUser = Auth.auth().currentUser {
                let idTokenResult = try await currentUser.getIDTokenResult()
                print("🔑 BACKEND: Got Firebase ID token: \(idTokenResult.token.prefix(20))...")
                return idTokenResult.token
            }
        } catch {
            print("❌ BACKEND: Failed to get Firebase ID token: \(error)")
        }
        #endif
        
        print("❌ BACKEND: No Firebase Auth or no current user - continuing without auth")
        return nil
    }
    
    // MARK: - Roast Generation (OpenRouter Proxy)

    /// Generate a sassy roast message for a receipt using AI
    func generateRoast(amount: String, merchant: String, category: String, notes: String? = nil, lineItems: [[String: Any]]? = nil, userName: String? = nil) async throws -> String {
        print("🔥 BACKEND: Generating roast message...")

        var request = URLRequest(url: URL(string: "\(baseURL)/generate-roast")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Firebase ID token for authentication
        if let idToken = await getCurrentFirebaseIDToken() {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        // Create payload with transaction details
        var payload: [String: Any] = [
            "amount": amount,
            "merchant": merchant,
            "category": category
        ]
        if let notes = notes, !notes.isEmpty {
            payload["notes"] = notes
        }
        if let lineItems = lineItems, !lineItems.isEmpty {
            payload["lineItems"] = lineItems
        }
        if let userName = userName, !userName.isEmpty, userName != "Cashmonki User" {
            payload["userName"] = userName
        }
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = jsonData

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendAPIError.invalidResponse
            }

            print("🔥 BACKEND: Roast response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                if let result = try? JSONDecoder().decode(RoastResponse.self, from: data) {
                    print("✅ BACKEND: Roast generated successfully")
                    return result.roast
                } else if let responseString = String(data: data, encoding: .utf8) {
                    // Try to parse as raw string if not JSON
                    return responseString
                }
                throw BackendAPIError.invalidResponse

            case 401:
                throw BackendAPIError.unauthorized

            case 429:
                throw BackendAPIError.rateLimited

            case 500...599:
                throw BackendAPIError.serverError

            default:
                print("❌ BACKEND: Unexpected roast response: \(httpResponse.statusCode)")
                throw BackendAPIError.unexpectedError(httpResponse.statusCode)
            }

        } catch {
            print("❌ BACKEND: Roast generation failed: \(error)")
            throw error
        }
    }

    private func getFirebaseProjectId() -> String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let plistData = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let projectId = plist["PROJECT_ID"] as? String else {
            return nil
        }
        return projectId
    }
}

// MARK: - Helper Functions

/// Create a date formatter for backend date parsing
private func createBackendDateFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
}

// MARK: - Data Models

struct BackendReceiptAnalysisResult: Codable {
    let merchantName: String
    let amount: Double
    let currency: String?
    let date: Date
    let category: String
    let items: [BackendReceiptItem]
    let confidence: Double
    let processingTime: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case merchantName = "merchant_name"
        case amount
        case currency
        case date
        case category
        case items
        case confidence
        case processingTime = "processing_time"
    }
}

struct BackendReceiptItem: Codable {
    let name: String
    let price: Double
    let quantity: Int
}

struct RoastResponse: Codable {
    let roast: String
}

struct AppConfiguration: Codable {
    let revenueCatApiKey: String
    let features: [String: Bool]
    let rateLimit: RateLimit
    
    enum CodingKeys: String, CodingKey {
        case revenueCatApiKey = "revenuecat_api_key"
        case features
        case rateLimit = "rate_limit"
    }
}

struct RateLimit: Codable {
    let receiptsPerHour: Int
    let receiptsPerDay: Int
    
    enum CodingKeys: String, CodingKey {
        case receiptsPerHour = "receipts_per_hour"
        case receiptsPerDay = "receipts_per_day"
    }
}

struct BackendDeviceInfo: Codable {
    let bundleId: String
    let appVersion: String
    let deviceModel: String
    let systemVersion: String
    let userId: String?
    
    static func current() -> BackendDeviceInfo {
        return BackendDeviceInfo(
            bundleId: Bundle.main.bundleIdentifier ?? "",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            userId: AuthenticationManager.shared.currentUser?.firebaseUID
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case bundleId = "bundle_id"
        case appVersion = "app_version"
        case deviceModel = "device_model"
        case systemVersion = "system_version"
        case userId = "user_id"
    }
}

// MARK: - Error Types

enum BackendAPIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited
    case serverError
    case configurationFailed
    case unexpectedError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .serverError:
            return "Server error. Please try again."
        case .configurationFailed:
            return "Failed to load app configuration"
        case .unexpectedError(let code):
            return "Unexpected error (code: \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}