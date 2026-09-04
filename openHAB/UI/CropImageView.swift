// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import PhotosUI
import SwiftUI

/// Full-screen photo crop sheet. Opens immediately and loads the photo
/// asynchronously — a spinner is shown in the crop circle while an iCloud
/// download is in progress. Pan with drag, zoom with pinch. The image may be
/// smaller than the crop circle; the chosen background color fills the gap.
/// The photo library button lets the user re-pick without leaving the view.
/// `onConfirm` receives a composited UIImage (background + image); `onCancel`
/// dismisses without changes.
struct CropImageView: View {
    let initialPhotoItem: PhotosPickerItem?
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var currentImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var fittedSize: CGSize = .zero
    // containerSize is updated via onGeometryChange inside the full-screen GR;
    // keeping it as @State lets onChange(of: currentImage) read the latest value.
    @State private var containerSize: CGSize = .zero
    @State private var backgroundHex: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var bgColorPickerWidth: CGFloat = 44

    private let cropDiameter: CGFloat = 280
    private let maxOffset: CGFloat = 280

    init(photoItem: PhotosPickerItem,
         initialBackgroundHex: String = HomeAvatarView.colorPalette[0],
         onConfirm: @escaping (UIImage) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialPhotoItem = photoItem
        _backgroundHex = State(initialValue: initialBackgroundHex)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    /// Opens the crop view pre-loaded with an existing `UIImage` — no async photo loading.
    init(image: UIImage,
         initialBackgroundHex: String = HomeAvatarView.colorPalette[0],
         onConfirm: @escaping (UIImage) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialPhotoItem = nil
        _currentImage = State(initialValue: image)
        _isLoading = State(initialValue: false)
        _backgroundHex = State(initialValue: initialBackgroundHex)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var backgroundColor: Color {
        Color(hex: backgroundHex) ?? HomeAvatarView.defaultColor
    }

    var body: some View {
        ZStack {
            // ── Layer 1: full-screen content (ignores safe area) ──────────────
            // Uses its own GeometryReader so geo.size is always the full-screen
            // size, which must match the image frame used in setupLayout / crop().
            GeometryReader { geo in
                ZStack {
                    Color.black

                    Circle()
                        .fill(backgroundColor)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .allowsHitTesting(false)

                    if let img = currentImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    DragGesture()
                                        .onChanged { v in
                                            offset = clamped(CGSize(
                                                width: lastOffset.width + v.translation.width,
                                                height: lastOffset.height + v.translation.height
                                            ))
                                        }
                                        .onEnded { _ in lastOffset = offset },
                                    MagnifyGesture()
                                        .onChanged { v in
                                            scale = max(0.1, min(5, lastScale * v.magnification))
                                            offset = clamped(offset)
                                        }
                                        .onEnded { _ in lastScale = scale }
                                )
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .frame(width: cropDiameter, height: cropDiameter)
                    }

                    CropMaskCanvas(cropDiameter: cropDiameter)
                        .allowsHitTesting(false)

                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                        .frame(width: cropDiameter, height: cropDiameter)
                        .allowsHitTesting(false)
                }
                // onGeometryChange fires on every layout pass (including after the
                // fullScreenCover animation completes), so containerSize is always
                // current. If the image arrived before layout was valid, we catch up here.
                .onGeometryChange(for: CGSize.self, of: { $0.size }) { newSize in
                    containerSize = newSize
                    guard currentImage != nil else { return }
                    setupLayout(containerSize: newSize)
                }
                // Fires when the image becomes available. Uses the stored containerSize
                // which is kept current by onGeometryChange above.
                .onChange(of: currentImage) { _, img in
                    guard img != nil, containerSize != .zero else { return }
                    setupLayout(containerSize: containerSize)
                }
            }
            .ignoresSafeArea()

            // ── Layer 2: UI controls ──────────────────────────────────────────
            // This VStack is NOT inside .ignoresSafeArea(), so SwiftUI positions
            // it within the safe area automatically — buttons sit below the notch
            // without any manual safeAreaInsets.top arithmetic.
            VStack {
                topBar
                Spacer()
                backgroundColorRow
                    .padding(.bottom, 40)
            }
        }
        .statusBarHidden()
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            isLoading = true
            currentImage = nil
            loadFailed = false
            Task { @MainActor in
                await loadPhoto(item)
                selectedPhoto = nil // reset so the same photo can be re-picked
            }
        }
        .task {
            guard let item = initialPhotoItem else { return }
            await loadPhoto(item)
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            isLoading = false
            loadFailed = true
            return
        }
        currentImage = uiImage
        isLoading = false
        loadFailed = false
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            photoPickerButton
            Spacer()
            Button("Cancel") { onCancel() }
                .foregroundStyle(.white)
                .padding(.trailing, 16)
            Button("Choose") { crop() }
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .disabled(currentImage == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var photoPickerButton: some View {
        if #available(iOS 26, *) {
            Button { showPhotoPicker = true } label: {
                Image(systemName: "photo.stack")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(GlassButtonStyle())
        } else {
            Button { showPhotoPicker = true } label: {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Background color row

    @ViewBuilder
    private var bgColorPicker: some View {
        if #available(iOS 26, *) {
            ColorPicker("", selection: Binding(
                get: { Color(hex: backgroundHex) ?? HomeAvatarView.defaultColor },
                set: { backgroundHex = $0.hexString }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 28, height: 28)
            .padding(7)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 13))
        } else {
            ColorPicker("", selection: Binding(
                get: { Color(hex: backgroundHex) ?? HomeAvatarView.defaultColor },
                set: { backgroundHex = $0.hexString }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 28, height: 28)
        }
    }

    private var backgroundColorRowContent: some View {
        let pinLeading: CGFloat = 10
        let gap: CGFloat = 10
        return ZStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HomeAvatarView.colorPalette, id: \.self) { hex in
                        let color = Color(hex: hex) ?? .blue
                        let isSelected = backgroundHex == hex
                        Button { backgroundHex = hex } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if isSelected { Circle().strokeBorder(.white, lineWidth: 2.5) }
                                }
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, pinLeading + bgColorPickerWidth + gap)
                .padding(.trailing, 8)
                .padding(.vertical, 10)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 32)
                .allowsHitTesting(false)
            }

