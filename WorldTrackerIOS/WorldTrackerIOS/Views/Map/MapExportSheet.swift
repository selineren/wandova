//
//  MapExportSheet.swift
//  WorldTrackerIOS
//

import SwiftUI

struct MapExportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let totalCountries: Int

    @State private var layer: LayerPick = .both
    @State private var style: StylePick = .flat
    @State private var preview: UIImage?
    @State private var isLoading = false
    @State private var showingActivity = false
    @State private var exportedImage: UIImage?

    // MARK: - Pickers

    enum LayerPick: String, CaseIterable {
        case both = "Both", visited = "Visited", wishlist = "Wishlist"

        var serviceLayer: MapExportLayer {
            switch self { case .both: .both; case .visited: .visited; case .wishlist: .wishlist }
        }
        var dotColor: Color? {
            switch self { case .both: nil; case .visited: .appVisited; case .wishlist: .appWishlist }
        }
    }

    enum StylePick: String, CaseIterable {
        case flat = "Flat", globe = "Globe"
        var icon: String   { self == .flat ? "map" : "globe" }
        var serviceStyle: MapExportStyle { self == .flat ? .flat : .globe }
        var previewRatio: CGFloat { self == .flat ? 720 / 450 : 540 / 640 }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerRow

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    previewCard
                    optionsPanel
                }
                .padding(.bottom, 24)
            }

            saveButton
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .padding(.top, 12)
        }
        .background(Color.appPaper)
        .task { await refresh() }
        .onChange(of: layer) { _, _ in Task { await refresh() } }
        .onChange(of: style) { _, _ in Task { await refresh() } }
        .sheet(isPresented: $showingActivity) {
            if let img = exportedImage {
                ActivitySheet(items: [img])
            }
        }
    }

    // MARK: - Top chrome

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.appInk3)
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 20)
    }

    private var headerRow: some View {
        HStack {
            Text("Travel Map")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.appInk)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appInk2)
                    .frame(width: 30, height: 30)
                    .background(Color.appPaper2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Preview

    private var previewCard: some View {
        ZStack {
            Group {
                if let img = preview {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else {
                    Rectangle()
                        .fill(Color.appPaper2)
                        .aspectRatio(style.previewRatio, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            if isLoading {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.35))
                ProgressView().tint(.white).scaleEffect(1.2)
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    // MARK: - Options

    private var optionsPanel: some View {
        VStack(spacing: 20) {
            layerPicker
            stylePicker
        }
        .padding(.horizontal, 24)
    }

    private var layerPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INCLUDE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.appInk3)
                .tracking(1.2)

            HStack(spacing: 8) {
                ForEach(LayerPick.allCases, id: \.self) { pick in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { layer = pick }
                    } label: {
                        HStack(spacing: 6) {
                            if let dot = pick.dotColor {
                                Circle().fill(dot).frame(width: 8, height: 8)
                            }
                            Text(pick.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(layer == pick ? .white : Color.appInk)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(layer == pick ? Color.appSurface : Color.appPaper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STYLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.appInk3)
                .tracking(1.2)

            HStack(spacing: 8) {
                ForEach(StylePick.allCases, id: \.self) { pick in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { style = pick }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: pick.icon)
                                .font(.system(size: 15, weight: .medium))
                            Text(pick.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(style == pick ? .white : Color.appInk2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(style == pick ? Color.appSurface : Color.appPaper2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button { Task { await exportAndShare() } } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isLoading ? "Generating…" : "Save & Share")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    // MARK: - Logic

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        preview = await MapSnapshotService.shared.render(
            visitedIDs: appState.visitedCountryIDs,
            wishlistIDs: appState.wantToVisitCountryIDs,
            layer: layer.serviceLayer,
            style: style.serviceStyle,
            highQuality: false
        )
    }

    private func exportAndShare() async {
        guard !isLoading else { return }
        isLoading = true
        let img = await MapSnapshotService.shared.render(
            visitedIDs: appState.visitedCountryIDs,
            wishlistIDs: appState.wantToVisitCountryIDs,
            layer: layer.serviceLayer,
            style: style.serviceStyle,
            highQuality: true
        )
        isLoading = false
        exportedImage = img
        showingActivity = true
    }
}

// MARK: - Activity sheet wrapper

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
