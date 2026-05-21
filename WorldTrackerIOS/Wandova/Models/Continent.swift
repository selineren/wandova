//
//  Continent.swift
//  Wandova
//
//  Created by seren on 25.02.2026.
//

import Foundation

enum Continent: String, CaseIterable, Identifiable, Codable {
    case africa
    case antarctica
    case asia
    case europe
    case northAmerica
    case oceania
    case southAmerica

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .africa: return "Africa"
        case .antarctica: return "Antarctica"
        case .asia: return "Asia"
        case .europe: return "Europe"
        case .northAmerica: return "North America"
        case .oceania: return "Oceania"
        case .southAmerica: return "South America"
        }
    }
}
