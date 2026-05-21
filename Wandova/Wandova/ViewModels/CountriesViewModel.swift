//
//  CountriesViewModel.swift
//  Wandova
//
//  Created by seren on 26.02.2026.
//

import Foundation
import Combine

@MainActor
final class CountriesViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedContinent: Continent? = nil // nil = "All Continents"
    @Published private(set) var countries: [Country] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    
    private let service = CountryDataService.shared
    
    init() {
        load()
    }
    
    func load() {
        isLoading = true
        loadError = nil
        
        // Load countries
        Task(priority: .userInitiated) {
            let loadedCountries = service.loadCountries()
            
            self.countries = loadedCountries
            self.isLoading = false
            
            if loadedCountries.isEmpty {
                self.loadError = "No countries found in GeoJSON file"
            }
        }
    }
    
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isFiltering: Bool {
        selectedContinent != nil
    }
    
    var filteredCountries: [Country] {
        var result = countries
        
        // Apply continent filter first
        if let continent = selectedContinent {
            result = result.filter { $0.continent == continent }
        }
        
        // Then apply search filter
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let q = trimmed.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) }
        }
        
        return result
    }
    
    var groupedByContinent: [(continent: Continent, countries: [Country])] {
        let grouped = Dictionary(grouping: filteredCountries, by: { $0.continent })
        return Continent.allCases.compactMap { c in
            guard let items = grouped[c], !items.isEmpty else { return nil }
            return (c, items.sorted { $0.name < $1.name })
        }
    }
}
