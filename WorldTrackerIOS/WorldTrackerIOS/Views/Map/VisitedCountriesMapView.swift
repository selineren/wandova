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

private extension MKPolygon {
    var locationCoordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Data Models

private struct PolygonItem: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let countryID: String
}

// MARK: - Map View

struct VisitedCountriesMapView: View {
    let visitedCountryIDs: Set<String>
    let wantToVisitCountryIDs: Set<String>
    @Binding var latDelta: Double
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
    @State private var overlaysByCountry: [String: [MKOverlay]] = [:]
    @State private var polygonItems: [PolygonItem] = []
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 20, longitude: 0)
    @State private var internalLatDelta: Double = 60

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                ForEach(polygonItems) { item in
                    MapPolygon(coordinates: item.coordinates)
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
                currentCenter = context.camera.centerCoordinate
                internalLatDelta = actualDelta
                onLatDeltaChanged?(actualDelta)
            }
            .onTapGesture { location in
                guard let coordinate = proxy.convert(location, from: .local) else { return }
                handleMapTap(at: coordinate)
            }
        }
        .task {
            let raw = await Task.detached(priority: .userInitiated) {
                CountryBoundaryService.shared.getCountryOverlays()
            }.value
            overlaysByCountry = raw
            updatePolygonItems()
        }
        .onChange(of: visitedCountryIDs) { _, _ in updatePolygonItems() }
        .onChange(of: wantToVisitCountryIDs) { _, _ in updatePolygonItems() }
        .onChange(of: latDelta) { _, newVal in
            guard abs(newVal - internalLatDelta) > 0.01 else { return }
            internalLatDelta = newVal
            cameraPosition = .region(MKCoordinateRegion(
                center: currentCenter,
                span: MKCoordinateSpan(latitudeDelta: newVal, longitudeDelta: newVal)
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
        let activeCountries = visitedCountryIDs.union(wantToVisitCountryIDs)
        var items: [PolygonItem] = []
        for countryID in activeCountries {
            guard let overlays = overlaysByCountry[countryID] else { continue }
            var idx = 0
            for overlay in overlays {
                if let polygon = overlay as? MKPolygon {
                    items.append(PolygonItem(
                        id: "\(countryID)_\(idx)",
                        coordinates: polygon.locationCoordinates,
                        countryID: countryID
                    ))
                    idx += 1
                } else if let multiPolygon = overlay as? MKMultiPolygon {
                    for subPolygon in multiPolygon.polygons {
                        items.append(PolygonItem(
                            id: "\(countryID)_\(idx)",
                            coordinates: subPolygon.locationCoordinates,
                            countryID: countryID
                        ))
                        idx += 1
                    }
                }
            }
        }
        polygonItems = items
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
