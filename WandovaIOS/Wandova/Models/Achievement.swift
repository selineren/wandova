//
//  Achievement.swift
//  Wandova
//
//  Created by seren on 04.04.2026.
//

import Foundation

// MARK: - Achievement Type

/// Defines the different types of achievements available in the app
enum AchievementType: Equatable, Hashable {
    case firstCountry
    case countries(Int)
    case firstNote
    case firstPhoto
    case continents(Int)
    case allContinents
    
    var id: String {
        switch self {
        case .firstCountry:
            return "first_country"
        case .countries(let count):
            return "countries_\(count)"
        case .firstNote:
            return "first_note"
        case .firstPhoto:
            return "first_photo"
        case .continents(let count):
            return "continents_\(count)"
        case .allContinents:
            return "all_continents"
        }
    }
}

// MARK: - Achievement

/// Represents a single achievement that can be earned by the user
struct Achievement: Identifiable, Equatable {
    let id: String
    let type: AchievementType
    let title: String
    let description: String
    let icon: String // SF Symbol name
    let isUnlocked: Bool
    let progress: Double? // Optional: 0.0 to 1.0 for progressive achievements
    let unlockedDate: Date? // When the achievement was earned
    
    init(
        type: AchievementType,
        title: String,
        description: String,
        icon: String,
        isUnlocked: Bool,
        progress: Double? = nil,
        unlockedDate: Date? = nil
    ) {
        self.id = type.id
        self.type = type
        self.title = title
        self.description = description
        self.icon = icon
        self.isUnlocked = isUnlocked
        self.progress = progress
        self.unlockedDate = unlockedDate
    }
}

// MARK: - Achievement Engine

/// Pure functions to calculate achievements from user data
/// All functions are static and have no side effects
enum AchievementEngine {
    
    /// Calculate all achievements based on current visit data
    /// - Parameters:
    ///   - visits: Dictionary of all visits keyed by country ID
    ///   - countries: Array of all available countries
    /// - Returns: Array of all achievements with unlock status
    static func calculateAchievements(
        visits: [String: Visit],
        countries: [Country]
    ) -> [Achievement] {
        // Extract visited countries
        let visitedVisits = visits.values.filter { $0.isVisited }
        let visitedCount = visitedVisits.count
        
        // Calculate continent coverage
        let visitedCountryIDs = Set(visitedVisits.map { $0.countryId })
        let visitedCountries = countries.filter { visitedCountryIDs.contains($0.id) }
        let visitedContinents = Set(visitedCountries.map { $0.continent })
        let continentCount = visitedContinents.count
        
        // Count notes and photos
        let notesCount = visitedVisits.filter { !$0.notes.isEmpty }.count
        let totalPhotos = visitedVisits.reduce(0) { $0 + $1.photos.count }
        
        // Find earliest visit date for unlocked achievements
        let earliestVisitDate = visitedVisits
            .compactMap { $0.visitedDate }
            .min()
        
        // Find first note date
        let firstNoteDate = visitedVisits
            .filter { !$0.notes.isEmpty }
            .compactMap { $0.visitedDate ?? $0.updatedAt }
            .min()
        
        // Find first photo date
        let firstPhotoDate = visitedVisits
            .filter { !$0.photos.isEmpty }
            .compactMap { $0.visitedDate ?? $0.updatedAt }
            .min()
        
        // Define all achievements
        var achievements: [Achievement] = []
        
        // MARK: First Steps
        
        achievements.append(Achievement(
            type: .firstCountry,
            title: "First Steps",
            description: "Visit your first country",
            icon: "flag.fill",
            isUnlocked: visitedCount >= 1,
            progress: visitedCount >= 1 ? 1.0 : 0.0,
            unlockedDate: visitedCount >= 1 ? earliestVisitDate : nil
        ))
        
        achievements.append(Achievement(
            type: .firstNote,
            title: "Memory Keeper",
            description: "Add your first note",
            icon: "note.text",
            isUnlocked: notesCount >= 1,
            progress: notesCount >= 1 ? 1.0 : 0.0,
            unlockedDate: notesCount >= 1 ? firstNoteDate : nil
        ))
        
        achievements.append(Achievement(
            type: .firstPhoto,
            title: "Photographer",
            description: "Add your first photo",
            icon: "camera.fill",
            isUnlocked: totalPhotos >= 1,
            progress: totalPhotos >= 1 ? 1.0 : 0.0,
            unlockedDate: totalPhotos >= 1 ? firstPhotoDate : nil
        ))
        
        // MARK: Country Milestones
        
        achievements.append(Achievement(
            type: .countries(5),
            title: "Explorer",
            description: "Visit 5 countries",
            icon: "map.fill",
            isUnlocked: visitedCount >= 5,
            progress: min(Double(visitedCount) / 5.0, 1.0),
            unlockedDate: visitedCount >= 5 ? earliestVisitDate : nil
        ))
        
        achievements.append(Achievement(
            type: .countries(10),
            title: "World Traveler",
            description: "Visit 10 countries",
            icon: "globe",
            isUnlocked: visitedCount >= 10,
            progress: min(Double(visitedCount) / 10.0, 1.0),
            unlockedDate: visitedCount >= 10 ? earliestVisitDate : nil
        ))
        
        // MARK: Continent Achievements
        
        achievements.append(Achievement(
            type: .continents(3),
            title: "Continental",
            description: "Visit countries on 3 continents",
            icon: "airplane",
            isUnlocked: continentCount >= 3,
            progress: min(Double(continentCount) / 3.0, 1.0),
            unlockedDate: continentCount >= 3 ? earliestVisitDate : nil
        ))
        
        achievements.append(Achievement(
            type: .allContinents,
            title: "Globe Trotter",
            description: "Visit all 7 continents",
            icon: "globe.americas.fill",
            isUnlocked: continentCount >= 7,
            progress: Double(continentCount) / 7.0,
            unlockedDate: continentCount >= 7 ? earliestVisitDate : nil
        ))
        
        return achievements
    }
    
    /// Get a summary of achievement progress
    /// - Parameter achievements: Array of achievements
    /// - Returns: Tuple with total and unlocked counts
    static func achievementSummary(_ achievements: [Achievement]) -> (total: Int, unlocked: Int) {
        let total = achievements.count
        let unlocked = achievements.filter { $0.isUnlocked }.count
        return (total: total, unlocked: unlocked)
    }
    
    /// Get recently unlocked achievements (within last 30 days)
    /// - Parameter achievements: Array of achievements
    /// - Returns: Recently unlocked achievements sorted by unlock date (newest first)
    static func recentlyUnlocked(_ achievements: [Achievement]) -> [Achievement] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        return achievements
            .filter { achievement in
                guard let unlockedDate = achievement.unlockedDate else { return false }
                return unlockedDate >= thirtyDaysAgo
            }
            .sorted { ($0.unlockedDate ?? Date.distantPast) > ($1.unlockedDate ?? Date.distantPast) }
    }
    
    /// Get achievements in progress (unlocked but not at 100%)
    /// - Parameter achievements: Array of achievements
    /// - Returns: Achievements that are in progress
    static func inProgress(_ achievements: [Achievement]) -> [Achievement] {
        achievements.filter { achievement in
            !achievement.isUnlocked && (achievement.progress ?? 0) > 0
        }
    }
    
    /// Get locked achievements (not started or no progress)
    /// - Parameter achievements: Array of achievements
    /// - Returns: Achievements that are locked
    static func locked(_ achievements: [Achievement]) -> [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }
}
