//
//  AppState.swift
//  WorldTrackerIOS
//
//  Created by seren on 25.02.2026.
//

import Foundation
import Combine

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(String, isOffline: Bool)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing):
            return true
        case let (.success(d1), .success(d2)):
            return d1 == d2
        case let (.error(msg1, offline1), .error(msg2, offline2)):
            return msg1 == msg2 && offline1 == offline2
        default:
            return false
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var visits: [String: Visit] = [:]
    @Published private(set) var visitedCountryIDs: Set<String> = []
    @Published private(set) var wantToVisitCountryIDs: Set<String> = []
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var isOffline = false

    private let repository: VisitRepository
    private let syncService: SyncService?
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()

    init(
        repository: VisitRepository, 
        syncService: SyncService? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.repository = repository
        self.syncService = syncService
        self.networkMonitor = networkMonitor ?? .shared
        
        // Monitor network status
        self.networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
            }
            .store(in: &cancellables)
        
        // Don't auto-load on init - wait for auth state
    }
    
    // Computed properties for convenience
    var isSyncing: Bool {
        if case .syncing = syncStatus { return true }
        return false
    }
    
    var lastSyncDate: Date? {
        if case .success(let date) = syncStatus { return date }
        return nil
    }
    
    var lastSyncError: String? {
        if case .error(let message, _) = syncStatus { return message }
        return nil
    }

    private func loadFromPersistence() {
        do {
            let stored = try repository.allVisits()
            let visitsDict = Dictionary(uniqueKeysWithValues: stored.map { ($0.countryId, $0) })
            let visitedIDs = Set(stored.filter { $0.isVisited }.map { $0.countryId })
            let wantToVisitIDs = Set(stored.filter { $0.wantToVisit }.map { $0.countryId })
            
            // OPTIMIZATION: Batch update to trigger only one SwiftUI re-render
            objectWillChange.send()
            self.visits = visitsDict
            self.visitedCountryIDs = visitedIDs
            self.wantToVisitCountryIDs = wantToVisitIDs
        } catch {
            #if DEBUG
            print("⚠️ Failed to load visits from SwiftData: \(error)")
            #endif
            objectWillChange.send()
            self.visits = [:]
            self.visitedCountryIDs = []
            self.wantToVisitCountryIDs = []
        }
    }

    func refreshFromPersistence() {
        loadFromPersistence()
    }
    
    func syncWithCloud(showStatus: Bool = true) async {
        guard let syncService else { 
            #if DEBUG
            print("⚠️ Sync service not available")
            #endif
            return 
        }

        // Prevent concurrent syncs
        guard !isSyncing else {
            #if DEBUG
            print("⚠️ Sync already in progress")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 syncWithCloud called (showStatus: \(showStatus))")
        #endif
        
        // Set syncing state immediately (before network check)
        if showStatus {
            syncStatus = .syncing
            #if DEBUG
            print("📊 Status set to: syncing")
            #endif
        }

        do {
            try await syncService.syncVisits(withRetry: true)
            loadFromPersistence()
            if showStatus {
                syncStatus = .success(Date())
                #if DEBUG
                print("✅ Status set to: success")
                #endif
            }
        } catch let error as SyncError where error == .noConnection {
            print("⚠️ Sync failed: No connection")
            if showStatus {
                syncStatus = .error("No internet connection", isOffline: true)
                #if DEBUG
                print("📊 Status set to: offline error")
                #endif
            }
        } catch let error as FirestoreVisitRepositoryError where error == .notAuthenticated {
            print("⚠️ Sync failed: User not authenticated")
            if showStatus {
                syncStatus = .error("Please sign in to sync your data", isOffline: false)
                #if DEBUG
                print("📊 Status set to: auth error")
                #endif
            }
        } catch {
            #if DEBUG
            print("⚠️ Sync failed: \(error)")
            #endif
            let message = error.localizedDescription
            if showStatus {
                syncStatus = .error(message, isOffline: false)
                #if DEBUG
                print("📊 Status set to: error - \(message)")
                #endif
            }
        }
    }
    
    func retrySyncIfNeeded() async {
        #if DEBUG
        print("🔁 retrySyncIfNeeded called, current status: \(syncStatus)")
        #endif
        // Retry for any error state (including offline - user might have turned WiFi back on)
        if case .error = syncStatus {
            #if DEBUG
            print("🔁 Retrying sync...")
            #endif
            await syncWithCloud()
        } else {
            #if DEBUG
            print("⚠️ Not retrying - not in error state")
            #endif
        }
    }
    
    /// Called when user signs in - loads data from local storage and syncs with cloud
    func handleSignIn() async {
        // Load from local storage first
        loadFromPersistence()
        
        // Then sync with cloud to get latest data
        await syncWithCloud()
    }
    
    /// Called when user signs out - clears all local data
    func handleSignOut() {
        clearLocalDataAfterSignOut()
        syncStatus = .idle
    }
    
    func visit(for countryId: String) -> Visit {
        visits[countryId] ?? Visit(countryId: countryId, isVisited: false, wantToVisit: false, visitedDate: nil, notes: "", photos: [], updatedAt: Date())
    }

    func isVisited(_ countryId: String) -> Bool {
        visit(for: countryId).isVisited
    }
    
    func wantToVisit(_ countryId: String) -> Bool {
        visit(for: countryId).wantToVisit
    }

    func setVisited(_ countryId: String, isVisited: Bool, visitedDate: Date? = nil) {
        // Store old state for rollback in case persistence fails
        let oldVisit = visits[countryId]
        let oldVisitedIDs = visitedCountryIDs
        let oldWantToVisitIDs = wantToVisitCountryIDs
        
        var v = visit(for: countryId)
        v.isVisited = isVisited

        if isVisited {
            v.visitedDate = visitedDate ?? v.visitedDate ?? Date()
            // MUTUAL EXCLUSIVITY: If marking as visited, clear wantToVisit
            v.wantToVisit = false
        } else {
            v.visitedDate = nil
        }
        v.updatedAt = Date()

        // OPTIMIZATION: Batch updates to avoid multiple SwiftUI re-renders
        // Use objectWillChange to manually trigger a single update
        objectWillChange.send()
        
        // Update both properties without triggering individual notifications
        visits[countryId] = v
        if isVisited {
            visitedCountryIDs.insert(countryId)
            wantToVisitCountryIDs.remove(countryId)  // Clear wantToVisit
        } else {
            visitedCountryIDs.remove(countryId)
        }

        // Persist - use upsert to save all fields including wantToVisit
        do {
            try repository.upsert(v)
            Task {
                await syncWithCloud(showStatus: false)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist setVisited: \(error)")
            #endif
            
            // ROLLBACK: Restore old state to keep AppState consistent with DB
            objectWillChange.send()
            if let old = oldVisit {
                visits[countryId] = old
            } else {
                visits.removeValue(forKey: countryId)
            }
            visitedCountryIDs = oldVisitedIDs
            wantToVisitCountryIDs = oldWantToVisitIDs
            
            // Inform user via sync status
            syncStatus = .error("Failed to save changes. Please try again.", isOffline: false)
        }
    }
    
    func setWantToVisit(_ countryId: String, wantToVisit: Bool) {
        // Store old state for rollback in case persistence fails
        let oldVisit = visits[countryId]
        let oldVisitedIDs = visitedCountryIDs
        let oldWantToVisitIDs = wantToVisitCountryIDs
        
        var v = visit(for: countryId)
        v.wantToVisit = wantToVisit
        
        if wantToVisit {
            // MUTUAL EXCLUSIVITY: If marking as wantToVisit, clear visited
            v.isVisited = false
            v.visitedDate = nil
        }
        v.updatedAt = Date()
        
        // OPTIMIZATION: Batch updates to avoid multiple SwiftUI re-renders
        objectWillChange.send()
        
        // Update all related properties atomically
        visits[countryId] = v
        if wantToVisit {
            wantToVisitCountryIDs.insert(countryId)
            visitedCountryIDs.remove(countryId)  // Clear visited
        } else {
            wantToVisitCountryIDs.remove(countryId)
        }
        
        // Persist - use upsert to save all fields including isVisited
        do {
            try repository.upsert(v)
            Task {
                await syncWithCloud(showStatus: false)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist setWantToVisit: \(error)")
            #endif
            
            // ROLLBACK: Restore old state to keep AppState consistent with DB
            objectWillChange.send()
            if let old = oldVisit {
                visits[countryId] = old
            } else {
                visits.removeValue(forKey: countryId)
            }
            visitedCountryIDs = oldVisitedIDs
            wantToVisitCountryIDs = oldWantToVisitIDs
            
            // Inform user via sync status
            syncStatus = .error("Failed to save changes. Please try again.", isOffline: false)
        }
    }

    func updateNotes(_ countryId: String, notes: String) {
        var v = visit(for: countryId)
        v.notes = notes
        v.updatedAt = Date()
        
        // OPTIMIZATION: Manual notification to avoid triggering @Published twice
        objectWillChange.send()
        visits[countryId] = v

        do {
            try repository.updateNotes(countryId, notes: notes)
            Task {
                await syncWithCloud(showStatus: false)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist updateNotes: \(error)")
            #endif
        }
    }
    
    func addPhoto(_ countryId: String, photo: VisitPhoto) {
        var v = visit(for: countryId)
        v.photos.append(photo)
        v.updatedAt = Date()
        
        // OPTIMIZATION: Manual notification to avoid triggering @Published twice
        objectWillChange.send()
        visits[countryId] = v
        
        do {
            try repository.addPhoto(countryId, photo: photo)
            Task {
                await syncWithCloud(showStatus: false)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist addPhoto: \(error)")
            #endif
        }
    }
    
    func removePhoto(_ countryId: String, photoId: UUID) {
        var v = visit(for: countryId)
        v.photos.removeAll { $0.id == photoId }
        v.updatedAt = Date()

        // OPTIMIZATION: Manual notification to avoid triggering @Published twice
        objectWillChange.send()
        visits[countryId] = v

        do {
            try repository.removePhoto(countryId, photoId: photoId)
            Task {
                // Delete from cloud subcollection first so the subsequent full sync
                // doesn't re-download the just-deleted photo.
                await syncService?.deleteCloudPhoto(countryId: countryId, photoId: photoId)
                await syncWithCloud(showStatus: false)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to persist removePhoto: \(error)")
            #endif
        }
    }
    
    func updatePhotoCaption(_ countryId: String, photoId: UUID, caption: String) {
        var v = visit(for: countryId)
        if let index = v.photos.firstIndex(where: { $0.id == photoId }) {
            v.photos[index].caption = caption
            v.updatedAt = Date()
            
            // OPTIMIZATION: Manual notification to avoid triggering @Published twice
            objectWillChange.send()
            visits[countryId] = v
            
            do {
                try repository.updatePhotoCaption(countryId, photoId: photoId, caption: caption)
                Task {
                    await syncWithCloud(showStatus: false)
                }
            } catch {
                #if DEBUG
                print("⚠️ Failed to persist updatePhotoCaption: \(error)")
                #endif
            }
        }
    }

    var visitedCount: Int {
        visits.values.filter { $0.isVisited }.count
    }
    
    var wantToVisitCount: Int {
        visits.values.filter { $0.wantToVisit }.count
    }
    
    func clearLocalState() {
        // OPTIMIZATION: Batch update to trigger only one SwiftUI re-render
        objectWillChange.send()
        visits = [:]
        visitedCountryIDs = []
        wantToVisitCountryIDs = []
    }
    
    func clearLocalDataAfterSignOut() {
        do {
            if let localRepository = repository as? SwiftDataVisitRepository {
                try localRepository.deleteAllVisits()
            }
            clearLocalState()
        } catch {
            #if DEBUG
            print("⚠️ Failed to clear local data after sign out: \(error)")
            #endif
        }
    }
}
