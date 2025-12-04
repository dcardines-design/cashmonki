//
//  ReceiptsPageBackup.swift
//  CashMonki
//
//  Temporary backup of ReceiptsPage
//

import SwiftUI

struct ReceiptsPageBackup: View {
    var body: some View {
        VStack {
            Text("Receipts Page")
                .font(.title)
                .padding()
            
            Text("Temporary simplified view")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ReceiptsPageBackup()
}