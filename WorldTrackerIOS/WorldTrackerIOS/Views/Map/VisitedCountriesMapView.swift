//
//  VisitedCountriesMapView.swift
//  WorldTrackerIOS
//
//  Created by seren on 15.03.2026.
//

import SwiftUI
import MapKit

// MARK: - Helper Extensions

extension MKCoordinateRegion {
    func intersects(_ mapRect: MKMapRect) -> Bool {
        let regionRect = MKCoordinateRegion.mapRect(for: self)
        return regionRect.intersects(mapRect)
    }
    
    static func mapRect(for region: MKCoordinateRegion) -> MKMapRect {
        let topLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude + (region.span.latitudeDelta / 2),
            longitude: region.center.longitude - (region.span.longitudeDelta / 2)
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: region.center.latitude - (region.span.latitudeDelta / 2),
            longitude: region.center.longitude + (region.span.longitudeDelta / 2)
        )
        
        let topLeftPoint = MKMapPoint(topLeft)
        let bottomRightPoint = MKMapPoint(bottomRight)
        
        return MKMapRect(
            x: min(topLeftPoint.x, bottomRightPoint.x),
            y: min(topLeftPoint.y, bottomRightPoint.y),
            width: abs(topLeftPoint.x - bottomRightPoint.x),
            height: abs(topLeftPoint.y - bottomRightPoint.y)
        )
    }
}

struct VisitedCountriesMapView: UIViewRepresentable {
    let visitedCountryIDs: Set<String>
    let wantToVisitCountryIDs: Set<String>
    @Binding var zoomLevel: MapZoomLevel
    var onCountryTapped: ((String) -> Void)?
    var bitmojiAnnotations: [CountryBitmojiAnnotation] = []
    var onBitmojiTapped: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            visitedCountryIDs: visitedCountryIDs,
            wantToVisitCountryIDs: wantToVisitCountryIDs,
            zoomLevel: zoomLevel,
            onCountryTapped: onCountryTapped,
            onBitmojiTapped: onBitmojiTapped
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        
        // Register annotation view class
        mapView.register(
            CountryBitmojiAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: CountryBitmojiAnnotationView.identifier
        )
        
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
                // Add ALL overlays initially (needed for tap detection)
                let allOverlays = overlaysByCountry.values.flatMap { $0 }
                mapView.addOverlays(allOverlays)
                coordinator.allOverlaysLoaded = true
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Cache old values to detect actual changes
        let oldVisitedIDs = context.coordinator.visitedCountryIDs
        let oldWantToVisitIDs = context.coordinator.wantToVisitCountryIDs
        
        // Update the coordinator's sets
        context.coordinator.visitedCountryIDs = visitedCountryIDs
        context.coordinator.wantToVisitCountryIDs = wantToVisitCountryIDs
        
        // Update the callbacks
        context.coordinator.onCountryTapped = onCountryTapped
        context.coordinator.onBitmojiTapped = onBitmojiTapped
        
        // Handle zoom level changes
        if context.coordinator.currentZoomLevel != zoomLevel {
            context.coordinator.currentZoomLevel = zoomLevel
            
            // Get current center
            let currentCenter = mapView.region.center
            
            // Create new region with updated zoom
            let newRegion = MKCoordinateRegion(
                center: currentCenter,
                span: MKCoordinateSpan(
                    latitudeDelta: zoomLevel.latitudeDelta,
                    longitudeDelta: zoomLevel.longitudeDelta
                )
            )
            
            // Animate to new zoom level
            mapView.setRegion(newRegion, animated: true)
        }
        
        // Update annotations
        updateAnnotations(in: mapView, coordinator: context.coordinator)
        
