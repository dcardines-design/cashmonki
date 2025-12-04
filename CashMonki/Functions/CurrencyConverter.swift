import Foundation

// MARK: - Currency Conversion Models

struct ExchangeRates: Codable {
    let base: String
    let rates: [String: Double]
    let timestamp: TimeInterval
}

struct ConvertedAmount {
    let originalAmount: Double
    let originalCurrency: Currency
    let convertedAmount: Double
    let convertedCurrency: Currency
    let exchangeRate: Double
    let timestamp: Date
}

// MARK: - Currency Conversion Service

class CurrencyConverter: ObservableObject {
    static let shared = CurrencyConverter()
    
    @Published var currentRates: ExchangeRates?
    @Published var isLoading = false
    
    private let rateManager: CurrencyRateManager
    private let cacheKey = "exchange_rates_cache"
    private let cacheTimestampKey = "exchange_rates_timestamp"
    private let cacheValidityHours: TimeInterval = 1 // Cache for 1 hour
    
    private init() {
        self.rateManager = CurrencyRateManager.shared
        loadCachedRates()
    }
    
    /// Public initializer for dependency injection
    init(rateManager: CurrencyRateManager) {
        self.rateManager = rateManager
        loadCachedRates()
    }
    
    // MARK: - Public Methods
    
    /// Convert amount from one currency to another
    func convert(
        amount: Double,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        completion: @escaping (Result<ConvertedAmount, CurrencyConversionError>) -> Void
    ) {
        // If same currency, no conversion needed
        if sourceCurrency == targetCurrency {
            let result = ConvertedAmount(
                originalAmount: amount,
                originalCurrency: sourceCurrency,
                convertedAmount: amount,
                convertedCurrency: targetCurrency,
                exchangeRate: 1.0,
                timestamp: Date()
            )
            completion(.success(result))
            return
        }
        
        // Check if we have valid cached rates
        if let rates = currentRates, isCacheValid() {
            performConversion(amount: amount, from: sourceCurrency, to: targetCurrency, rates: rates, completion: completion)
        } else {
            // Fetch fresh rates
            fetchExchangeRates { [weak self] result in
                switch result {
                case .success(let rates):
                    self?.performConversion(amount: amount, from: sourceCurrency, to: targetCurrency, rates: rates, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get exchange rate between two currencies
    func getExchangeRate(from sourceCurrency: Currency, to targetCurrency: Currency) -> Double? {
        guard let rates = currentRates else { return nil }
        
        if sourceCurrency == targetCurrency { return 1.0 }
        
        // Convert via USD as base currency
        let sourceToUSD = sourceCurrency == .usd ? 1.0 : (1.0 / (rates.rates[sourceCurrency.rawValue] ?? 1.0))
        let targetFromUSD = targetCurrency == .usd ? 1.0 : (rates.rates[targetCurrency.rawValue] ?? 1.0)
        
        return sourceToUSD * targetFromUSD
    }
    
    /// Synchronous conversion using rate manager for simple conversions
    func convert(amount: Double, from sourceCurrency: Currency, to targetCurrency: Currency) -> Double {
        return rateManager.convertAmount(amount, from: sourceCurrency, to: targetCurrency)
    }
    
    // MARK: - Private Methods
    
    private func performConversion(
        amount: Double,
        from sourceCurrency: Currency,
        to targetCurrency: Currency,
        rates: ExchangeRates,
        completion: @escaping (Result<ConvertedAmount, CurrencyConversionError>) -> Void
    ) {
        // Convert via USD as base currency
        let sourceToUSD = sourceCurrency == .usd ? 1.0 : (1.0 / (rates.rates[sourceCurrency.rawValue] ?? 1.0))
        let targetFromUSD = targetCurrency == .usd ? 1.0 : (rates.rates[targetCurrency.rawValue] ?? 1.0)
        
        guard sourceToUSD > 0, targetFromUSD > 0 else {
            completion(.failure(.unsupportedCurrency))
            return
        }
        
        let exchangeRate = sourceToUSD * targetFromUSD
        let convertedAmount = amount * exchangeRate
        
        let result = ConvertedAmount(
            originalAmount: amount,
            originalCurrency: sourceCurrency,
            convertedAmount: convertedAmount,
            convertedCurrency: targetCurrency,
            exchangeRate: exchangeRate,
            timestamp: Date()
        )
        
        completion(.success(result))
    }
    
    private func fetchExchangeRates(completion: @escaping (Result<ExchangeRates, CurrencyConversionError>) -> Void) {
        isLoading = true
        
        // Using a free exchange rate API (exchangerate-api.com)
        let urlString = "https://api.exchangerate-api.com/v4/latest/USD"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noDataReceived))
                    return
                }
                
                do {
                    let apiResponse = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)
                    let exchangeRates = ExchangeRates(
                        base: apiResponse.base,
                        rates: apiResponse.rates,
                        timestamp: Date().timeIntervalSince1970
                    )
                    
                    self?.currentRates = exchangeRates
                    self?.cacheRates(exchangeRates)
                    completion(.success(exchangeRates))
                } catch {
                    completion(.failure(.parsingError(error)))
                }
            }
        }.resume()
    }
    
    private func loadCachedRates() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let rates = try? JSONDecoder().decode(ExchangeRates.self, from: data),
              isCacheValid() else {
            return
        }
        
        currentRates = rates
    }
    
    private func cacheRates(_ rates: ExchangeRates) {
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        }
    }
    
    private func isCacheValid() -> Bool {
        let lastCacheTime = UserDefaults.standard.double(forKey: cacheTimestampKey)
        let now = Date().timeIntervalSince1970
        return (now - lastCacheTime) < (cacheValidityHours * 3600)
    }
}

// MARK: - Supporting Types

private struct ExchangeRateAPIResponse: Codable {
    let base: String
    let rates: [String: Double]
}

enum CurrencyConversionError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case noDataReceived
    case parsingError(Error)
    case unsupportedCurrency
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid exchange rate API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noDataReceived:
            return "No exchange rate data received"
        case .parsingError(let error):
            return "Failed to parse exchange rates: \(error.localizedDescription)"
        case .unsupportedCurrency:
            return "Unsupported currency for conversion"
        case .conversionFailed:
            return "Currency conversion failed"
        }
    }
}