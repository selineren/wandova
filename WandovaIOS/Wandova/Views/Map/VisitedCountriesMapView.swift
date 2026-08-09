//
//  VisitedCountriesMapView.swift
//  Wandova
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

// MARK: - Camera Tracking

/// Camera state the view needs to remember but must not re-render for.
/// A plain class held in @State: mutating its properties does not
/// invalidate the view, so camera settles no longer re-evaluate `body`
/// (and therefore no longer re-diff the polygon content).
private final class CameraTracker {
    var center = CLLocationCoordinate2D(latitude: 20, longitude: 0)
    var latDelta: Double = 60
}

// MARK: - Map View

struct VisitedCountriesMapView: View {
    let visitedCountryIDs: Set<String>
    let wantToVisitCountryIDs: Set<String>
    var zoomCommand: MapZoomCommand?
    var onCountryTapped: ((String) -> Void)?
    var bitmojiAnnotations: [CountryBitmojiAnnotation] = []
    var onBitmojiTapped: ((String) -> Void)?
    var onLatDeltaChanged: ((Double) -> Void)?

    @State private var cameraPosition: MapCameraPosition = .camera(MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        distance: 20_000_000,
        heading: 0,
        pitch: 0
    ))
    /// Full-resolution overlays — tap hit-testing only.
    @State private var overlaysByCountry: [String: [MKOverlay]] = [:]
    /// Simplified geometry pre-flattened into render items, built once at load.
    @State private var polygonItemsByCountry: [String: [CountryPolygonItem]] = [:]
    @State private var polygonItems: [CountryPolygonItem] = []
    @State private var camera = CameraTracker()

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                ForEach(polygonItems) { item in
                    MapPolygon(item.polygon)
                        .foregroundStyle(fillColor(for: item.countryID))
                        .stroke(strokeColor(for: item.countryID), lineWidth: lineWidth(for: item.countryID))
                }
                ForEach(bitmojiAnnotations, id: \.countryID) { annotation in
                    Annotation("", coordinate: annotation.coordinate, anchor: .bottom) {
                        BitmojiAnnotationView(annotation: annotation)
                            .onTapGesture {
                                onBitmojiTapped?(annotation.countryID)
                            }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .onMapCameraChange(frequency: .onEnd) { context in
                let actualDelta = context.region.span.latitudeDelta
                camera.center = context.camera.centerCoordinate
                camera.latDelta = actualDelta
                onLatDeltaChanged?(actualDelta)
            }
            .onTapGesture { location in
                guard let coordinate = proxy.convert(location, from: .local) else { return }
                handleMapTap(at: coordinate)
            }
        }
        .task {
            let (renderItems, hitTest) = await Task.detached(priority: .userInitiated) {
                (CountryPolygonItemBuilder.itemsByCountry(from: CountryBoundaryService.shared.getRenderOverlays()),
                 CountryBoundaryService.shared.getCountryOverlays())
            }.value
            polygonItemsByCountry = renderItems
            overlaysByCountry = hitTest
            updatePolygonItems()
        }
        .onChange(of: visitedCountryIDs) { _, _ in updatePolygonItems() }
        .onChange(of: wantToVisitCountryIDs) { _, _ in updatePolygonItems() }
        .onChange(of: zoomCommand) { _, newVal in
            guard let command = newVal else { return }
            cameraPosition = .region(MKCoordinateRegion(
                center: camera.center,
                span: MKCoordinateSpan(latitudeDelta: command.latDelta, longitudeDelta: command.latDelta)
            ))
        }
    }

    // MARK: - Styling

    private func fillColor(for countryID: String) -> Color {
        if visitedCountryIDs.contains(countryID) {
            return Color(red: 0.863, green: 0.149, blue: 0.149).opacity(0.75)
        } else {
            return Color(red: 0.486, green: 0.227, blue: 0.929).opacity(0.65)
        }
    }

    private func strokeColor(for countryID: String) -> Color {
        if visitedCountryIDs.contains(countryID) {
            return Color(red: 0.863, green: 0.149, blue: 0.149).opacity(0.95)
        } else {
            return Color(red: 0.486, green: 0.227, blue: 0.929).opacity(0.9)
        }
    }

    private func lineWidth(for countryID: String) -> CGFloat {
        visitedCountryIDs.contains(countryID) ? 1.5 : 1.2
    }

    // MARK: - Overlay Management

    private func updatePolygonItems() {
        polygonItems = CountryPolygonItemBuilder.items(
            for: visitedCountryIDs.union(wantToVisitCountryIDs),
            in: polygonItemsByCountry
        )
    }

    // MARK: - Tap Handling

    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        guard !overlaysByCountry.isEmpty else { return }

        let tapRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        )

        for (countryID, overlays) in overlaysByCountry {
            for overlay in overlays {
                guard tapRegion.intersects(overlay.boundingMapRect) else { continue }
                if overlayContains(overlay, coordinate: coordinate) {
                    onCountryTapped?(countryID)
                    return
                }
            }
        }
    }

    private func overlayContains(_ overlay: MKOverlay, coordinate: CLLocationCoordinate2D) -> Bool {
        if let polygon = overlay as? MKPolygon {
            return polygonContains(polygon, coordinate: coordinate)
        }
        if let multiPolygon = overlay as? MKMultiPolygon {
            return multiPolygon.polygons.contains { polygonContains($0, coordinate: coordinate) }
        }
        return false
    }

    private func polygonContains(_ polygon: MKPolygon, coordinate: CLLocationCoordinate2D) -> Bool {
        let renderer = MKPolygonRenderer(polygon: polygon)
        let mapPoint = MKMapPoint(coordinate)
        let polygonPoint = renderer.point(for: mapPoint)
        return renderer.path.contains(polygonPoint)
    }
}
