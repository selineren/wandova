//
//  SyncStatusViewModifier.swift
//  Wandova
//
//  Created by seren on 16.03.2026.
//

import SwiftUI

struct SyncStatusBannerModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    
    @State private var showBanner = true
    
    let position: BannerPosition
    let onRetry: (() -> Void)?
    
    enum BannerPosition {
        case top
        case bottom
    }
    
    init(
        position: BannerPosition = .top,
        onRetry: (() -> Void)? = nil
    ) {
        self.position = position
        self.onRetry = onRetry
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if showBanner {
                VStack {
                    if position == .bottom {
                        Spacer()
                    }
                    
                    SyncStatusView(
                        status: appState.syncStatus,
                        onRetry: onRetry ?? {
                            Task {
                                await appState.retrySyncIfNeeded()
                            }
                        },
                        onDismiss: {
                            withAnimation {
                                showBanner = false
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(position == .top ? .top : .bottom, 8)
                    .transition(.move(edge: position == .top ? .top : .bottom).combined(with: .opacity))
                    
                    if position == .top {
                        Spacer()
                    }
                }
            }
        }
        .onChange(of: appState.syncStatus) { oldValue, newValue in
            // Show banner when status changes
            if case .idle = oldValue, case .idle = newValue {
                // Don't show for idle -> idle
            } else {
                withAnimation {
                    showBanner = true
                }
                
                // Auto-hide success message after 3 seconds
                if case .success = newValue {
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation {
                            showBanner = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    /// Adds a sync status banner to the view
    func syncStatusBanner(
        position: SyncStatusBannerModifier.BannerPosition = .top,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(SyncStatusBannerModifier(position: position, onRetry: onRetry))
    }
}
