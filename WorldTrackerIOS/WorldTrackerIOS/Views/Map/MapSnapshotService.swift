//
//  MapSnapshotService.swift
//  WorldTrackerIOS
//

import UIKit
import MapKit

// MARK: - Enums

enum MapExportLayer {
    case both, visited, wishlist
}

enum MapExportStyle {
    case flat, globe
}

// MARK: - Service

final class MapSnapshotService {
    static let shared = MapSnapshotService()
    private init() {}

    // highQuality=false → fast 1x preview; true → 2x export
    func render(
        visitedIDs: Set<String>,
        wishlistIDs: Set<String>,
        layer: MapExportLayer,
        style: MapExportStyle,
        highQuality: Bool
    ) async -> UIImage {
        let effVisited: Set<String>  = (layer == .wishlist) ? [] : visitedIDs
        let effWishlist: Set<String> = (layer == .visited)  ? [] : wishlistIDs
        let visitedCount  = effVisited.count
        let wishlistCount = effWishlist.count
        let scale: CGFloat = highQuality ? 2 : 1

        return await Task.detached(priority: .userInitiated) { [effVisited, effWishlist] in
            let overlays = CountryBoundaryService.shared.getCountryOverlays()
            switch style {
            case .flat:
                return Self.renderFlat(
                    overlays: overlays, visitedIDs: effVisited, wishlistIDs: effWishlist,
                    layer: layer, visitedCount: visitedCount, wishlistCount: wishlistCount, scale: scale
                )
            case .globe:
                return Self.renderGlobe(
                    overlays: overlays, visitedIDs: effVisited, wishlistIDs: effWishlist,
                    layer: layer, visitedCount: visitedCount, wishlistCount: wishlistCount, scale: scale
                )
            }
        }.value
    }

    // MARK: - Flat (Mercator)

