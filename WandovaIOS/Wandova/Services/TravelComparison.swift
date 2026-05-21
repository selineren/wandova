//
//  TravelComparison.swift
//  Wandova
//
//  Created by seren on 13.04.2026.
//

import Foundation

// MARK: - Comparison Mode

/// Defines which aspect of travel data to compare
enum ComparisonMode: Equatable {
    case visited      // Compare countries marked as visited
    case wishlist     // Compare countries marked as want-to-visit
}

// MARK: - Comparison Result

/// Represents the result of comparing two users' travel data
struct TravelComparisonResult: Equatable {
    /// Countries that only you have (visited or wishlisted)
    let yours: Set<String>
    
    /// Countries that both users share (both visited or both wishlisted)
    let shared: Set<String>
    
    /// Countries that only the other user has (visited or wishlisted)
    let theirs: Set<String>
    
    /// The mode used for this comparison (visited or wishlist)
    let mode: ComparisonMode
    
    // MARK: - Computed Properties
    
    /// Total unique countries across both users
    var totalUnique: Int {
        yours.count + shared.count + theirs.count
    }
    
    /// Percentage of overlap between the two users
    /// Returns 0-100, or 0 if no countries exist
    var overlapPercentage: Double {
        guard totalUnique > 0 else { return 0 }
        return Double(shared.count) / Double(totalUnique) * 100
    }
    
    /// All country IDs involved in this comparison
    var allCountryIds: Set<String> {
        yours.union(shared).union(theirs)
    }
    
    /// True if both users have no data for this comparison mode
    var isEmpty: Bool {
        totalUnique == 0
    }
}

// MARK: - Detailed Comparison Result

/// A comprehensive comparison containing both visited and wishlist comparisons
struct DetailedTravelComparison {
    /// Comparison of visited countries
    let visitedComparison: TravelComparisonResult
    
    /// Comparison of wishlist countries
    let wishlistComparison: TravelComparisonResult
    
    // MARK: - Computed Properties
    
    /// Total unique countries either user has interacted with (visited or wishlisted)
    var totalUniqueCountries: Int {
        let allIds = visitedComparison.allCountryIds.union(wishlistComparison.allCountryIds)
        return allIds.count
    }
    
    /// True if both users have no travel data at all
    var isEmpty: Bool {
        visitedComparison.isEmpty && wishlistComparison.isEmpty
    }
    
    /// Countries that appear in both users' data but with different states
    /// Example: You visited, they wishlisted (or vice versa)
    var conflictingCountries: ConflictingCountries {
        ConflictingCountries(
            visitedComparison: visitedComparison,
            wishlistComparison: wishlistComparison
        )
    }
}

// MARK: - Conflicting Countries Analysis

/// Identifies countries where users have different travel states
struct ConflictingCountries {
    /// You visited, they wishlisted
    let youVisitedTheyWishlisted: Set<String>
    
    /// They visited, you wishlisted
    let theyVisitedYouWishlisted: Set<String>
    
    init(visitedComparison: TravelComparisonResult, wishlistComparison: TravelComparisonResult) {
        // Your visited ∩ Their wishlist (you've been, they want to go)
        let yourVisited = visitedComparison.yours.union(visitedComparison.shared)
        let theirWishlist = wishlistComparison.theirs.union(wishlistComparison.shared)
        self.youVisitedTheyWishlisted = yourVisited.intersection(theirWishlist)
        
        // Their visited ∩ Your wishlist (they've been, you want to go)
        let theirVisited = visitedComparison.theirs.union(visitedComparison.shared)
        let yourWishlist = wishlistComparison.yours.union(wishlistComparison.shared)
        self.theyVisitedYouWishlisted = theirVisited.intersection(yourWishlist)
    }
    
    /// True if there are any conflicting states
    var hasConflicts: Bool {
        !youVisitedTheyWishlisted.isEmpty || !theyVisitedYouWishlisted.isEmpty
    }
}
