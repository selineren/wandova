//
//  CountryMapPreviewBubble.swift
//  Wandova
//
//  Created by seren on 26.03.2026.
//

import SwiftUI
import MapKit

// MARK: - Map Annotation Bubble (Always Visible)

struct CountryMapAnnotationBubble: View {
    let country: Country
    let visit: Visit

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if let firstPhoto = visit.photos.first,
                   let uiImage = UIImage(data: firstPhoto.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#F9234D"))
                            .frame(width: 40, height: 40)
                        Text(country.flagEmoji)
                            .font(.system(size: 20))
                    }
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }

                Text(country.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1b1b1b"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)

            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 6)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Full Preview Bubble (Overlay Card)

struct CountryMapPreviewBubble: View {
    let country: Country
    let visit: Visit
    let onDismiss: () -> Void
    let onViewDetails: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header: flag + name + date + close
            HStack(spacing: 12) {
                Text(country.flagEmoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 3) {
                    Text(country.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#1b1b1b"))
                        .lineLimit(1)

                    if let date = visit.visitedDate {
                        Text(date.formatted(.dateTime.month(.abbreviated).year()))
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#9E9E9E"))
                    } else {
                        Text(country.continent.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#9E9E9E"))
                    }
                }

                Spacer()

                Button { animatedDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#CCCCCC"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, hasContent ? 12 : 4)

            // Photo strip
            if let firstPhoto = visit.photos.first,
               let uiImage = UIImage(data: firstPhoto.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                if visit.photos.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 11))
                        Text("\(visit.photos.count) photos")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(hex: "#9E9E9E"))
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }

            // Notes preview
            if !visit.notes.isEmpty {
                Text(visit.notes)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#6B6B6B"))
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.top, hasPhoto ? 10 : 0)
                    .padding(.bottom, 4)
            }

            // Divider + View Details row
            Divider()
                .padding(.horizontal, 16)
                .padding(.top, hasContent ? 12 : 0)

            Button { onViewDetails() } label: {
                HStack {
                    Text("View Details")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1b1b1b"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#CCCCCC"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 340)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 6)
        .scaleEffect(appeared ? 1.0 : 0.88)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    private var hasPhoto: Bool { !visit.photos.isEmpty }
    private var hasContent: Bool { !visit.photos.isEmpty || !visit.notes.isEmpty }

    private func animatedDismiss() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Preview Container

struct CountryPreviewData: Identifiable {
    let id: String
    let country: Country
    let visit: Visit

    init(country: Country, visit: Visit) {
        self.id = country.id
        self.country = country
        self.visit = visit
    }
}
