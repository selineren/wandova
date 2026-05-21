//
//  SyncStatusView.swift
//  Wandova
//
//  Created by seren on 16.03.2026.
//

import SwiftUI

struct SyncStatusView: View {
    let status: SyncStatus
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    @State private var showDetails = false
    
    init(
        status: SyncStatus,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.status = status
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
                
            case .syncing:
                syncingBanner
                
            case .success(let date):
                successBanner(date: date)
                
            case .error(let message, let isOffline):
                errorBanner(message: message, isOffline: isOffline)
            }
        }
    }
    
    // MARK: - Syncing Banner
    
    private var syncingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text("Syncing...")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.9))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Success Banner
    
    private func successBanner(date: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text(timeAgoString(from: date))
                .font(.caption)
                .foregroundColor(.white)
            
            if let onDismiss {
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.85))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(message: String, isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isOffline ? "Offline" : "Sync Failed")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    if showDetails || isOffline {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Always show retry button - user might have fixed connection
                    if let onRetry {
                        Button {
                            onRetry()
                        } label: {
                            Text("Retry")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    
                    if let onDismiss {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isOffline ? Color.orange.opacity(0.9) : Color.red.opacity(0.9))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .onTapGesture {
            if !isOffline {
                withAnimation {
                    showDetails.toggle()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Synced just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Synced \(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Synced \(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "Synced \(days)d ago"
        }
    }
}

// MARK: - Compact Toolbar Variant

struct SyncStatusToolbarItem: View {
    let status: SyncStatus
    
    var body: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()
                
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
            case .success(let date):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(compactTimeString(from: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
            case .error(_, let isOffline):
                HStack(spacing: 4) {
                    Image(systemName: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isOffline ? .orange : .red)
                        .font(.caption)
                    Text(isOffline ? "Offline" : "Error")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func compactTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SyncStatusView(status: .syncing)
        
        SyncStatusView(
            status: .success(Date().addingTimeInterval(-120)),
            onDismiss: {}
        )
        
        SyncStatusView(
            status: .error("Failed to connect to server", isOffline: false),
            onRetry: {},
            onDismiss: {}
        )
        
        SyncStatusView(
            status: .error("No internet connection", isOffline: true),
            onDismiss: {}
        )
    }
    .padding()
}
