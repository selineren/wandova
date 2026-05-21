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
    
    init(id: UUID = UUID(), imageData: Data, caption: String = "", createdAt: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.caption = caption
        self.createdAt = createdAt
    }
}

