//
//  CurrencyPickerSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

struct CurrencyPickerSheet: View {
    @Binding var primaryCurrency: Currency
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    // Performance optimization: Use debouncer for search
    @State private var searchDebouncer = Debouncer(delay: 0.3)
    
    // Performance optimization: Cache filtered currencies
    @State private var cachedCurrencies: [Currency] = []
    @State private var isSearching = false
    
    /// Get optimized cached currencies
    private var filteredCurrencies: [Currency] {
        return cachedCurrencies
    }
    
    /// Update cached currencies with debounced search
    private func updateCachedCurrencies(searchText: String) {
        isSearching = !searchText.isEmpty
        
        searchDebouncer.debounce { [searchText] in
            #if DEBUG
            let startTime = CFAbsoluteTimeGetCurrent()
            #endif
            
            let filtered = searchText.isEmpty ? Currency.allCases : Currency.allCases.filter { currency in
                currency.searchableDisplayName.localizedCaseInsensitiveContains(searchText) ||
                currency.rawValue.localizedCaseInsensitiveContains(searchText) ||
                currency.fullName.localizedCaseInsensitiveContains(searchText)
            }
            
            cachedCurrencies = filtered
            
            #if DEBUG
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("🔍 CurrencyPicker search completed in \(String(format: "%.3f", duration))s for '\(searchText)' - found \(filtered.count) results")
            #endif
            
            isSearching = false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(
                title: "Select Currency",
                onBackTap: { isPresented = false }
            )
        
            // Search bar
            AppInputField.search(text: $searchText, placeholder: "Search for a currency...", size: .md)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .background(AppColors.backgroundWhite)
                .fixedSize(horizontal: false, vertical: true)
            
            // Currency list with loading state
            if isSearching && !searchText.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching currencies...")
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundColor(AppColors.foregroundSecondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundWhite)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCurrencies, id: \.self) { currency in
                            SelectionRowItem.currency(
                                currency,
                                isSelected: primaryCurrency == currency,
                                onTap: {
                                    primaryCurrency = currency
                                    searchText = ""
                                    isPresented = false
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(AppColors.backgroundWhite)
            }
        }
        .background(AppColors.backgroundWhite)
        .onAppear {
            // Initialize cache on first load
            updateCachedCurrencies(searchText: "")
        }
        .onChange(of: searchText) { _, newValue in
            // Update cache when search text changes (debounced)
            updateCachedCurrencies(searchText: newValue)
        }
    }
}