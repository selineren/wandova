//
//  CountryDataService.swift
//  Wandova
//
//  Created by seren on 15.03.2026.
//

import Foundation
import MapKit

final class CountryDataService {
    static let shared = CountryDataService()
    
    // OPTIMIZATION: Cache loaded countries in memory to avoid repeated disk I/O and parsing
    private var countriesCache: [Country]?
    private let cacheLock = NSLock()
    
    private init() {}
    
    /// Loads all countries from the GeoJSON file (cached after first load)
    func loadCountries() -> [Country] {
        // Check cache first (thread-safe)
        cacheLock.lock()
        if let cached = countriesCache {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        // Load from disk if not cached
        let loaded = loadCountriesFromDisk()
        
        // Store in cache
        cacheLock.lock()
        countriesCache = loaded
        cacheLock.unlock()
        
        return loaded
    }
    
    /// Internal method that actually loads from disk
    private func loadCountriesFromDisk() -> [Country] {
        guard let url = Bundle.main.url(forResource: "world_countries", withExtension: "geojson") else {
            print("⚠️ world_countries.geojson not found in bundle")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = MKGeoJSONDecoder()
            let objects = try decoder.decode(data)
            
            var countries: [Country] = []
            var skippedCount = 0
            var skippedReasons: [String: Int] = [:]
            
            for object in objects {
                guard let feature = object as? MKGeoJSONFeature else {
                    skippedCount += 1
                    skippedReasons["Not a feature"] = (skippedReasons["Not a feature"] ?? 0) + 1
                    continue
                }
                
                guard let properties = feature.properties,
                      let jsonObject = try? JSONSerialization.jsonObject(with: properties),
                      let dict = jsonObject as? [String: Any]
                else {
                    skippedCount += 1
                    skippedReasons["No properties"] = (skippedReasons["No properties"] ?? 0) + 1
                    continue
                }
                
                guard let countryCode = extractCountryCode(from: dict) else {
                    skippedCount += 1
                    skippedReasons["No country code"] = (skippedReasons["No country code"] ?? 0) + 1
                    continue
                }
                
                guard let countryName = extractCountryName(from: dict) else {
                    skippedCount += 1
                    skippedReasons["No country name"] = (skippedReasons["No country name"] ?? 0) + 1
                    continue
                }
                
                let continent = extractContinent(from: dict)
                let centroid = calculateCentroid(from: feature.geometry)
                let flagEmoji = getFlagEmoji(for: countryCode)
                
                let country = Country(
                    id: countryCode,
                    name: countryName,
                    continent: continent,
                    flagEmoji: flagEmoji,
                    centroid: centroid
                )
                
                countries.append(country)
            }
            
            // Check for duplicates and remove them
            var seenCodes = Set<String>()
            var uniqueCountries: [Country] = []
            
            for country in countries {
                if !seenCodes.contains(country.id) {
                    seenCodes.insert(country.id)
                    uniqueCountries.append(country)
                }
            }
            
            return uniqueCountries.sorted { $0.name < $1.name }
            
        } catch {
            print("❌ Failed to load countries from GeoJSON: \(error)")
            return []
        }
    }
    
    // MARK: - Extraction Helpers
    
    private func extractCountryCode(from dict: [String: Any]) -> String? {
        // First, check if this is a special territory that should be skipped or reassigned
        if let name = extractCountryName(from: dict) {
            let normalized = name.lowercased()
            
            // Skip these - they're not countries or are disputed/uninhabited
            let skipList = [
                "bir tawil",
                "patagonian ice",
                "spratly",
                "scarborough reef",
                "brazilian island"
            ]
            
            for skip in skipList {
                if normalized.contains(skip) {
                    return nil // Intentionally skip these
                }
            }
            
            // Assign territories to their administering country
            if normalized.contains("akrotiri") || normalized.contains("dhekelia") {
                return "GB" // UK Sovereign Base Areas
            }
            if normalized.contains("guantanamo") {
                return "US" // US Naval Base
            }
            if normalized.contains("ashmore") || normalized.contains("cartier") ||
               normalized.contains("coral sea") {
                return "AU" // Australian territories
            }
            if normalized.contains("clipperton") {
                return "FR" // French territory
            }
            if normalized.contains("indian ocean territories") {
                return "AU" // Australian Indian Ocean Territories
            }
        }
        
        // Try various property names for country code
        let possibleKeys = [
            "ISO3166-1-Alpha-2",
            "iso_a2",
            "ISO_A2",
            "iso2",
            "ISO2",
            "countryCode",
            "code",
            "iso_code",
            "ISO_CODE",
            "ADM0_A3",
            "ADM0_A3_US",
            "ADM0_A3_GB", 
            "ADM0_A3_UN",
            "ADM0_A3_WB",
            "ISO_A3",
            "iso_a3",
            "ISO3"
        ]
        
        for key in possibleKeys {
            if let code = dict[key] as? String, !code.isEmpty, code != "-99", code != "-1" {
                // Handle 2-letter codes
                if code.count == 2 {
                    return code.uppercased()
                }
                // Handle 3-letter codes - try to convert to 2-letter
                if code.count == 3 {
                    if let twoLetter = convertISO3ToISO2(code) {
                        return twoLetter
                    }
                }
            }
        }
        
        return nil
    }
    
    // Convert ISO 3166-1 alpha-3 to alpha-2 (comprehensive mapping)
    private func convertISO3ToISO2(_ iso3: String) -> String? {
        let mapping: [String: String] = [
            // A
            "AFG": "AF", "ALB": "AL", "DZA": "DZ", "ASM": "AS", "AND": "AD",
            "AGO": "AO", "AIA": "AI", "ATA": "AQ", "ATG": "AG", "ARG": "AR",
            "ARM": "AM", "ABW": "AW", "AUS": "AU", "AUT": "AT", "AZE": "AZ",
            // B
            "BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB", "BLR": "BY",
            "BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BMU": "BM", "BTN": "BT",
            "BOL": "BO", "BIH": "BA", "BWA": "BW", "BVT": "BV", "BRA": "BR",
            "IOT": "IO", "BRN": "BN", "BGR": "BG", "BFA": "BF", "BDI": "BI",
            // C
            "KHM": "KH", "CMR": "CM", "CAN": "CA", "CPV": "CV", "CYM": "KY",
            "CAF": "CF", "TCD": "TD", "CHL": "CL", "CHN": "CN", "CXR": "CX",
            "CCK": "CC", "COL": "CO", "COM": "KM", "COG": "CG", "COD": "CD",
            "COK": "CK", "CRI": "CR", "CIV": "CI", "HRV": "HR", "CUB": "CU",
            "CYP": "CY", "CZE": "CZ",
            // D
            "DNK": "DK", "DJI": "DJ", "DMA": "DM", "DOM": "DO",
            // E
            "ECU": "EC", "EGY": "EG", "SLV": "SV", "GNQ": "GQ", "ERI": "ER",
            "EST": "EE", "ETH": "ET",
            // F
            "FLK": "FK", "FRO": "FO", "FJI": "FJ", "FIN": "FI", "FRA": "FR",
            "GUF": "GF", "PYF": "PF", "ATF": "TF",
            // G
            "GAB": "GA", "GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH",
            "GIB": "GI", "GRC": "GR", "GRL": "GL", "GRD": "GD", "GLP": "GP",
            "GUM": "GU", "GTM": "GT", "GGY": "GG", "GIN": "GN", "GNB": "GW",
            "GUY": "GY",
            // H
            "HTI": "HT", "HMD": "HM", "VAT": "VA", "HND": "HN", "HKG": "HK",
            "HUN": "HU",
            // I
            "ISL": "IS", "IND": "IN", "IDN": "ID", "IRN": "IR", "IRQ": "IQ",
            "IRL": "IE", "IMN": "IM", "ISR": "IL", "ITA": "IT",
            // J
            "JAM": "JM", "JPN": "JP", "JEY": "JE", "JOR": "JO",
            // K
            "KAZ": "KZ", "KEN": "KE", "KIR": "KI", "PRK": "KP", "KOR": "KR",
            "KWT": "KW", "KGZ": "KG",
            // L
            "LAO": "LA", "LVA": "LV", "LBN": "LB", "LSO": "LS", "LBR": "LR",
            "LBY": "LY", "LIE": "LI", "LTU": "LT", "LUX": "LU",
            // M
            "MAC": "MO", "MKD": "MK", "MDG": "MG", "MWI": "MW", "MYS": "MY",
            "MDV": "MV", "MLI": "ML", "MLT": "MT", "MHL": "MH", "MTQ": "MQ",
            "MRT": "MR", "MUS": "MU", "MYT": "YT", "MEX": "MX", "FSM": "FM",
            "MDA": "MD", "MCO": "MC", "MNG": "MN", "MNE": "ME", "MSR": "MS",
            "MAR": "MA", "MOZ": "MZ", "MMR": "MM",
            // N
            "NAM": "NA", "NRU": "NR", "NPL": "NP", "NLD": "NL", "ANT": "AN",
            "NCL": "NC", "NZL": "NZ", "NIC": "NI", "NER": "NE", "NGA": "NG",
            "NIU": "NU", "NFK": "NF", "MNP": "MP", "NOR": "NO",
            // O
            "OMN": "OM",
            // P
            "PAK": "PK", "PLW": "PW", "PSE": "PS", "PAN": "PA", "PNG": "PG",
            "PRY": "PY", "PER": "PE", "PHL": "PH", "PCN": "PN", "POL": "PL",
            "PRT": "PT", "PRI": "PR",
            // Q
            "QAT": "QA",
            // R
            "REU": "RE", "ROU": "RO", "RUS": "RU", "RWA": "RW",
            // S
            "BLM": "BL", "SHN": "SH", "KNA": "KN", "LCA": "LC", "MAF": "MF",
            "SPM": "PM", "VCT": "VC", "WSM": "WS", "SMR": "SM", "STP": "ST",
            "SAU": "SA", "SEN": "SN", "SRB": "RS", "SYC": "SC", "SLE": "SL",
            "SGP": "SG", "SVK": "SK", "SVN": "SI", "SLB": "SB", "SOM": "SO",
            "ZAF": "ZA", "SGS": "GS", "SSD": "SS", "ESP": "ES", "LKA": "LK",
            "SDN": "SD", "SUR": "SR", "SJM": "SJ", "SWZ": "SZ", "SWE": "SE",
            "CHE": "CH", "SYR": "SY",
            // T
            "TWN": "TW", "TJK": "TJ", "TZA": "TZ", "THA": "TH", "TLS": "TL",
            "TGO": "TG", "TKL": "TK", "TON": "TO", "TTO": "TT", "TUN": "TN",
            "TUR": "TR", "TKM": "TM", "TCA": "TC", "TUV": "TV",
            // U
            "UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB", "USA": "US",
            "UMI": "UM", "URY": "UY", "UZB": "UZ",
            // V
            "VUT": "VU", "VEN": "VE", "VNM": "VN", "VGB": "VG", "VIR": "VI",
            // W
            "WLF": "WF",
            // Y
            "YEM": "YE",
            // Z
            "ZMB": "ZM", "ZWE": "ZW",
            
            // Special territories
            "XKX": "XK"  // Kosovo
        ]
        return mapping[iso3.uppercased()]
    }
    
    private func extractCountryName(from dict: [String: Any]) -> String? {
        // Try various property names for country name
        let possibleKeys = [
            "ADMIN",           // Natural Earth
            "name",
            "NAME",
            "name_long",
            "NAME_LONG",
            "sovereignt",
            "SOVEREIGNT",
            "formal_en",
            "FORMAL_EN"
        ]
        
        for key in possibleKeys {
            if let name = dict[key] as? String, !name.isEmpty {
                return name
            }
        }
        
        return nil
    }
    
    private func extractContinent(from dict: [String: Any]) -> Continent {
        // Try various property names for continent
        let possibleKeys = [
            "CONTINENT",
            "continent",
            "REGION_UN",
            "region_un",
            "SUBREGION"
        ]
        
        for key in possibleKeys {
            if let continentString = dict[key] as? String {
                if let continent = mapToContinent(continentString) {
                    return continent
                }
            }
        }
        
        // Fallback: try to infer from country code
        if let code = extractCountryCode(from: dict) {
            return inferContinentFromCountryCode(code)
        }
        
        return .asia // Default fallback
    }
    
    private func mapToContinent(_ string: String) -> Continent? {
        let normalized = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch normalized {
        case "africa":
            return .africa
        case "antarctica":
            return .antarctica
        case "asia":
            return .asia
        case "europe":
            return .europe
        case "north america", "northern america", "central america", "caribbean":
            return .northAmerica
        case "oceania", "australia", "pacific":
            return .oceania
        case "south america":
            return .southAmerica
        default:
            return nil
        }
    }
    
    private func inferContinentFromCountryCode(_ code: String) -> Continent {
        // Comprehensive mapping of country codes to continents
        // This is a fallback when GeoJSON doesn't have continent info
        
        let europeanCodes = ["AL", "AD", "AT", "BY", "BE", "BA", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IS", "IE", "IT", "XK", "LV", "LI", "LT", "LU", "MT", "MD", "MC", "ME", "NL", "MK", "NO", "PL", "PT", "RO", "RU", "SM", "RS", "SK", "SI", "ES", "SE", "CH", "UA", "GB", "VA"]
        
        let asianCodes = ["AF", "AM", "AZ", "BH", "BD", "BT", "BN", "KH", "CN", "GE", "IN", "ID", "IR", "IQ", "IL", "JP", "JO", "KZ", "KW", "KG", "LA", "LB", "MY", "MV", "MN", "MM", "NP", "KP", "OM", "PK", "PS", "PH", "QA", "SA", "SG", "KR", "LK", "SY", "TJ", "TH", "TL", "TR", "TM", "AE", "UZ", "VN", "YE"]
        
        let africanCodes = ["DZ", "AO", "BJ", "BW", "BF", "BI", "CM", "CV", "CF", "TD", "KM", "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "ET", "GA", "GM", "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML", "MR", "MU", "MA", "MZ", "NA", "NE", "NG", "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "SZ", "TZ", "TG", "TN", "UG", "ZM", "ZW"]
        
        let northAmericanCodes = ["AG", "BS", "BB", "BZ", "CA", "CR", "CU", "DM", "DO", "SV", "GD", "GT", "HT", "HN", "JM", "MX", "NI", "PA", "KN", "LC", "VC", "TT", "US"]
        
        let southAmericanCodes = ["AR", "BO", "BR", "CL", "CO", "EC", "GY", "PY", "PE", "SR", "UY", "VE"]
        
        let oceanianCodes = ["AU", "FJ", "KI", "MH", "FM", "NR", "NZ", "PW", "PG", "WS", "SB", "TO", "TV", "VU"]
        
        let antarcticaCodes = ["AQ"]
        
        if europeanCodes.contains(code) {
            return .europe
        } else if asianCodes.contains(code) {
            return .asia
        } else if africanCodes.contains(code) {
            return .africa
        } else if northAmericanCodes.contains(code) {
            return .northAmerica
        } else if southAmericanCodes.contains(code) {
            return .southAmerica
        } else if oceanianCodes.contains(code) {
            return .oceania
        } else if antarcticaCodes.contains(code) {
            return .antarctica
        }
        
        return .asia // Default fallback
    }
    
    private func calculateCentroid(from geometries: [MKGeoJSONObject]) -> Coordinate {
        // Find the largest polygon to use for centroid calculation
        // This avoids offshore territories skewing the result
        var largestPolygon: MKPolygon?
        var largestArea = 0.0
        
        for geometry in geometries {
            if let polygon = geometry as? MKPolygon {
                let area = polygon.boundingMapRect.width * polygon.boundingMapRect.height
                if area > largestArea {
                    largestArea = area
                    largestPolygon = polygon
                }
            } else if let multiPolygon = geometry as? MKMultiPolygon {
                for polygon in multiPolygon.polygons {
                    let area = polygon.boundingMapRect.width * polygon.boundingMapRect.height
                    if area > largestArea {
                        largestArea = area
                        largestPolygon = polygon
                    }
                }
            }
        }
        
        // Use the center of the bounding box of the largest polygon
        // This gives a more visually accurate centroid than averaging all points
        if let polygon = largestPolygon {
            let boundingBox = polygon.boundingMapRect
            let centerPoint = MKMapPoint(x: boundingBox.midX, y: boundingBox.midY)
            let centerCoordinate = centerPoint.coordinate
            
            return Coordinate(
                latitude: centerCoordinate.latitude,
                longitude: centerCoordinate.longitude
            )
        }
        
        // Fallback to averaging all points if no polygon found
        var totalLat = 0.0
        var totalLon = 0.0
        var pointCount = 0
        
        for geometry in geometries {
            if let polygon = geometry as? MKPolygon {
                let coords = extractCoordinates(from: polygon)
                for coord in coords {
                    totalLat += coord.latitude
                    totalLon += coord.longitude
                    pointCount += 1
                }
            } else if let multiPolygon = geometry as? MKMultiPolygon {
                for polygon in multiPolygon.polygons {
                    let coords = extractCoordinates(from: polygon)
                    for coord in coords {
                        totalLat += coord.latitude
                        totalLon += coord.longitude
                        pointCount += 1
                    }
                }
            }
        }
        
        if pointCount > 0 {
            return Coordinate(
                latitude: totalLat / Double(pointCount),
                longitude: totalLon / Double(pointCount)
            )
        }
        
        // Final fallback
        return Coordinate(latitude: 0, longitude: 0)
    }
    
    private func extractCoordinates(from polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
        return coords
    }
    
    private func getFlagEmoji(for countryCode: String) -> String {
        // Convert ISO 3166-1 alpha-2 country code to flag emoji
        // Each letter is converted to its regional indicator symbol
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let regionalIndicator = UnicodeScalar(base + scalar.value) {
                emoji.append(String(regionalIndicator))
            }
        }
        return emoji.isEmpty ? "🏳️" : emoji
    }
}