        // OPTIMIZATION: Only update renderer colors if visited or wantToVisit countries changed
        // Don't add/remove overlays - they're all on the map already
        if oldVisitedIDs != visitedCountryIDs || oldWantToVisitIDs != wantToVisitCountryIDs {
            if context.coordinator.allOverlaysLoaded {
                // Calculate the difference - only update changed countries
                let visitedAdded = visitedCountryIDs.subtracting(oldVisitedIDs)
                let visitedRemoved = oldVisitedIDs.subtracting(visitedCountryIDs)
                let wantToVisitAdded = wantToVisitCountryIDs.subtracting(oldWantToVisitIDs)
                let wantToVisitRemoved = oldWantToVisitIDs.subtracting(wantToVisitCountryIDs)
                
                let changedCountries = visitedAdded
                    .union(visitedRemoved)
                    .union(wantToVisitAdded)
                    .union(wantToVisitRemoved)
            
                context.coordinator.updateRendererColors(for: mapView, changedCountries: changedCountries)
            }
        }
    }
    
    private func updateAnnotations(in mapView: MKMapView, coordinator: Coordinator) {
        let currentAnnotations = mapView.annotations.compactMap { $0 as? CountryBitmojiAnnotation }
        
        // Create lookup dictionaries for efficient comparison
        let currentByID = Dictionary(uniqueKeysWithValues: currentAnnotations.map { ($0.countryID, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: bitmojiAnnotations.map { ($0.countryID, $0) })
        
        let currentIDs = Set(currentByID.keys)
        let newIDs = Set(newByID.keys)
        
        // Only remove annotations that are no longer needed
        let toRemove = currentAnnotations.filter { !newIDs.contains($0.countryID) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }
        
        // Only add annotations that are new
        let toAdd = bitmojiAnnotations.filter { !currentIDs.contains($0.countryID) }
        if !toAdd.isEmpty {
            mapView.addAnnotations(toAdd)
        }
        
        // Update existing annotations if their visit data changed (photos/notes)
        // This is critical when photos are added/removed but the country set stays the same
        for countryID in currentIDs.intersection(newIDs) {
            guard let currentAnnotation = currentByID[countryID],
                  let newAnnotation = newByID[countryID] else { continue }
            
            // Check if the visit data actually changed
            let visitChanged = currentAnnotation.visit != newAnnotation.visit
            
            if visitChanged {
                // Find the existing annotation view using the OLD annotation that's on the map
                if let annotationView = mapView.view(for: currentAnnotation) as? CountryBitmojiAnnotationView {
                    // Reconfigure with the NEW visit data
                    annotationView.configure(with: newAnnotation)
                }
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var visitedCountryIDs: Set<String>
        var wantToVisitCountryIDs: Set<String>
        var overlaysByCountry: [String: [MKOverlay]] = [:]
        var onCountryTapped: ((String) -> Void)?
        var onBitmojiTapped: ((String) -> Void)?
        var currentZoomLevel: MapZoomLevel
        var allOverlaysLoaded = false
        
        // Cache overlay -> countryID lookups for performance
        private var overlayCountryCache: [ObjectIdentifier: String] = [:]
        
        // Cache renderers to avoid recreating them on every map render
        private var rendererCache: [ObjectIdentifier: MKOverlayPathRenderer] = [:]

        init(visitedCountryIDs: Set<String>, wantToVisitCountryIDs: Set<String>, zoomLevel: MapZoomLevel, onCountryTapped: ((String) -> Void)?, onBitmojiTapped: ((String) -> Void)?) {
            self.visitedCountryIDs = visitedCountryIDs
            self.wantToVisitCountryIDs = wantToVisitCountryIDs
            self.currentZoomLevel = zoomLevel
            self.onCountryTapped = onCountryTapped
            self.onBitmojiTapped = onBitmojiTapped
        }
        
        // OPTIMIZATION: Update renderer colors only for countries that changed
        func updateRendererColors(for mapView: MKMapView, changedCountries: Set<String>) {
            // Only iterate through overlays for countries that actually changed
            for countryID in changedCountries {
                guard let overlays = overlaysByCountry[countryID] else { continue }
                
                for overlay in overlays {
                    let overlayID = ObjectIdentifier(overlay)
                    // Use cached renderer if available, otherwise get from mapView
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
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Check if we tapped on an annotation first
            // If so, don't process country tap
            for annotation in mapView.annotations {
                if mapView.view(for: annotation) != nil {
                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let distance = hypot(point.x - annotationPoint.x, point.y - annotationPoint.y)
                    
                    // If tap is within 32pt of annotation (matching the new smaller size), ignore country tap
                    if distance < 32 {
                        return
                    }
                }
            }
            
            // Ensure overlays are loaded before processing tap
            if overlaysByCountry.isEmpty {
                overlaysByCountry = CountryBoundaryService.shared.getCountryOverlays()
                let allOverlays = overlaysByCountry.values.flatMap { $0 }
                mapView.addOverlays(allOverlays)
                allOverlaysLoaded = true
            }
            
            // OPTIMIZATION: Spatial filtering - only check countries near tap
            let tapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
            
            // Check all countries with spatial filtering
            for (countryID, overlays) in overlaysByCountry {
                for overlay in overlays {
                    // Quick bounds check before expensive polygon test
                    if tapRegion.intersects(overlay.boundingMapRect) {
                        if overlayContains(overlay, coordinate: coordinate) {
                            onCountryTapped?(countryID)
                            return
                        }
                    }
                }
            }
        }
        
        private func overlayContains(_ overlay: MKOverlay, coordinate: CLLocationCoordinate2D) -> Bool {
            if let polygon = overlay as? MKPolygon {
                return polygonContains(polygon, coordinate: coordinate)
            }
            
            if let multiPolygon = overlay as? MKMultiPolygon {
                for polygon in multiPolygon.polygons {
                    if polygonContains(polygon, coordinate: coordinate) {
                        return true
                    }
                }
            }
            
            return false
        }
        
        private func polygonContains(_ polygon: MKPolygon, coordinate: CLLocationCoordinate2D) -> Bool {
            let renderer = MKPolygonRenderer(polygon: polygon)
            let mapPoint = MKMapPoint(coordinate)
            let polygonPoint = renderer.point(for: mapPoint)
            return renderer.path.contains(polygonPoint)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let overlayID = ObjectIdentifier(overlay)
            
            // Check cache first
            if let cachedRenderer = rendererCache[overlayID] {
                return cachedRenderer
            }
            
            // Create new renderer
            let renderer: MKOverlayPathRenderer
            if let polygon = overlay as? MKPolygon {
                renderer = MKPolygonRenderer(polygon: polygon)
            } else if let multiPolygon = overlay as? MKMultiPolygon {
                renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
            } else {
                return MKOverlayRenderer(overlay: overlay)
            }
            
            // Configure and cache
            configure(renderer: renderer, for: overlay)
            rendererCache[overlayID] = renderer
            return renderer
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let bitmojiAnnotation = annotation as? CountryBitmojiAnnotation else {
                return nil
            }
            
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CountryBitmojiAnnotationView.identifier,
                for: annotation
            ) as? CountryBitmojiAnnotationView ?? CountryBitmojiAnnotationView(
                annotation: annotation,
                reuseIdentifier: CountryBitmojiAnnotationView.identifier
            )
            
            view.configure(with: bitmojiAnnotation)
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Handle bitmoji tap
            if let annotation = view.annotation as? CountryBitmojiAnnotation {
                onBitmojiTapped?(annotation.countryID)
                mapView.deselectAnnotation(annotation, animated: false)
            }
        }

        func configure(renderer: MKOverlayPathRenderer, for overlay: MKOverlay) {
            let countryID = countryID(for: overlay)

            if let countryID, visitedCountryIDs.contains(countryID) {
                renderer.fillColor = UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 0.75)
                renderer.strokeColor = UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 0.95)
                renderer.lineWidth = 1.5
            } else if let countryID, wantToVisitCountryIDs.contains(countryID) {
                renderer.fillColor = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.65)
                renderer.strokeColor = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.9)
                renderer.lineWidth = 1.2
            } else {
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
            
            // Find and cache
            for (countryID, overlays) in overlaysByCountry {
                if overlays.contains(where: { $0 === overlay }) {
                    overlayCountryCache[overlayID] = countryID
                    return countryID
                }
            }
            return nil
        }
    }
}
