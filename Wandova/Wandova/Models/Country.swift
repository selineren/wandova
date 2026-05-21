//
//  Country.swift
//  Wandova
//
//  Created by seren on 25.02.2026.
//

import Foundation

struct Country: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let continent: Continent
    let flagEmoji: String
    let centroid: Coordinate
}
