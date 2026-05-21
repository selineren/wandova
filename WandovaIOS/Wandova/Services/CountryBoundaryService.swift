//
//  CountryBoundaryService.swift
//  Wandova
//
//  Created by seren on 15.03.2026.
//

import Foundation
import MapKit

final class CountryBoundaryService {
    static let shared = CountryBoundaryService()

    private var cachedOverlays: [String: [MKOverlay]]?
    private let cacheLock = NSLock()
    
    private init() {}
    
    /// Thread-safe access to overlays with lazy loading
    func getCountryOverlays() -> [String: [MKOverlay]] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let cached = cachedOverlays {
            return cached
        }
        
        // Load and cache
        let overlays = performLoad()
        cachedOverlays = overlays
        return overlays
    }
    
    private func performLoad() -> [String: [MKOverlay]] {
        guard let url = Bundle.main.url(forResource: "world_countries", withExtension: "geojson") else {
            print("⚠️ world_countries.geojson not found in bundle")
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = MKGeoJSONDecoder()
            let objects = try decoder.decode(data)

            var result: [String: [MKOverlay]] = [:]

            for object in objects {
                guard let feature = object as? MKGeoJSONFeature else { continue }
                guard let countryCode = extractCountryCode(from: feature) else { continue }

                let overlays = feature.geometry.compactMap { geometry -> MKOverlay? in
                    if let polygon = geometry as? MKPolygon {
                        return polygon
                    } else if let multiPolygon = geometry as? MKMultiPolygon {
                        return multiPolygon
                    } else {
                        return nil
                    }
                }

                guard !overlays.isEmpty else { continue }
                result[countryCode, default: []].append(contentsOf: overlays)
            }
            
            return result
        } catch {
            print("❌ Failed to decode GeoJSON:", error)
            return [:]
        }
    }

    private func extractCountryCode(from feature: MKGeoJSONFeature) -> String? {
        guard let properties = feature.properties,
              let object = try? JSONSerialization.jsonObject(with: properties),
              let dictionary = object as? [String: Any]
        else {
            return nil
        }

        // Try 2-letter codes first
        let twoLetterKeys = [
            "ISO3166-1-Alpha-2",
            "iso_a2",
            "ISO_A2",
            "iso2",
            "ISO2"
        ]
        
        for key in twoLetterKeys {
            if let code = dictionary[key] as? String, code.count == 2, !code.isEmpty, code != "-99", code != "-1" {
                return code.uppercased()
            }
        }
        
        // Try 3-letter codes and convert to 2-letter
        let threeLetterKeys = [
            "ADM0_A3",
            "ADM0_A3_US",
            "ADM0_A3_GB",
            "ADM0_A3_UN",
            "ISO_A3",
            "iso_a3"
        ]
        
        for key in threeLetterKeys {
            if let code = dictionary[key] as? String, code.count == 3, !code.isEmpty, code != "-99", code != "-1" {
                if let twoLetter = convertISO3ToISO2(code) {
                    return twoLetter
                }
            }
        }

        return nil
    }
    
    // Convert ISO 3166-1 alpha-3 to alpha-2
    private func convertISO3ToISO2(_ iso3: String) -> String? {
        let mapping: [String: String] = [
            // A
            "AFG": "AF", "ALB": "AL", "DZA": "DZ", "AND": "AD", "AGO": "AO",
            "ATG": "AG", "ARG": "AR", "ARM": "AM", "AUS": "AU", "AUT": "AT",
            "AZE": "AZ",
            // B
            "BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB", "BLR": "BY",
            "BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BTN": "BT", "BOL": "BO",
            "BIH": "BA", "BWA": "BW", "BRA": "BR", "BRN": "BN", "BGR": "BG",
            "BFA": "BF", "BDI": "BI",
            // C
            "KHM": "KH", "CMR": "CM", "CAN": "CA", "CPV": "CV", "CAF": "CF",
            "TCD": "TD", "CHL": "CL", "CHN": "CN", "COL": "CO", "COM": "KM",
            "COG": "CG", "COD": "CD", "CRI": "CR", "CIV": "CI", "HRV": "HR",
            "CUB": "CU", "CYP": "CY", "CZE": "CZ",
            // D
            "DNK": "DK", "DJI": "DJ", "DMA": "DM", "DOM": "DO",
            // E
            "ECU": "EC", "EGY": "EG", "SLV": "SV", "GNQ": "GQ", "ERI": "ER",
            "EST": "EE", "ETH": "ET",
            // F
            "FJI": "FJ", "FIN": "FI", "FRA": "FR",
            // G
            "GAB": "GA", "GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH",
            "GRC": "GR", "GRD": "GD", "GTM": "GT", "GIN": "GN", "GNB": "GW",
            "GUY": "GY",
            // H
            "HTI": "HT", "HND": "HN", "HUN": "HU",
            // I
            "ISL": "IS", "IND": "IN", "IDN": "ID", "IRN": "IR", "IRQ": "IQ",
            "IRL": "IE", "ISR": "IL", "ITA": "IT",
            // J
            "JAM": "JM", "JPN": "JP", "JOR": "JO",
            // K
            "KAZ": "KZ", "KEN": "KE", "KIR": "KI", "PRK": "KP", "KOR": "KR",
            "KWT": "KW", "KGZ": "KG",
            // L
            "LAO": "LA", "LVA": "LV", "LBN": "LB", "LSO": "LS", "LBR": "LR",
            "LBY": "LY", "LIE": "LI", "LTU": "LT", "LUX": "LU",
            // M
            "MKD": "MK", "MDG": "MG", "MWI": "MW", "MYS": "MY", "MDV": "MV",
            "MLI": "ML", "MLT": "MT", "MHL": "MH", "MRT": "MR", "MUS": "MU",
            "MEX": "MX", "FSM": "FM", "MDA": "MD", "MCO": "MC", "MNG": "MN",
            "MNE": "ME", "MAR": "MA", "MOZ": "MZ", "MMR": "MM",
            // N
            "NAM": "NA", "NRU": "NR", "NPL": "NP", "NLD": "NL", "NZL": "NZ",
            "NIC": "NI", "NER": "NE", "NGA": "NG", "NOR": "NO",
            // O
            "OMN": "OM",
            // P
            "PAK": "PK", "PLW": "PW", "PAN": "PA", "PNG": "PG", "PRY": "PY",
            "PER": "PE", "PHL": "PH", "POL": "PL", "PRT": "PT", "PSE": "PS",
            // Q
            "QAT": "QA",
            // R
            "ROU": "RO", "RUS": "RU", "RWA": "RW",
            // S
            "KNA": "KN", "LCA": "LC", "VCT": "VC", "WSM": "WS", "SMR": "SM",
            "STP": "ST", "SAU": "SA", "SEN": "SN", "SRB": "RS", "SYC": "SC",
            "SLE": "SL", "SGP": "SG", "SVK": "SK", "SVN": "SI", "SLB": "SB",
            "SOM": "SO", "ZAF": "ZA", "SSD": "SS", "ESP": "ES", "LKA": "LK",
            "SDN": "SD", "SUR": "SR", "SWE": "SE", "CHE": "CH", "SYR": "SY",
            "SWZ": "SZ",
            // T
            "TWN": "TW", "TJK": "TJ", "TZA": "TZ", "THA": "TH", "TLS": "TL",
            "TGO": "TG", "TON": "TO", "TTO": "TT", "TUN": "TN", "TUR": "TR",
            "TKM": "TM", "TUV": "TV",
            // U
            "UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB", "USA": "US",
            "URY": "UY", "UZB": "UZ",
            // V
            "VUT": "VU", "VEN": "VE", "VNM": "VN",
            // Y
            "YEM": "YE",
            // Z
            "ZMB": "ZM", "ZWE": "ZW",
            // Special
            "XKX": "XK"
        ]
        return mapping[iso3.uppercased()]
    }
}
