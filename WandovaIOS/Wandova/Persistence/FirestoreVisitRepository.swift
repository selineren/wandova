//
//  FirestoreVisitRepository.swift
//  Wandova
//
//  Created by seren on 10.03.2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

final class FirestoreVisitRepository {
    private let db = Firestore.firestore()

    // MARK: - Public API

    func visit(for countryId: String) async throws -> Visit {
        let doc = try await getVisitDocument(countryId: countryId)

        guard let data = doc.data() else {
            throw FirestoreVisitRepositoryError.documentNotFound
        }

        return try mapVisit(countryId: countryId, data: data)
    }

    func allVisits() async throws -> [Visit] {
        let userID = try requireUserID()

        let snapshot = try await getDocuments(
            from: db.collection("users")
                .document(userID)
                .collection("visits")
        )

        return try snapshot.documents.map { document in
            try mapVisit(countryId: document.documentID, data: document.data())
        }
    }
    
    /// Fetch all visits for a specific user (read-only)
    /// Used for travel comparison - can only read users who have allowComparison enabled
    /// - Parameter userId: The Firebase Auth user ID to fetch visits for
    /// - Returns: Array of Visit objects for the specified user
    /// - Throws: FirestoreVisitRepositoryError if the fetch fails
    /// - Note: This is a read-only operation. No write access to other users' data is possible.
    func allVisits(forUserId userId: String) async throws -> [Visit] {
        // Ensure we're authenticated (even though we're reading someone else's data)
        _ = try requireUserID()
        
        let snapshot = try await getDocuments(
            from: db.collection("users")
                .document(userId)
                .collection("visits")
        )

        return try snapshot.documents.map { document in
            try mapVisit(countryId: document.documentID, data: document.data())
        }
    }

    func setVisited(_ countryId: String, isVisited: Bool, visitedDate: Date?, notes: String, wantToVisit: Bool = false) async throws {
        let userID = try requireUserID()

        let data: [String: Any] = [
            "isVisited": isVisited,
            "wantToVisit": wantToVisit,
            "visitedDate": visitedDate as Any,
            "notes": notes,
            "updatedAt": Timestamp(date: Date())
        ]

        try await setData(
            data,
            for: db.collection("users")
                .document(userID)
                .collection("visits")
                .document(countryId)
        )
    }

    /// Writes visit metadata to Firestore. Photos are stored separately in the photos subcollection.
    func setVisit(_ visit: Visit) async throws {
        let userID = try requireUserID()
        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(visit.countryId)

        let data: [String: Any] = [
            "isVisited": visit.isVisited,
            "wantToVisit": visit.wantToVisit,
            "visitedDate": visit.visitedDate as Any,
            "notes": visit.notes,
            "updatedAt": Timestamp(date: visit.updatedAt)
        ]

        try await setData(data, for: ref)
    }

    func updateNotes(_ countryId: String, notes: String) async throws {
        let userID = try requireUserID()

        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)

        let data: [String: Any] = [
            "notes": notes,
            "updatedAt": Timestamp(date: Date())
        ]

