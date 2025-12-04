//
//  LanguagePickerSheet.swift
//  Cashooya Playground
//
//  Created by Claude on 9/8/25.
//

import SwiftUI

struct LanguagePickerSheet: View {
    @Binding var selectedLanguage: Language
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.allCases
        } else {
            return Language.allCases.filter { language in
                language.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SheetHeader.basic(
                title: "Select Language",
                onBackTap: { isPresented = false }
            )
        
            // Search bar
            AppInputField.search(text: $searchText, placeholder: "Search for a language...", size: .md)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .background(AppColors.backgroundWhite)
                .fixedSize(horizontal: false, vertical: true)
            
            // Language list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(filteredLanguages, id: \.self) { language in
                        SelectionRowItem.language(
                            language,
                            isSelected: selectedLanguage == language,
                            onTap: {
                                selectedLanguage = language
                                searchText = ""
                                isPresented = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .background(AppColors.backgroundWhite)
        }
        .background(AppColors.backgroundWhite)
    }
}