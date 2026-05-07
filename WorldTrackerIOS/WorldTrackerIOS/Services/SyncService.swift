//
//  SyncService.swift
//  WorldTrackerIOS
//
//  Created by seren on 11.03.2026.
//

import Foundation
import FirebaseAuth

@MainActor
final class SyncService {
    private let localRepository: SwiftDataVisitRepository
    private let cloudRepository: FirestoreVisitRepository
    private let networkMonitor: NetworkMonitor
    
    private var isSyncing = false
    private(set) var lastSyncDate: Date?
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0

    init(
        localRepository: SwiftDataVisitRepository,
        cloudRepository: FirestoreVisitRepository,
        networkMonitor: NetworkMonitor? = nil
    ) {
        self.localRepository = localRepository
        self.cloudRepository = cloudRepository
        self.networkMonitor = networkMonitor ?? .shared
    }

    func syncVisits(withRetry: Bool = true) async throws {
        #if DEBUG
        print("🌐 Network status check: isConnected = \(networkMonitor.isConnected)")
        #endif
        
        // AUTH GUARD: Don't sync if user is not authenticated
        guard Auth.auth().currentUser != nil else {
            print("⚠️ Sync skipped: User is not authenticated")
            throw FirestoreVisitRepositoryError.notAuthenticated
        }
        
        // Prevent concurrent syncs
        guard !isSyncing else {
            #if DEBUG
            print("⚠️ Sync already in progress, skipping")
            #endif
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        #if DEBUG
        print("🔄 Starting sync...")
        #endif
        
        var lastError: Error?
        let attempts = withRetry ? maxRetries : 1
        
        for attempt in 1...attempts {
            do {
                try await performSync()
                lastSyncDate = Date()
                #if DEBUG
                print("✅ Sync complete on attempt \(attempt)")
                #endif
                return
            } catch let error as SyncError where error == .noConnection {
                // Don't retry network errors - user needs to fix connectivity
                print("❌ Sync failed: No connection (will not retry)")
                throw error
            } catch let error as FirestoreVisitRepositoryError where error == .notAuthenticated {
                // Don't retry auth errors - user needs to sign in
                print("❌ Sync failed: User not authenticated (will not retry)")
                throw error
            } catch {
                lastError = error
                #if DEBUG
                print("⚠️ Sync attempt \(attempt) failed: \(error)")
                #endif
                
                // If we have more attempts, wait before retrying
                if attempt < attempts {
                    #if DEBUG
                    print("⏳ Retrying in \(retryDelay) seconds...")
                    #endif
                    try await Task.sleep(for: .seconds(retryDelay))
                    // Removed network check - let the actual sync attempt determine if there's a connection
                }
            }
        }
        
        // All retries failed
        if let error = lastError {
            print("❌ Sync failed after \(attempts) attempts")
            throw SyncError.syncFailed(underlying: error, attempts: attempts)
        }
    }
    
    
    private func performSync() async throws {
        do {
            let localVisits = try localRepository.allVisits()
            let cloudVisits = try await cloudRepository.allVisits()

            let localById = Dictionary(uniqueKeysWithValues: localVisits.map { ($0.countryId, $0) })
            let cloudById = Dictionary(uniqueKeysWithValues: cloudVisits.map { ($0.countryId, $0) })

            let allCountryIDs = Set(localById.keys).union(cloudById.keys)

            var syncedCount = 0
            var errorCount = 0
            
            for countryId in allCountryIDs {
                let localVisit = localById[countryId]
                let cloudVisit = cloudById[countryId]

                do {
                    switch (localVisit, cloudVisit) {
                    case let (local?, cloud?):
                        // Both exist - use most recent
                        if local.updatedAt > cloud.updatedAt {
                            try await pushToCloud(local)
                            syncedCount += 1
                        } else if cloud.updatedAt > local.updatedAt {
                            try saveToLocal(cloud)
                            syncedCount += 1
                        }
                        // if equal, do nothing

                    case let (local?, nil):
                        // Only local - push to cloud
                        try await pushToCloud(local)
                    syncedCount += 1

                case let (nil, cloud?):
                    // Only cloud - save to local
                    try saveToLocal(cloud)
                    syncedCount += 1

                case (nil, nil):
                    break
                }
            } catch {
                #if DEBUG
                print("⚠️ Failed to sync country \(countryId): \(error)")
                #endif
                errorCount += 1
                // Continue with other countries
            }
        }
            
            #if DEBUG
            print("✅ Metadata sync complete: \(syncedCount) synced, \(errorCount) errors")
            #endif

            if errorCount > 0 {
                throw SyncError.partialFailure(syncedCount: syncedCount, failedCount: errorCount)
            }

            // Phase 2: Photo sync via subcollection (no 1 MB document size limit).
            // Errors here are non-fatal — metadata sync already succeeded.
            // Re-read local state — some visits may have been added by saveToLocal above.
            let currentLocalVisits = try localRepository.allVisits()
            let currentLocalById = Dictionary(uniqueKeysWithValues: currentLocalVisits.map { ($0.countryId, $0) })

            for countryId in allCountryIDs {
                let localPhotos = currentLocalById[countryId]?.photos ?? []
                do {
                    let mergedPhotos = try await cloudRepository.syncPhotos(
                        countryId: countryId, localPhotos: localPhotos
                    )
                    if mergedPhotos.count != localPhotos.count,
                       var localVisit = currentLocalById[countryId] {
                        localVisit.photos = mergedPhotos
                        try localRepository.upsert(localVisit)
                    }
                } catch let error as FirestoreVisitRepositoryError where error == .offline {
                    throw error  // propagates to outer catch → .noConnection
                } catch {
                    #if DEBUG
                    print("⚠️ Photo sync failed for \(countryId): \(error)")
                    #endif
                    // Non-fatal: metadata sync succeeded; photos will retry on next sync
                }
            }

            #if DEBUG
            print("✅ Photo sync complete")
            #endif
        } catch {
            // Check if it's a network error
            let nsError = error as NSError
            let errorDescription = error.localizedDescription.lowercased()
            
            #if DEBUG
            print("🔍 Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
            print("🔍 Error description: \(error.localizedDescription)")
            print("🔍 NetworkMonitor.isConnected: \(networkMonitor.isConnected)")
            #endif
            
            // Check if it's our custom offline error
            if let repoError = error as? FirestoreVisitRepositoryError, repoError == .offline {
                #if DEBUG
                print("❌ Firestore offline error detected (from cache check)")
                #endif
                throw SyncError.noConnection
            }
            
            // Common network error codes and domains
            let isNetworkError = nsError.domain == NSURLErrorDomain ||
                                nsError.code == NSURLErrorNotConnectedToInternet ||
                                nsError.code == NSURLErrorNetworkConnectionLost ||
                                nsError.code == NSURLErrorTimedOut ||
                                nsError.code == NSURLErrorCannotConnectToHost ||
                                nsError.code == NSURLErrorCannotFindHost ||
                                (nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 14) || // Firestore unavailable
                                (nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7) ||  // Permission denied (often when offline)
                                errorDescription.contains("network") ||
                                errorDescription.contains("offline") ||
                                errorDescription.contains("internet") ||
                                errorDescription.contains("connection") ||
                                !networkMonitor.isConnected
            
            if isNetworkError {
                #if DEBUG
                print("❌ Network error detected: \(error)")
                #endif
                throw SyncError.noConnection
            } else {
                #if DEBUG
                print("❌ Non-network error detected: \(error)")
                #endif
                // Re-throw other errors
                throw error
            }
        }
    }

    private func pushToCloud(_ visit: Visit) async throws {
        try await cloudRepository.setVisit(visit)
    }

    private func saveToLocal(_ visit: Visit) throws {
        var merged = visit
        let existing = try? localRepository.visit(for: visit.countryId)
        if let existing, !existing.photos.isEmpty {
            // Prefer local photos; photo subcollection sync handles cross-device transfer
            merged.photos = existing.photos
        }
        // If no existing local photos, preserve any photos decoded from the legacy "photos"
        // field (old Firestore format) so the first sync on a new device migrates them.
        try localRepository.upsert(merged)
    }

    /// Deletes a single photo from the Firestore photos subcollection. Best-effort — errors are logged but not thrown.
    func deleteCloudPhoto(countryId: String, photoId: UUID) async {
        guard Auth.auth().currentUser != nil else { return }
        do {
            try await cloudRepository.deletePhoto(countryId: countryId, photoId: photoId)
        } catch {
            #if DEBUG
            print("⚠️ Failed to delete cloud photo \(photoId) for \(countryId): \(error)")
            #endif
        }
    }
}

enum SyncError: LocalizedError, Equatable {
    case noConnection
    case syncFailed(underlying: Error, attempts: Int)
    case partialFailure(syncedCount: Int, failedCount: Int)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .syncFailed(let error, let attempts):
            return "Sync failed after \(attempts) attempt(s): \(error.localizedDescription)"
        case .partialFailure(let synced, let failed):
            return "Partial sync: \(synced) succeeded, \(failed) failed"
        }
    }
    
    static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection):
            return true
        case let (.syncFailed(_, attempts1), .syncFailed(_, attempts2)):
            return attempts1 == attempts2
        case let (.partialFailure(s1, f1), .partialFailure(s2, f2)):
            return s1 == s2 && f1 == f2
        default:
            return false
        }
    }
}