            if #available(iOS 26, *) {
            } else {
                LinearGradient(
                    colors: [.black.opacity(0.6), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: pinLeading + bgColorPickerWidth + 20)
                .allowsHitTesting(false)
            }

            bgColorPicker
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { bgColorPickerWidth = $0 }
                .padding(.leading, pinLeading)
        }
    }

    @ViewBuilder
    private var backgroundColorRow: some View {
        if #available(iOS 26, *) {
            backgroundColorRowContent
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
        } else {
            backgroundColorRowContent
                .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Layout

    private func setupLayout(containerSize: CGSize) {
        guard let img = currentImage, containerSize != .zero else { return }
        let aspect = img.size.width / img.size.height
        let cAspect = containerSize.width / containerSize.height
        fittedSize = aspect > cAspect
            ? CGSize(width: containerSize.width, height: containerSize.width / aspect)
            : CGSize(width: containerSize.height * aspect, height: containerSize.height)
        let initialScale = min(cropDiameter / fittedSize.width, cropDiameter / fittedSize.height)
        scale = max(0.1, initialScale)
        lastScale = scale
        offset = .zero
        lastOffset = .zero
    }

    // MARK: - Clamping

    private func clamped(_ proposed: CGSize) -> CGSize {
        CGSize(
            width: max(-maxOffset, min(maxOffset, proposed.width)),
            height: max(-maxOffset, min(maxOffset, proposed.height))
        )
    }

    // MARK: - Compositing crop

    private func crop() {
        guard let img = currentImage else { return }
        let dw = fittedSize.width * scale
        let dh = fittedSize.height * scale
        let imageInCropX = offset.width - dw / 2 + cropDiameter / 2
        let imageInCropY = offset.height - dh / 2 + cropDiameter / 2

        let canvasSize = CGSize(width: cropDiameter, height: cropDiameter)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let result = renderer.image { _ in
            UIColor(backgroundColor).setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            img.draw(in: CGRect(x: imageInCropX, y: imageInCropY, width: dw, height: dh))
        }
        onConfirm(result)
    }
}

// MARK: - Overlay with circular cutout

private struct CropMaskCanvas: View {
    let cropDiameter: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addEllipse(in: CGRect(
                x: size.width / 2 - cropDiameter / 2,
                y: size.height / 2 - cropDiameter / 2,
                width: cropDiameter,
                height: cropDiameter
            ))
            ctx.fill(path, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
        .ignoresSafeArea()
    }
}
