//
//  TravelComparisonEngine.swift
//  Wandova
//
//  Created by seren on 13.04.2026.
//

import Foundation

/// Pure comparison engine for analyzing travel data between two users
/// No dependencies on Firestore, networking, or UI - only operates on Visit models
struct TravelComparisonEngine {
    
    // MARK: - Public API
    
    /// Compare two users' travel data for a specific mode (visited or wishlist)
    ///
    /// - Parameters:
    ///   - yourVisits: Your visit records (typically from AppState.visits)
    ///   - theirVisits: The other user's visit records
    ///   - mode: Whether to compare visited countries or wishlist countries
    /// - Returns: Comparison result with yours/shared/theirs country sets
    static func compare(
        yourVisits: [String: Visit],
        theirVisits: [String: Visit],
        mode: ComparisonMode
    ) -> TravelComparisonResult {
        // Extract relevant country IDs based on mode
        let yourCountries = extractCountryIds(from: yourVisits, mode: mode)
        let theirCountries = extractCountryIds(from: theirVisits, mode: mode)
        
        // Compute set operations
        let shared = yourCountries.intersection(theirCountries)
        let yours = yourCountries.subtracting(shared)
        let theirs = theirCountries.subtracting(shared)
        
        return TravelComparisonResult(
            yours: yours,
            shared: shared,
            theirs: theirs,
            mode: mode
        )
    }
    
    /// Perform a comprehensive comparison including both visited and wishlist data
    ///
    /// - Parameters:
    ///   - yourVisits: Your visit records
    ///   - theirVisits: The other user's visit records
    /// - Returns: Detailed comparison with both visited and wishlist results
    static func detailedCompare(
        yourVisits: [String: Visit],
        theirVisits: [String: Visit]
    ) -> DetailedTravelComparison {
        let visitedComparison = compare(
            yourVisits: yourVisits,
            theirVisits: theirVisits,
            mode: .visited
        )
        
        let wishlistComparison = compare(
            yourVisits: yourVisits,
            theirVisits: theirVisits,
            mode: .wishlist
        )
        
        return DetailedTravelComparison(
            visitedComparison: visitedComparison,
            wishlistComparison: wishlistComparison
        )
    }
    
    /// Compare using array of visits (convenience method)
    ///
    /// - Parameters:
    ///   - yourVisits: Array of your visits
    ///   - theirVisits: Array of their visits
    ///   - mode: Comparison mode
    /// - Returns: Comparison result
    static func compare(
        yourVisits: [Visit],
        theirVisits: [Visit],
        mode: ComparisonMode
    ) -> TravelComparisonResult {
        let yourDict = Dictionary(uniqueKeysWithValues: yourVisits.map { ($0.countryId, $0) })
        let theirDict = Dictionary(uniqueKeysWithValues: theirVisits.map { ($0.countryId, $0) })
        
        return compare(
            yourVisits: yourDict,
            theirVisits: theirDict,
            mode: mode
        )
    }
    
    /// Detailed comparison using array of visits (convenience method)
    ///
    /// - Parameters:
    ///   - yourVisits: Array of your visits
    ///   - theirVisits: Array of their visits
    /// - Returns: Detailed comparison
    static func detailedCompare(
        yourVisits: [Visit],
        theirVisits: [Visit]
    ) -> DetailedTravelComparison {
        let yourDict = Dictionary(uniqueKeysWithValues: yourVisits.map { ($0.countryId, $0) })
        let theirDict = Dictionary(uniqueKeysWithValues: theirVisits.map { ($0.countryId, $0) })
        
        return detailedCompare(
            yourVisits: yourDict,
            theirVisits: theirDict
        )
    }
    
    // MARK: - Private Helpers
    
    /// Extract country IDs from visit data based on comparison mode
    private static func extractCountryIds(
        from visits: [String: Visit],
        mode: ComparisonMode
    ) -> Set<String> {
        switch mode {
        case .visited:
            // Only countries where isVisited = true
            return Set(visits.values.filter { $0.isVisited }.map { $0.countryId })
            
        case .wishlist:
            // Only countries where wantToVisit = true
            return Set(visits.values.filter { $0.wantToVisit }.map { $0.countryId })
        }
    }
}

// MARK: - Convenience Extensions

extension TravelComparisonResult {
    /// Check if a specific country belongs to you only
    func isYours(_ countryId: String) -> Bool {
        yours.contains(countryId)
    }
    
    /// Check if a specific country is shared
    func isShared(_ countryId: String) -> Bool {
        shared.contains(countryId)
    }
    
    /// Check if a specific country belongs to them only
    func isTheirs(_ countryId: String) -> Bool {
        theirs.contains(countryId)
    }
    
    /// Get the ownership category for a country
    func ownership(of countryId: String) -> ComparisonOwnership? {
        if isYours(countryId) { return .yours }
        if isShared(countryId) { return .shared }
        if isTheirs(countryId) { return .theirs }
        return nil
    }
}

/// Represents who "owns" a country in a comparison
enum ComparisonOwnership {
    case yours
    case shared
    case theirs
}