    private static func renderFlat(
        overlays: [String: [MKOverlay]],
        visitedIDs: Set<String>,
        wishlistIDs: Set<String>,
        layer: MapExportLayer,
        visitedCount: Int,
        wishlistCount: Int,
        scale: CGFloat
    ) -> UIImage {
        let size     = CGSize(width: 720, height: 450)
        let footerH  = size.height * 0.13
        let mapSize  = CGSize(width: size.width, height: size.height - footerH)
        let proj     = FlatProjection(size: mapSize)

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext

            UIColor(hex: "#080F1A").setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            for (id, countryOverlays) in overlays {
                let fill = landColor(id, visited: visitedIDs, wishlist: wishlistIDs)
                for overlay in countryOverlays {
                    if let poly = overlay as? MKPolygon {
                        drawFlatPoly(poly, ctx: cg, fill: fill, proj: proj)
                    } else if let multi = overlay as? MKMultiPolygon {
                        for poly in multi.polygons { drawFlatPoly(poly, ctx: cg, fill: fill, proj: proj) }
                    }
                }
            }

            drawFlatFooter(ctx: cg, size: size, footerH: footerH,
                           layer: layer, visitedCount: visitedCount, wishlistCount: wishlistCount)
        }
    }

    private static func drawFlatPoly(_ polygon: MKPolygon, ctx: CGContext, fill: UIColor, proj: FlatProjection) {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
        guard coords.count >= 3 else { return }

        ctx.saveGState()
        let path = CGMutablePath()
        addFlatRing(&coords, to: path, proj: proj)
        if let holes = polygon.interiorPolygons {
            for hole in holes {
                var hc = [CLLocationCoordinate2D](repeating: .init(), count: hole.pointCount)
                hole.getCoordinates(&hc, range: NSRange(location: 0, length: hole.pointCount))
                addFlatRing(&hc, to: path, proj: proj)
            }
        }
        ctx.addPath(path)
        ctx.setFillColor(fill.cgColor)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.11).cgColor)
        ctx.setLineWidth(0.35)
        ctx.drawPath(using: .eoFillStroke)
        ctx.restoreGState()
    }

    private static func addFlatRing(_ coords: inout [CLLocationCoordinate2D], to path: CGMutablePath, proj: FlatProjection) {
        guard !coords.isEmpty else { return }
        path.move(to: proj.point(coords[0]))
        for i in 1..<coords.count {
            if abs(coords[i].longitude - coords[i - 1].longitude) > 180 {
                path.closeSubpath()
                path.move(to: proj.point(coords[i]))
            } else {
                path.addLine(to: proj.point(coords[i]))
            }
        }
        path.closeSubpath()
    }

    private static func drawFlatFooter(
        ctx: CGContext, size: CGSize, footerH: CGFloat,
        layer: MapExportLayer, visitedCount: Int, wishlistCount: Int
    ) {
        let footerY = size.height - footerH

        ctx.saveGState()
        UIColor(hex: "#0C1320").setFill()
        ctx.fill(CGRect(x: 0, y: footerY, width: size.width, height: footerH))
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.06).cgColor)
        ctx.fill(CGRect(x: 0, y: footerY, width: size.width, height: 0.5))
        ctx.restoreGState()

        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: 2.0
        ]
        let name   = NSAttributedString(string: "WORLDTRACKER", attributes: nameAttr)
        let nameSz = name.size()
        let nameY  = footerY + (footerH - nameSz.height) / 2 - 9
        name.draw(at: CGPoint(x: (size.width - nameSz.width) / 2, y: nameY))

        let statsAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.45)
        ]
        let statsStr = NSAttributedString(string: footerStats(layer: layer, visitedCount: visitedCount, wishlistCount: wishlistCount), attributes: statsAttr)
        let statsSz  = statsStr.size()
        statsStr.draw(at: CGPoint(x: (size.width - statsSz.width) / 2, y: nameY + nameSz.height + 5))
    }

    // MARK: - Globe (Orthographic)

    private static func renderGlobe(
        overlays: [String: [MKOverlay]],
        visitedIDs: Set<String>,
        wishlistIDs: Set<String>,
        layer: MapExportLayer,
        visitedCount: Int,
        wishlistCount: Int,
        scale: CGFloat
    ) -> UIImage {
        let size    = CGSize(width: 540, height: 640)
        let footerH = size.height * 0.15
        let mapH    = size.height - footerH
        let radius  = min(size.width, mapH) * 0.43
        let gc      = CGPoint(x: size.width / 2, y: mapH / 2)
        let pc      = CLLocationCoordinate2D(latitude: 25, longitude: 15)
        let rect    = CGRect(x: gc.x - radius, y: gc.y - radius, width: radius * 2, height: radius * 2)

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = scale
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext

            UIColor(hex: "#07070A").setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Ambient glow
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: radius * 0.18, color: UIColor(hex: "#1A3A5C").withAlphaComponent(0.55).cgColor)
            UIColor(hex: "#0A1929").setFill()
            cg.addEllipse(in: rect.insetBy(dx: -1, dy: -1)); cg.fillPath()
            cg.restoreGState()

            // Ocean gradient
            cg.saveGState()
            cg.addEllipse(in: rect); cg.clip()
            let oceanColors = [UIColor(hex: "#0D1B2A").cgColor, UIColor(hex: "#060D15").cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: oceanColors, locations: [0.0, 1.0]) {
                let lp = CGPoint(x: gc.x - radius * 0.25, y: gc.y - radius * 0.3)
                cg.drawRadialGradient(grad, startCenter: lp, startRadius: 0, endCenter: gc, endRadius: radius * 1.15, options: [])
            }
            cg.restoreGState()

            // Countries
            cg.saveGState()
            cg.addEllipse(in: rect); cg.clip()
            for (id, countryOverlays) in overlays {
                let fill = landColor(id, visited: visitedIDs, wishlist: wishlistIDs)
                for overlay in countryOverlays {
                    if let poly = overlay as? MKPolygon {
                        drawGlobePoly(poly, ctx: cg, fill: fill, center: gc, radius: radius, projCenter: pc)
                    } else if let multi = overlay as? MKMultiPolygon {
                        for poly in multi.polygons {
                            drawGlobePoly(poly, ctx: cg, fill: fill, center: gc, radius: radius, projCenter: pc)
                        }
                    }
                }
            }
            cg.restoreGState()

            // Specular sheen
            cg.saveGState()
            cg.addEllipse(in: rect); cg.clip()
            let sheenColors = [UIColor.white.withAlphaComponent(0.07).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sheenColors, locations: [0.0, 1.0]) {
                let lp = CGPoint(x: gc.x - radius * 0.3, y: gc.y - radius * 0.3)
                cg.drawRadialGradient(sheen, startCenter: lp, startRadius: 0, endCenter: gc, endRadius: radius, options: [])
            }
            cg.restoreGState()

            // Globe border
            cg.addEllipse(in: rect)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
            cg.setLineWidth(1); cg.strokePath()

            drawGlobeFooter(ctx: cg, size: size, footerH: footerH,
                            layer: layer, visitedCount: visitedCount, wishlistCount: wishlistCount)
        }
    }

    private static func drawGlobePoly(
        _ polygon: MKPolygon, ctx: CGContext, fill: UIColor,
        center: CGPoint, radius: CGFloat, projCenter: CLLocationCoordinate2D
    ) {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
        guard coords.count >= 3 else { return }

        ctx.saveGState()
        let path = CGMutablePath()
        addGlobeRing(&coords, to: path, center: center, radius: radius, projCenter: projCenter)
        if let holes = polygon.interiorPolygons {
            for hole in holes {
                var hc = [CLLocationCoordinate2D](repeating: .init(), count: hole.pointCount)
                hole.getCoordinates(&hc, range: NSRange(location: 0, length: hole.pointCount))
                addGlobeRing(&hc, to: path, center: center, radius: radius, projCenter: projCenter)
            }
        }
        ctx.addPath(path)
        ctx.setFillColor(fill.cgColor)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.09).cgColor)
        ctx.setLineWidth(0.25)
        ctx.drawPath(using: .eoFillStroke)
        ctx.restoreGState()
    }

    private static func addGlobeRing(
        _ coords: inout [CLLocationCoordinate2D], to path: CGMutablePath,
        center: CGPoint, radius: CGFloat, projCenter: CLLocationCoordinate2D
    ) {
        var prevVisible = false
        for coord in coords {
            guard let pt = ortho(coord, center: center, radius: radius, projCenter: projCenter) else {
                prevVisible = false; continue
            }
            prevVisible ? path.addLine(to: pt) : path.move(to: pt)
            prevVisible = true
        }
        if prevVisible { path.closeSubpath() }
    }

    private static func ortho(
        _ coord: CLLocationCoordinate2D, center: CGPoint, radius: CGFloat,
        projCenter: CLLocationCoordinate2D
    ) -> CGPoint? {
        let lat  = coord.latitude  * .pi / 180
        let lon  = coord.longitude * .pi / 180
        let lat0 = projCenter.latitude  * .pi / 180
        let lon0 = projCenter.longitude * .pi / 180
        let cosC = sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(lon - lon0)
        guard cosC >= 0 else { return nil }
        let x = cos(lat) * sin(lon - lon0)
        let y = cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(lon - lon0)
        return CGPoint(x: center.x + CGFloat(x) * radius, y: center.y - CGFloat(y) * radius)
    }

    private static func drawGlobeFooter(
        ctx: CGContext, size: CGSize, footerH: CGFloat,
        layer: MapExportLayer, visitedCount: Int, wishlistCount: Int
    ) {
        let footerY = size.height - footerH

        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: 2.0
        ]
        let name   = NSAttributedString(string: "WORLDTRACKER", attributes: nameAttr)
        let nameSz = name.size()
        name.draw(at: CGPoint(x: (size.width - nameSz.width) / 2, y: footerY + 14))

        let statsAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.45)
        ]
        let statsStr = NSAttributedString(string: footerStats(layer: layer, visitedCount: visitedCount, wishlistCount: wishlistCount), attributes: statsAttr)
        let statsSz  = statsStr.size()
        statsStr.draw(at: CGPoint(x: (size.width - statsSz.width) / 2, y: footerY + 14 + nameSz.height + 6))
    }

    // MARK: - Shared helpers

    private static func landColor(_ id: String, visited: Set<String>, wishlist: Set<String>) -> UIColor {
        if visited.contains(id)  { return UIColor(hex: "#DC2626") }
        if wishlist.contains(id) { return UIColor(hex: "#7C3AED") }
        return UIColor(hex: "#152030")
    }

    private static func footerStats(layer: MapExportLayer, visitedCount: Int, wishlistCount: Int) -> String {
        switch layer {
        case .visited:  return "\(visitedCount) countries visited"
        case .wishlist: return "\(wishlistCount) countries on wishlist"
        case .both:     return "\(visitedCount) visited  ·  \(wishlistCount) on wishlist"
        }
    }
}

// MARK: - Mercator projection

private struct FlatProjection {
    let size: CGSize
    private let latMin = -70.0, latMax = 85.0
    private let mercNMax: Double
    private let mercNMin: Double

    init(size: CGSize) {
        self.size = size
        mercNMax = log(tan(.pi / 4 + 85.0   * .pi / 180 / 2))
        mercNMin = log(tan(.pi / 4 + (-70.0) * .pi / 180 / 2))
    }

    func point(_ coord: CLLocationCoordinate2D) -> CGPoint {
        let x      = (coord.longitude + 180) / 360 * size.width
        let lat    = min(max(coord.latitude, latMin), latMax)
        let mercN  = log(tan(.pi / 4 + lat * .pi / 180 / 2))
        let y      = (1 - (mercN - mercNMin) / (mercNMax - mercNMin)) * size.height
        return CGPoint(x: x, y: y)
    }
}
