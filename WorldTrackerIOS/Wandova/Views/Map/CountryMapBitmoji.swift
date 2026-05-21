//
//  CountryMapBitmoji.swift
//  Wandova
//
//  Created by seren on 26.03.2026.
//

import SwiftUI
import MapKit

// MARK: - Map Annotation Data Model

class CountryBitmojiAnnotation: NSObject, MKAnnotation {
    let countryID: String
    let country: Country
    let visit: Visit

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: country.centroid.latitude,
            longitude: country.centroid.longitude
        )
    }

    var title: String? { country.name }

    init(country: Country, visit: Visit) {
        self.countryID = country.id
        self.country = country
        self.visit = visit
        super.init()
    }
}

// MARK: - Pin Tip Shape

private struct PinTip: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - SwiftUI Annotation View

struct BitmojiAnnotationView: View {
    let annotation: CountryBitmojiAnnotation

    private let headSize: CGFloat = 42

    var body: some View {
        VStack(spacing: -2) {
            // Pin head
            ZStack {
                Circle()
                    .fill(Color.appCard)

                if let photo = annotation.visit.photos.first,
                   let img = UIImage(data: photo.imageData) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .padding(2.5)
                } else {
                    Text(annotation.country.flagEmoji)
                        .font(.system(size: 22))
                }

                Circle()
                    .stroke(Color.appVisited, lineWidth: 2.5)
            }
            .frame(width: headSize, height: headSize)
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)

            // Pin tip
            PinTip()
                .fill(Color.appVisited)
                .frame(width: 13, height: 9)
        }
    }
}
