//
//  Visit.swift
//  Wandova
//
//  Created by seren on 25.02.2026.
//

import Foundation

struct Visit: Equatable {
    let countryId: String
    var isVisited: Bool
    var wantToVisit: Bool
    var visitedDate: Date?
    var notes: String
    var photos: [VisitPhoto]
    var updatedAt: Date
}
struct VisitPhoto: Equatable, Codable, Identifiable {
    let id: UUID
    var imageData: Data
    var caption: String
    var createdAt: Date
    /// When the caption was last edited — drives caption last-write-wins in sync.
    var captionUpdatedAt: Date

    init(id: UUID = UUID(), imageData: Data, caption: String = "", createdAt: Date = Date(), captionUpdatedAt: Date? = nil) {
        self.id = id
        self.imageData = imageData
        self.caption = caption
        self.createdAt = createdAt
        self.captionUpdatedAt = captionUpdatedAt ?? createdAt
    }

    // Photos persisted before captionUpdatedAt existed must still decode —
    // the local store swallows decode errors and would wipe them otherwise.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decode(Data.self, forKey: .imageData)
        caption = try container.decode(String.self, forKey: .caption)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        captionUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .captionUpdatedAt) ?? createdAt
    }
}

