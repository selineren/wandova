//
//  CountryDetailScreen.swift
//  Wandova
//
//  Created by seren on 26.02.2026.
//

import SwiftUI
import PhotosUI

struct CountryDetailScreen: View {
    @EnvironmentObject private var appState: AppState
    let country: Country

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDatePicker = false
    @State private var fullScreenPhoto: VisitPhoto?
    @State private var showAllPhotos = false
    @FocusState private var isEditingNotes: Bool

    // MARK: - Bindings

    private var isVisited: Binding<Bool> {
        Binding(
            get: { appState.visit(for: country.id).isVisited },
            set: { newValue in
                if newValue {
                    let existing = appState.visit(for: country.id).visitedDate
                    appState.setVisited(country.id, isVisited: true, visitedDate: existing ?? Date())
                } else {
                    appState.setVisited(country.id, isVisited: false)
                }
            }
        )
    }

    private var visitDate: Binding<Date> {
        Binding(
            get: { appState.visit(for: country.id).visitedDate ?? Date() },
            set: { appState.setVisited(country.id, isVisited: true, visitedDate: $0) }
        )
    }

    private var notes: Binding<String> {
        Binding(
            get: { appState.visit(for: country.id).notes },
            set: { appState.updateNotes(country.id, notes: $0) }
        )
    }

    private var wantToVisitBinding: Binding<Bool> {
        Binding(
            get: { appState.wantToVisit(country.id) },
            set: { appState.setWantToVisit(country.id, wantToVisit: $0) }
        )
    }