        try await updateData(data, for: ref)
    }
    
    func addPhoto(_ countryId: String, photo: VisitPhoto) async throws {
        let userID = try requireUserID()
        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)
        
        // Fetch current visit to get existing photos
        let visit = try await self.visit(for: countryId)
        var photos = visit.photos
        photos.append(photo)
        
        // Encode photos as Base64 string for Firestore
        let photosBase64 = try encodePhotosToBase64(photos)
        
        let data: [String: Any] = [
            "photos": photosBase64,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await updateData(data, for: ref)
    }
    
    func removePhoto(_ countryId: String, photoId: UUID) async throws {
        let userID = try requireUserID()
        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)
        
        // Fetch current visit to get existing photos
        let visit = try await self.visit(for: countryId)
        var photos = visit.photos
        photos.removeAll { $0.id == photoId }
        
        // Encode photos as Base64 string for Firestore
        let photosBase64 = try encodePhotosToBase64(photos)
        
        let data: [String: Any] = [
            "photos": photosBase64,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await updateData(data, for: ref)
    }
    
    func updatePhotoCaption(_ countryId: String, photoId: UUID, caption: String) async throws {
        let userID = try requireUserID()
        let ref = db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)
        
        // Fetch current visit to get existing photos
        let visit = try await self.visit(for: countryId)
        var photos = visit.photos
        
        if let index = photos.firstIndex(where: { $0.id == photoId }) {
            photos[index].caption = caption
            
            // Encode photos as Base64 string for Firestore
            let photosBase64 = try encodePhotosToBase64(photos)
            
            let data: [String: Any] = [
                "photos": photosBase64,
                "updatedAt": Timestamp(date: Date())
            ]
            
            try await updateData(data, for: ref)
        }
    }

    func deleteVisit(_ countryId: String) async throws {
        let userID = try requireUserID()

        try await deleteDocument(
            db.collection("users")
                .document(userID)
                .collection("visits")
                .document(countryId)
        )
    }
    
    /// Delete all visit documents for the current user
    /// Used during account deletion to clean up cloud data before removing the Firebase Auth account
    /// - Throws: `FirestoreVisitRepositoryError.notAuthenticated` if no user is signed in
    /// - Note: Succeeds silently if the user has no visit documents (empty collection is valid)
    func deleteAllUserVisits() async throws {
        let userID = try requireUserID()
        
        // Fetch all visit documents for this user
        let snapshot = try await getDocuments(
            from: db.collection("users")
                .document(userID)
                .collection("visits")
        )
        
        // Delete each document individually
        // Note: Firestore doesn't support batch deletes via the client SDK for collections,
        // so we must delete each document separately
        for document in snapshot.documents {
            try await deleteDocument(document.reference)
        }
        
        #if DEBUG
        print("🗑️ Deleted \(snapshot.documents.count) visit document(s) for user \(userID)")
        #else
        print("🗑️ Deleted \(snapshot.documents.count) visit document(s)")
        #endif
    }

    // MARK: - Helpers

    private func requireUserID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreVisitRepositoryError.notAuthenticated
        }
        return uid
    }

    private func getVisitDocument(countryId: String) async throws -> DocumentSnapshot {
        let userID = try requireUserID()

        return try await getDocument(
            from: db.collection("users")
                .document(userID)
                .collection("visits")
                .document(countryId)
        )
    }

    private func mapVisit(countryId: String, data: [String: Any]) throws -> Visit {
        guard let isVisited = data["isVisited"] as? Bool else {
            throw FirestoreVisitRepositoryError.invalidData
        }

        // Backward compatible: default to false if field doesn't exist in Firestore
        let wantToVisit = data["wantToVisit"] as? Bool ?? false
        
        // VALIDATION: Enforce mutual exclusivity
        // If cloud data has both states true (corrupted), visited takes priority
        let validatedIsVisited: Bool
        let validatedWantToVisit: Bool
        
        if isVisited && wantToVisit {
            #if DEBUG
            print("⚠️ Data integrity issue for \(countryId): both isVisited and wantToVisit are true")
            print("   Resolving by prioritizing visited state (clearing wantToVisit)")
            #endif
            // Visited is more important state - it has a date and represents completed travel
            validatedIsVisited = true
            validatedWantToVisit = false
        } else {
            validatedIsVisited = isVisited
            validatedWantToVisit = wantToVisit
        }
        
        let notes = data["notes"] as? String ?? ""

        let visitedDate: Date?
        if let timestamp = data["visitedDate"] as? Timestamp {
            visitedDate = timestamp.dateValue()
        } else {
            visitedDate = nil
        }
        
        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            throw FirestoreVisitRepositoryError.invalidData
        }
        
        // Decode photos from Base64-encoded JSON array
        let photos: [VisitPhoto]
        if let photosBase64 = data["photos"] as? String,
           let photosData = Data(base64Encoded: photosBase64) {
            photos = (try? JSONDecoder().decode([VisitPhoto].self, from: photosData)) ?? []
        } else {
            photos = []
        }
        
        // Ensure visited countries have a date - if missing, use updatedAt as best guess
        let finalVisitedDate: Date?
        if validatedIsVisited {
            finalVisitedDate = visitedDate ?? updatedAt
        } else {
            finalVisitedDate = nil
        }

        return Visit(
            countryId: countryId,
            isVisited: validatedIsVisited,
            wantToVisit: validatedWantToVisit,
            visitedDate: finalVisitedDate,
            notes: notes,
            photos: photos,
            updatedAt: updatedAt
        )
    }

    // MARK: - Async wrappers

    private func getDocument(from ref: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            // Use source: .server to force network fetch, not cache
            ref.getDocument(source: .server) { snapshot, error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                    return
                }

                guard let snapshot else {
                    continuation.resume(throwing: FirestoreVisitRepositoryError.documentNotFound)
                    return
                }

                continuation.resume(returning: snapshot)
            }
        }
    }

    private func getDocuments(from ref: CollectionReference) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            // Use source: .server to force network fetch, not cache
            ref.getDocuments(source: .server) { snapshot, error in
                if let error {
                    #if DEBUG
                    print("🔥 Firestore error: \(error)")
                    #endif
                    continuation.resume(throwing: self.mapError(error))
                    return
                }

                guard let snapshot else {
                    #if DEBUG
                    print("🔥 Firestore: No snapshot returned")
                    #endif
                    continuation.resume(throwing: FirestoreVisitRepositoryError.invalidData)
                    return
                }
                
                #if DEBUG
                // Check if this data came from cache despite requesting server
                print("🔥 Firestore snapshot: \(snapshot.documents.count) docs, metadata.isFromCache: \(snapshot.metadata.isFromCache)")
                #endif
                
                // If we requested server but got cache, and we're offline, throw error
                if snapshot.metadata.isFromCache {
                    #if DEBUG
                    print("⚠️ Received cached data when server was requested - treating as offline")
                    #endif
                    continuation.resume(throwing: FirestoreVisitRepositoryError.offline)
                    return
                }

                continuation.resume(returning: snapshot)
            }
        }
    }

    private func setData(_ data: [String: Any], for ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(data) { error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func updateData(_ data: [String: Any], for ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateData(data) { error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteDocument(_ ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func mapError(_ error: Error) -> FirestoreVisitRepositoryError {
        let nsError = error as NSError

        // 7 is permission denied in gRPC / Firestore permission failures
        if nsError.code == 7 {
            return .permissionDenied
        }

        return .unknown(error)
    }
    
    // MARK: - Photo Subcollection

    /// Syncs photos for a country using the photos subcollection.
    /// Uploads local-only photos to cloud and returns the union of local + cloud-only photos.
    func syncPhotos(countryId: String, localPhotos: [VisitPhoto]) async throws -> [VisitPhoto] {
        let userID = try requireUserID()
        let ref = photosCollection(userID: userID, countryId: countryId)
        let snapshot = try await getDocuments(from: ref)
        let cloudPhotos = snapshot.documents.compactMap { photoFromDocument($0) }

        let cloudIds = Set(cloudPhotos.map { $0.id })
        let localIds  = Set(localPhotos.map { $0.id })

        for photo in localPhotos where !cloudIds.contains(photo.id) {
            try await setData(photoDocument(photo), for: ref.document(photo.id.uuidString))
        }

        return localPhotos + cloudPhotos.filter { !localIds.contains($0.id) }
    }

    func deletePhoto(countryId: String, photoId: UUID) async throws {
        let userID = try requireUserID()
        try await deleteDocument(
            photosCollection(userID: userID, countryId: countryId).document(photoId.uuidString)
        )
    }

    private func photosCollection(userID: String, countryId: String) -> CollectionReference {
        db.collection("users")
            .document(userID)
            .collection("visits")
            .document(countryId)
            .collection("photos")
    }

    private func photoDocument(_ photo: VisitPhoto) -> [String: Any] {
        [
            "imageData": photo.imageData.base64EncodedString(),
            "caption": photo.caption,
            "createdAt": Timestamp(date: photo.createdAt)
        ]
    }

    private func photoFromDocument(_ doc: QueryDocumentSnapshot) -> VisitPhoto? {
        let data = doc.data()
        guard let s = data["imageData"] as? String,
              let imageData = Data(base64Encoded: s) else { return nil }
        return VisitPhoto(
            id: UUID(uuidString: doc.documentID) ?? UUID(),
            imageData: imageData,
            caption: data["caption"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    // MARK: - Photo encoding (legacy: used by addPhoto/removePhoto/updatePhotoCaption)

    private func encodePhotosToBase64(_ photos: [VisitPhoto]) throws -> String {
        let jsonData = try JSONEncoder().encode(photos)
        return jsonData.base64EncodedString()
    }
}
