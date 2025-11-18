//
//  CapsuleToggle.swift
//  Cashooya Playground
//
//  Created by Dante Cardines III on 9/5/25.
//

import SwiftUI

struct CapsuleToggle: View {
    let text: String
    let isOn: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AppFonts.overusedGroteskMedium(size: 14))
                .foregroundStyle(isOn ? .white : .primary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isOn ? Color.black : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}