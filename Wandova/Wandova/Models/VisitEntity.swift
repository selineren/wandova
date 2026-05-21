//
//  VisitEntity.swift
//  Wandova
//
//  Created by seren on 2.03.2026.
//

import Foundation
import SwiftData

@Model
final class VisitEntity {
    @Attribute(.unique) var countryId: String
    var isVisited: Bool
    var wantToVisit: Bool = false
    var visitedDate: Date?
    var notes: String
    var photosData: Data? // JSON-encoded array of VisitPhoto
    var updatedAt: Date

    init(countryId: String, isVisited: Bool = false, wantToVisit: Bool = false, visitedDate: Date? = nil, notes: String = "", photosData: Data? = nil, updatedAt: Date = Date ()) {
        self.countryId = countryId
        self.isVisited = isVisited
        self.wantToVisit = wantToVisit
        self.visitedDate = visitedDate
        self.notes = notes
        self.photosData = photosData
        self.updatedAt = updatedAt
    }
}
