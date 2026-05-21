//
//  SwiftDataVisitRepository.swift
//  Wandova
//
//  Created by seren on 2.03.2026.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataVisitRepository: VisitRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func visit(for countryId: String) throws -> Visit {
        if let entity = try fetchEntity(countryId: countryId) {
            let photos = decodePhotos(from: entity.photosData)
            #if DEBUG
            print("📸 Loading visit for \(countryId) - photos count: \(photos.count)")
            #endif
            return Visit(
                countryId: entity.countryId,
                isVisited: entity.isVisited,
                wantToVisit: entity.wantToVisit,
                visitedDate: entity.visitedDate,
                notes: entity.notes,
                photos: photos,
                updatedAt: entity.updatedAt
            )
        }

        // default "not visited"
        #if DEBUG
        print("📸 Creating new visit for \(countryId) - no existing entity")
        #endif
        return Visit(countryId: countryId, isVisited: false, wantToVisit: false, visitedDate: nil, notes: "", photos: [], updatedAt: Date())
    }
    
    func allVisits() throws -> [Visit] {
        let descriptor = FetchDescriptor<VisitEntity>()
        let entities = try context.fetch(descriptor)
        return entities.map {
            Visit(
                countryId: $0.countryId,
                isVisited: $0.isVisited,
                wantToVisit: $0.wantToVisit,
                visitedDate: $0.visitedDate,
                notes: $0.notes,
                photos: decodePhotos(from: $0.photosData),
                updatedAt: $0.updatedAt
            )
        }
    }
    
    func deleteAllVisits() throws {
        let descriptor = FetchDescriptor<VisitEntity>()
        let entities = try context.fetch(descriptor)

        for entity in entities {
            context.delete(entity)
        }

        try context.save()
    }

    func setVisited(_ countryId: String, isVisited: Bool, visitedDate: Date?) throws {
        let entity = try fetchOrCreateEntity(countryId: countryId)

        entity.isVisited = isVisited

        if isVisited {
            // IMPORTANT: allow choosing date; if none provided, keep existing; if none exists, default today
            entity.visitedDate = visitedDate ?? entity.visitedDate ?? Date()
        } else {
            entity.visitedDate = nil
            // keep notes (better UX) — do NOT wipe them
        }
        
        entity.updatedAt = Date()

        try context.save()
    }
    
    func setWantToVisit(_ countryId: String, wantToVisit: Bool) throws {
        let entity = try fetchOrCreateEntity(countryId: countryId)
        entity.wantToVisit = wantToVisit
        entity.updatedAt = Date()
        try context.save()
    }

    func updateNotes(_ countryId: String, notes: String) throws {
        let entity = try fetchOrCreateEntity(countryId: countryId)
        entity.notes = notes
        entity.updatedAt = Date()
        try context.save()
    }
    
    func addPhoto(_ countryId: String, photo: VisitPhoto) throws {
        let entity = try fetchOrCreateEntity(countryId: countryId)
        var photos = decodePhotos(from: entity.photosData)
        #if DEBUG
        print("📸 Before adding photo - Country: \(countryId), existing photos: \(photos.count)")
        #endif
        photos.append(photo)
        entity.photosData = encodePhotos(photos)
        entity.updatedAt = Date()
        try context.save()
        #if DEBUG
        print("📸 After saving photo - Country: \(countryId), total photos: \(photos.count)")
        
        // Verify save
        let verifyEntity = try fetchEntity(countryId: countryId)
        let verifyPhotos = decodePhotos(from: verifyEntity?.photosData)
        print("📸 Verification - Country: \(countryId), photos in DB: \(verifyPhotos.count)")
        #endif
    }
    
    func removePhoto(_ countryId: String, photoId: UUID) throws {
        let entity = try fetchOrCreateEntity(countryId: countryId)
        var photos = decodePhotos(from: entity.photosData)
        photos.removeAll { $0.id == photoId }
        entity.photosData = encodePhotos(photos)
        entity.updatedAt = Date()
        try context.save()
    }
    
    func updatePhotoCaption(_ countryId: String, photoId: UUID, caption: String) throws {
        let entity = try fetchOrCreateEntity(countryId: countryId)
        var photos = decodePhotos(from: entity.photosData)
        if let index = photos.firstIndex(where: { $0.id == photoId }) {
            photos[index].caption = caption
            entity.photosData = encodePhotos(photos)
            entity.updatedAt = Date()
            try context.save()
        }
    }
    
    func upsert(_ visit: Visit) throws {
        let entity = try fetchOrCreateEntity(countryId: visit.countryId)
        entity.isVisited = visit.isVisited
        entity.wantToVisit = visit.wantToVisit
        
        // Enforce invariant: visited countries must have a date
        if visit.isVisited {
            entity.visitedDate = visit.visitedDate ?? entity.visitedDate ?? visit.updatedAt
        } else {
            entity.visitedDate = nil
        }
        
        entity.notes = visit.notes
        entity.photosData = encodePhotos(visit.photos)
        entity.updatedAt = visit.updatedAt
        try context.save()
    }

    func visitedCount() throws -> Int {
        let descriptor = FetchDescriptor<VisitEntity>(
            predicate: #Predicate { $0.isVisited == true }
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - Private helpers

    private func fetchEntity(countryId: String) throws -> VisitEntity? {
        let descriptor = FetchDescriptor<VisitEntity>(
            predicate: #Predicate { $0.countryId == countryId }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchOrCreateEntity(countryId: String) throws -> VisitEntity {
        if let existing = try fetchEntity(countryId: countryId) {
            return existing
        }
        let created = VisitEntity(countryId: countryId)
        context.insert(created)
        return created
    }
    
    // MARK: - Photo encoding/decoding
    
    private func decodePhotos(from data: Data?) -> [VisitPhoto] {
        guard let data = data else { return [] }
        return (try? JSONDecoder().decode([VisitPhoto].self, from: data)) ?? []
    }
    
    private func encodePhotos(_ photos: [VisitPhoto]) -> Data? {
        try? JSONEncoder().encode(photos)
    }
}
