//
//  LocationCurrencyService.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import Foundation

class LocationCurrencyService {
    static let shared = LocationCurrencyService()
    
    private init() {}
    
    /// Get recommended currency based on device's locale/region
    func getRecommendedCurrency() -> Currency {
        let locale = Locale.current
        
        // Get the currency code from the device's region
        guard let currencyCode = locale.currency?.identifier else {
            print("🌍 LocationCurrency: Could not detect currency from locale, defaulting to PHP")
            return .php
        }
        
        let regionCode = locale.region?.identifier ?? "Unknown"
        print("🌍 LocationCurrency: Detected region: \(regionCode)")
        print("🌍 LocationCurrency: Detected currency code: \(currencyCode)")
        
        // Map currency code to our Currency enum
        let recommendedCurrency = mapCurrencyCode(currencyCode)
        print("🌍 LocationCurrency: Recommended currency: \(recommendedCurrency.rawValue) (\(recommendedCurrency.displayName))")
        print("🌍 LocationCurrency: Currency symbol: \(recommendedCurrency.symbol)")
        
        return recommendedCurrency
    }
    
    /// Get country name from device locale
    func getDetectedCountry() -> String {
        let locale = Locale.current
        
        if let regionCode = locale.region?.identifier {
            // Get localized country name
            let countryName = locale.localizedString(forRegionCode: regionCode) ?? regionCode
            print("🌍 LocationCurrency: Detected country: \(countryName) (\(regionCode))")
            return countryName
        }
        
        return "Unknown"
    }
    
    /// Map currency codes to our Currency enum
    private func mapCurrencyCode(_ code: String) -> Currency {
        switch code.uppercased() {
        case "USD":
            return .usd
        case "EUR":
            return .eur
        case "GBP":
            return .gbp
        case "JPY":
            return .jpy
        case "AUD":
            return .aud
        case "CAD":
            return .cad
        case "CHF":
            return .chf
        case "CNY":
            return .cny
        case "SEK":
            return .sek
        case "NZD":
            return .nzd
        case "MXN":
            return .mxn
        case "SGD":
            return .sgd
        case "HKD":
            return .hkd
        case "NOK":
            return .nok
        case "KRW":
            return .krw
        case "TRY":
            return .try_
        case "RUB":
            return .rub
        case "INR":
            return .inr
        case "BRL":
            return .brl
        case "ZAR":
            return .zar
        case "PHP":
            return .php
        default:
            print("🌍 LocationCurrency: Unknown currency code '\(code)', defaulting to PHP")
            return .php
        }
    }
    
    /// Get formatted recommendation message
    func getRecommendationMessage() -> String {
        let country = getDetectedCountry()
        let currency = getRecommendedCurrency()
        
        return "Based on your location (\(country)), we recommend \(currency.displayName) (\(currency.symbol))"
    }
}