    private var photos: [VisitPhoto] {
        appState.visits[country.id]?.photos ?? []
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                statusCard
                notesCard
                photosCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.appPaper)
        .navigationTitle(country.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditingNotes = false }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task { await loadPhoto(from: newValue) }
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            PhotoFullScreenView(photo: photo) {
                appState.removePhoto(country.id, photoId: photo.id)
                fullScreenPhoto = nil
            }
        }
        .sheet(isPresented: $showAllPhotos) {
            AllPhotosSheetView(photos: photos) { photoId in
                appState.removePhoto(country.id, photoId: photoId)
            }
        }
    }

    // MARK: - Hero Card (intentionally dark in both modes)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(country.flagEmoji)
                    .font(.system(size: 56))
                Spacer()
                statusBadge
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(country.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.3)

                Text(country.continent.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .tracking(1.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isVisited.wrappedValue {
            Text("Visited")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#2E9E5B"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#2E9E5B").opacity(0.18))
                .clipShape(Capsule())
        } else if wantToVisitBinding.wrappedValue {
            Text("Wishlist")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#93E0FA"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#93E0FA").opacity(0.18))
                .clipShape(Capsule())
        } else {
            Text("Not Visited")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Travel Status")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appInk)

            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isVisited.wrappedValue.toggle()
                        if isVisited.wrappedValue { wantToVisitBinding.wrappedValue = false }
                    }
                } label: {
                    statusRow(
                        icon: "checkmark.circle.fill",
                        iconBg: isVisited.wrappedValue ? Color.appSuccess.opacity(0.12) : Color.appInk.opacity(0.06),
                        iconFg: isVisited.wrappedValue ? Color.appSuccess : Color.appInk3,
                        title: "Visited",
                        checked: isVisited.wrappedValue,
                        checkColor: Color.appSuccess
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 16)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if !isVisited.wrappedValue {
                            wantToVisitBinding.wrappedValue.toggle()
                        }
                    }
                } label: {
                    statusRow(
                        icon: "star.fill",
                        iconBg: wantToVisitBinding.wrappedValue ? Color(hex: "#4A90D9").opacity(0.12) : Color.appInk.opacity(0.06),
                        iconFg: wantToVisitBinding.wrappedValue ? Color(hex: "#4A90D9") : Color.appInk3,
                        title: "Want to Visit",
                        titleColor: isVisited.wrappedValue ? Color.appInk3 : Color.appInk,
                        checked: wantToVisitBinding.wrappedValue,
                        checkColor: Color(hex: "#4A90D9")
                    )
                }
                .buttonStyle(.plain)
                .disabled(isVisited.wrappedValue)

                if isVisited.wrappedValue {
                    Divider().padding(.horizontal, 16)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color(hex: "#4A90D9").opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#4A90D9"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Visit Date")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appInk3)
                            Text(visitDate.wrappedValue, format: .dateTime.month(.wide).day().year())
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) { showDatePicker.toggle() }
                        } label: {
                            Text("Edit")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appInk3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if showDatePicker {
                        Divider().padding(.horizontal, 16)
                        DatePicker("", selection: visitDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    private func statusRow(
        icon: String,
        iconBg: Color,
        iconFg: Color,
        title: String,
        titleColor: Color = Color.appInk,
        checked: Bool,
        checkColor: Color
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconBg).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconFg)
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(titleColor)
            Spacer()
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(checkColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notes")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appInk)

            ZStack(alignment: .topLeading) {
                if notes.wrappedValue.isEmpty {
                    Text("Add travel highlights, tips, and hidden gems for \(country.name)...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appInk3)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: notes)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appInk)
                    .frame(minHeight: 100)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .focused($isEditingNotes)
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Photos Card

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Photos")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.appInk)
                Spacer()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add Photo")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.appInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appPaper2)
                    .clipShape(Capsule())
                }
            }

            if photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.appInk3)
                    Text("No photos yet")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appInk3)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
            } else {
                let displayed = Array(photos.prefix(4))
                let remaining = max(0, photos.count - 4)
                let cellSize = (UIScreen.main.bounds.width - 32 - 12) / 2
                let rows = Int(ceil(Double(displayed.count) / 2.0))
                let gridHeight = CGFloat(rows) * cellSize + CGFloat(rows - 1) * 12

                VStack(spacing: 12) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(0..<2, id: \.self) { col in
                                let idx = row * 2 + col
                                if idx < displayed.count {
                                    let isOverlay = idx == 3 && remaining > 0
                                    photoCell(
                                        photo: displayed[idx],
                                        size: cellSize,
                                        showOverlay: isOverlay,
                                        remaining: remaining
                                    ) {
                                        if isOverlay { showAllPhotos = true }
                                        else { fullScreenPhoto = displayed[idx] }
                                    }
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
                .frame(height: gridHeight)
            }
        }
    }

    private func photoCell(photo: VisitPhoto, size: CGFloat, showOverlay: Bool, remaining: Int, onTap: @escaping () -> Void) -> some View {
        Button { onTap() } label: {
            ZStack {
                Color.appPaper2
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                        .opacity(showOverlay ? 0.5 : 1.0)
                }
                if showOverlay {
                    Color.black.opacity(0.3)
                    Text("+\(remaining)")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Loading

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let photo = VisitPhoto(imageData: compressImage(data))
            appState.addPhoto(country.id, photo: photo)
            selectedPhotoItem = nil
        } catch {
            print("⚠️ Error loading photo: \(error)")
        }
    }

    private func compressImage(_ data: Data) -> Data {
        guard var image = UIImage(data: data) else { return data }
        let maxSize = 300_000
        let maxDimension: CGFloat = 1200
        let size = image.size
        if size.width > maxDimension || size.height > maxDimension {
            let scale = min(maxDimension / size.width, maxDimension / size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() { image = resized }
            UIGraphicsEndImageContext()
        }
        var compression: CGFloat = 0.8
        guard var imageData = image.jpegData(compressionQuality: compression) else { return data }
        var attempts = 0
        while imageData.count > maxSize && compression > 0.1 && attempts < 10 {
            compression -= 0.1
            if let compressed = image.jpegData(compressionQuality: compression) { imageData = compressed }
            attempts += 1
        }
        return imageData
    }
}

// MARK: - Full Screen Photo Viewer

struct PhotoFullScreenView: View {
    let photo: VisitPhoto
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var showControls = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = max(1, $0) }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3)) {
                                    if scale < 1.1 { scale = 1; offset = .zero }
                                }
                            }
                            .simultaneously(with:
                                DragGesture()
                                    .onChanged { offset = scale > 1 ? $0.translation : .zero }
                                    .onEnded { _ in
                                        if scale <= 1 { withAnimation(.spring(response: 0.3)) { offset = .zero } }
                                    }
                            )
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
                    }
            }

            if showControls {
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Button(role: .destructive) { onDelete() } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden()
    }
}

// MARK: - All Photos Sheet

struct AllPhotosSheetView: View {
    let photos: [VisitPhoto]
    let onDelete: (UUID) -> Void

    @State private var selectedPhoto: VisitPhoto?
    @Environment(\.dismiss) private var dismiss

    private let spacing: CGFloat = 3
    private var cellSize: CGFloat {
        (UIScreen.main.bounds.width - spacing * 2) / 3
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(photos.count) Photos")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.appInk)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.appInk3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                let rows = Int(ceil(Double(photos.count) / 3.0))
                VStack(spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<3, id: \.self) { col in
                                let idx = row * 3 + col
                                if idx < photos.count {
                                    Button { selectedPhoto = photos[idx] } label: {
                                        photoThumb(photos[idx])
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.appPaper)
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoFullScreenView(photo: photo) {
                onDelete(photo.id)
                selectedPhoto = nil
            }
        }
    }

    private func photoThumb(_ photo: VisitPhoto) -> some View {
        ZStack {
            Color.appPaper2
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
