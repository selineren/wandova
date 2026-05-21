//
//  ComparisonMapView.swift
//  Wandova
//
//  Created by seren on 13.04.2026.
//

import SwiftUI
import MapKit

/// A map view that displays travel comparison data with color-coded countries
/// - Green: Countries both users have (shared)
/// - Blue: Countries only you have (yours)
/// - Orange: Countries only they have (theirs)
/// - Gray: Countries neither has
struct ComparisonMapView: UIViewRepresentable {
    let comparison: TravelComparisonResult
    @Binding var zoomLevel: MapZoomLevel
    var onCountryTapped: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            comparison: comparison,
            zoomLevel: zoomLevel,
            onCountryTapped: onCountryTapped
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        
        // Ensure proper rendering
        mapView.isOpaque = true
        
        // Enable tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        if #available(iOS 16.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            mapView.preferredConfiguration = config
        }

        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = false

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )
        mapView.setRegion(region, animated: false)

        // Load overlays asynchronously to prevent main thread blocking
        let coordinator = context.coordinator
        DispatchQueue.global(qos: .userInitiated).async { [weak coordinator] in
            let overlaysByCountry = CountryBoundaryService.shared.getCountryOverlays()
            
            // Update map on main thread
            DispatchQueue.main.async { [weak coordinator] in
                guard let coordinator = coordinator else { return }
                coordinator.overlaysByCountry = overlaysByCountry
                // Add ALL overlays initially (needed for tap detection and rendering)
                let allOverlays = overlaysByCountry.values.flatMap { $0 }
                mapView.addOverlays(allOverlays)
                coordinator.allOverlaysLoaded = true
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Cache old comparison to detect changes
        let oldComparison = context.coordinator.comparison
        
        // Update the coordinator's comparison data
        context.coordinator.comparison = comparison
        context.coordinator.onCountryTapped = onCountryTapped
        
        // Handle zoom level changes
        if context.coordinator.currentZoomLevel != zoomLevel {
            context.coordinator.currentZoomLevel = zoomLevel
            
            let currentCenter = mapView.region.center
            let newRegion = MKCoordinateRegion(
                center: currentCenter,
                span: MKCoordinateSpan(
                    latitudeDelta: zoomLevel.latitudeDelta,
                    longitudeDelta: zoomLevel.longitudeDelta
                )
            )
            
            mapView.setRegion(newRegion, animated: true)
        }
        
        // Update renderer colors if comparison data changed
        if context.coordinator.allOverlaysLoaded && oldComparison != comparison {
            // Calculate which countries changed
            let oldAllCountries = oldComparison.allCountryIds
            let newAllCountries = comparison.allCountryIds
            let changedCountries = oldAllCountries.symmetricDifference(newAllCountries)
                .union(comparison.allCountryIds) // Always update all countries involved in new comparison
            
            context.coordinator.updateRendererColors(for: mapView, changedCountries: changedCountries)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var comparison: TravelComparisonResult
        var overlaysByCountry: [String: [MKOverlay]] = [:]
        var onCountryTapped: ((String) -> Void)?
        var currentZoomLevel: MapZoomLevel
        var allOverlaysLoaded = false
        
        // Cache overlay -> countryID lookups for performance
        private var overlayCountryCache: [ObjectIdentifier: String] = [:]
        
        // Cache renderers to avoid recreating them on every map render
        private var rendererCache: [ObjectIdentifier: MKOverlayPathRenderer] = [:]

        init(comparison: TravelComparisonResult, zoomLevel: MapZoomLevel, onCountryTapped: ((String) -> Void)?) {
            self.comparison = comparison
            self.currentZoomLevel = zoomLevel
            self.onCountryTapped = onCountryTapped
        }
        
        // Update renderer colors only for countries that changed
        func updateRendererColors(for mapView: MKMapView, changedCountries: Set<String>) {
            for countryID in changedCountries {
                guard let overlays = overlaysByCountry[countryID] else { continue }
                
                for overlay in overlays {
                    let overlayID = ObjectIdentifier(overlay)
                    if let renderer = rendererCache[overlayID] {
                        configure(renderer: renderer, for: overlay)
                        renderer.setNeedsDisplay()
                    } else if let renderer = mapView.renderer(for: overlay) as? MKOverlayPathRenderer {
                        configure(renderer: renderer, for: overlay)
                        renderer.setNeedsDisplay()
                    }
                }
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let overlayID = ObjectIdentifier(overlay)
            
            // Return cached renderer if available
            if let cached = rendererCache[overlayID] {
                return cached
            }
            
            // Create new renderer
            let renderer: MKOverlayPathRenderer
            if let polygon = overlay as? MKPolygon {
                renderer = MKPolygonRenderer(polygon: polygon)
            } else if let multiPolygon = overlay as? MKMultiPolygon {
                renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
            } else {
                renderer = MKOverlayPathRenderer(overlay: overlay)
            }
            
            configure(renderer: renderer, for: overlay)
            
            // Cache the renderer
            rendererCache[overlayID] = renderer
            
            return renderer
        }

        func configure(renderer: MKOverlayPathRenderer, for overlay: MKOverlay) {
            let countryID = countryID(for: overlay)

            if let countryID {
                if comparison.isShared(countryID) {
                    // Shared: Both users have this country - Green
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.7)
                    renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9)
                    renderer.lineWidth = 1.5
                } else if comparison.isYours(countryID) {
                    // Yours: Only you have this country - Blue
                    renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.6)
                    renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                    renderer.lineWidth = 1.2
                } else if comparison.isTheirs(countryID) {
                    // Theirs: Only they have this country - Orange
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.6)
                    renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
                    renderer.lineWidth = 1.2
                } else {
                    // None: Neither has this country - Light gray
                    renderer.fillColor = UIColor.systemGray5.withAlphaComponent(0.85)
                    renderer.strokeColor = UIColor.systemGray3.withAlphaComponent(0.7)
                    renderer.lineWidth = 0.5
                }
            } else {
                // Unknown country - default gray
                renderer.fillColor = UIColor.systemGray5.withAlphaComponent(0.85)
                renderer.strokeColor = UIColor.systemGray3.withAlphaComponent(0.7)
                renderer.lineWidth = 0.5
            }
        }

        private func countryID(for overlay: MKOverlay) -> String? {
            let overlayID = ObjectIdentifier(overlay)
            
            // Check cache first
            if let cached = overlayCountryCache[overlayID] {
                return cached
            }
            
            // Search through overlaysByCountry
            for (countryID, overlays) in overlaysByCountry {
                for countryOverlay in overlays {
                    if ObjectIdentifier(countryOverlay) == overlayID {
                        overlayCountryCache[overlayID] = countryID
                        return countryID
                    }
                }
            }
            
            return nil
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Find which country was tapped
            for (countryID, overlays) in overlaysByCountry {
                for overlay in overlays {
                    if isCoordinate(coordinate, inside: overlay) {
                        onCountryTapped?(countryID)
                        return
                    }
                }
            }
        }

        private func isCoordinate(_ coordinate: CLLocationCoordinate2D, inside overlay: MKOverlay) -> Bool {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let mapPoint = MKMapPoint(coordinate)
                let polygonPoint = renderer.point(for: mapPoint)
                return renderer.path.contains(polygonPoint)
            } else if let multiPolygon = overlay as? MKMultiPolygon {
                for polygon in multiPolygon.polygons {
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    let mapPoint = MKMapPoint(coordinate)
                    let polygonPoint = renderer.point(for: mapPoint)
                    if renderer.path.contains(polygonPoint) {
                        return true
                    }
                }
            }
            return false
        }
    }
}
