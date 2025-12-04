//
//  SyncStatusIndicator.swift
//  CashMonki
//
//  Created by Claude on 10/23/25.
//

import SwiftUI

/// Displays current sync status to users with real-time updates
struct SyncStatusIndicator: View {
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var syncManager = TransactionSyncManager.shared
    @State private var showSyncDetails = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            statusIcon
            
            // Status text
            Text(syncStatus.description)
                .font(.caption)
                .foregroundColor(statusColor)
            
            // Show details button for errors or pending changes
            if case .error = syncStatus, showDetailsButton {
                Button(action: { showSyncDetails = true }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(statusBackgroundColor)
        )
        .onTapGesture {
            if case .pendingChanges = syncStatus {
                userManager.forceSync()
            } else if case .error = syncStatus {
                showSyncDetails = true
            }
        }
        .sheet(isPresented: $showSyncDetails) {
            SyncDetailsSheet()
        }
    }
    
    private var syncStatus: SyncStatus {
        if let syncError = syncManager.syncError {
            return .error(message: syncError)
        }
        return userManager.getSyncStatus()
    }
    
    private var statusIcon: some View {
        Group {
            switch syncStatus {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor((AppColors.successForeground))
                    .font(.caption)
                
            case .pendingChanges:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
                    .font(.caption)
                
            case .notSynced:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.gray)
                    .font(.caption)
                
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.destructiveForeground)
                    .font(.caption)
            }
        }
    }
    
    private var statusColor: Color {
        switch syncStatus {
        case .syncing:
            return .blue
        case .synced:
            return (AppColors.successForeground)
        case .pendingChanges:
            return .orange
        case .notSynced:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var statusBackgroundColor: Color {
        switch syncStatus {
        case .syncing:
            return Color.blue.opacity(0.1)
        case .synced:
            return Color(AppColors.successForeground).opacity(0.1)
        case .pendingChanges:
            return Color.orange.opacity(0.1)
        case .notSynced:
            return Color.gray.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        }
    }
    
    private var showDetailsButton: Bool {
        switch syncStatus {
        case .error, .pendingChanges:
            return true
        default:
            return false
        }
    }
}

/// Detailed sync information sheet
struct SyncDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var syncManager = TransactionSyncManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sync Status")
                        .font(.headline)
                    
                    HStack {
                        SyncStatusIndicator()
                        Spacer()
                    }
                    
                    if let error = syncManager.syncError {
                        Text("Error Details:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.destructiveForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sync statistics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        syncStatRow("Last Sync", value: lastSyncText)
                        syncStatRow("Pending Changes", value: "\(syncManager.pendingChangesCount)")
                        syncStatRow("Total Transactions", value: "\(userManager.currentUser.transactions.count)")
                        syncStatRow("User ID", value: userManager.currentUser.id.uuidString.prefix(8) + "...")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        userManager.forceSync()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Force Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(syncManager.isSyncing)
                    
                    if syncManager.syncError != nil {
                        Button(action: {
                            userManager.clearSyncError()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Clear Error")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sync Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func syncStatRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var lastSyncText: String {
        if let lastSync = syncManager.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never"
        }
    }
}

// MARK: - Preview Support

struct SyncStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Different sync states for preview
            HStack {
                SyncStatusIndicator()
                Spacer()
            }
            
            // Mock different states
            HStack {
                Text("Synced")
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor((AppColors.successForeground))
                        .font(.caption)
                    Text("Synced 2m ago")
                        .font(.caption)
                        .foregroundColor((AppColors.successForeground))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(AppColors.successForeground).opacity(0.1))
                .cornerRadius(16)
            }
            
            HStack {
                Text("Pending Changes")
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("3 pending changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(16)
            }
            
            HStack {
                Text("Error")
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.destructiveForeground)
                        .font(.caption)
                    Text("Error: Connection failed")
                        .font(.caption)
                        .foregroundColor(AppColors.destructiveForeground)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(16)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}