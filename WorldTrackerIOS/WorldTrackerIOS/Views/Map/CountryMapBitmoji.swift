//
//  CountryMapBitmoji.swift
//  WorldTrackerIOS
//
//  Created by seren on 26.03.2026.
//

import SwiftUI
import MapKit

// MARK: - Map Annotation for Country Bitmoji

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
    
    var title: String? {
        country.name
    }
    
    init(country: Country, visit: Visit) {
        self.countryID = country.id
        self.country = country
        self.visit = visit
        super.init()
    }
}

// MARK: - Annotation View

class CountryBitmojiAnnotationView: MKAnnotationView {
    static let identifier = "CountryBitmoji"
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.layer.borderWidth = 3.0
        iv.layer.borderColor = UIColor.white.cgColor
        return iv
    }()
    
    private let noteIconView: UIView = {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 3.0
        container.layer.borderColor = UIColor.white.cgColor

        let icon = UIImageView(image: UIImage(systemName: "note.text"))
        icon.tintColor = .darkGray
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])

        return container
    }()
    
    private let flagView: UIView = {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 3.0
        container.layer.borderColor = UIColor.white.cgColor
        return container
    }()
    
    private let flagLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        frame = CGSize(width: 32, height: 32).asRect
        centerOffset = CGPoint(x: 0, y: 0) // No offset - center the circle on the location
        
        addSubview(containerView)
        containerView.frame = bounds
        
        thumbnailImageView.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        noteIconView.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        flagView.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        
        flagView.addSubview(flagLabel)
        NSLayoutConstraint.activate([
            flagLabel.centerXAnchor.constraint(equalTo: flagView.centerXAnchor),
            flagLabel.centerYAnchor.constraint(equalTo: flagView.centerYAnchor)
        ])
        
        containerView.addSubview(thumbnailImageView)
        containerView.addSubview(noteIconView)
        containerView.addSubview(flagView)
        
        // Enable tap
        isEnabled = true
        canShowCallout = false
    }
    
    func configure(with annotation: CountryBitmojiAnnotation) {
        // Always set the flag
        flagLabel.text = annotation.country.flagEmoji
        
        if let firstPhoto = annotation.visit.photos.first,
           let image = UIImage(data: firstPhoto.imageData) {
            // Show photo thumbnail - this is the main feature!
            thumbnailImageView.image = image
            thumbnailImageView.isHidden = false
            noteIconView.isHidden = true
            flagView.isHidden = true
        } else if !annotation.visit.notes.isEmpty {
            // Show note icon when no photo
            thumbnailImageView.isHidden = true
            noteIconView.isHidden = false
            flagView.isHidden = true
        } else {
            // Show flag emoji when no content
            thumbnailImageView.isHidden = true
            noteIconView.isHidden = true
            flagView.isHidden = false
        }
    }
}

// MARK: - Helper Extension

extension CGSize {
    var asRect: CGRect {
        CGRect(origin: .zero, size: self)
    }
}

