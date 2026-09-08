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

import OpenHABCore
import SwiftUI

/// Saves and loads per-home avatar images from Application Support.
///
/// Storage layout:
///   `<App Support>/homes/<uuid>/avatarImage.jpg`  — full-resolution original (no downscaling)
///
/// Crop parameters live in `HomePreferences.avatarMode` (as `.image(originX:originY:size:background:)`).
/// The helper maintains a `@MainActor` in-memory cache of rendered 280×280 thumbnails; it is
/// invalidated whenever a new original is saved or the home directory is deleted.
///
/// Raw image data is never written to UserDefaults. `HomePreferences` no longer stores a path.
enum AvatarImageHelper {
    // MARK: - File layout

    private static var homesDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("homes", isDirectory: true)
    }

    private static func homeDirectory(for homeId: UUID) -> URL {
        homesDirectory.appendingPathComponent(homeId.uuidString, isDirectory: true)
    }

    static func originalURL(for homeId: UUID) -> URL {
        homeDirectory(for: homeId).appendingPathComponent("avatarImage.jpg")
    }

    // MARK: - Render cache (main-actor, never persisted)

    @MainActor private static var renderCache: [UUID: UIImage] = [:]

    // MARK: - Public API

    /// Saves `image` as the original for `homeId` and synchronously clears the render cache.
    /// The image is stored full-resolution — no downscaling.
    @MainActor
    static func saveOriginal(_ image: UIImage, for homeId: UUID) {
        let url = originalURL(for: homeId)
        let dir = url.deletingLastPathComponent()
        guard (try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)) != nil,
              let data = image.jpegData(compressionQuality: 0.92),
              (try? data.write(to: url, options: .atomic)) != nil
        else { return }
        renderCache.removeValue(forKey: homeId)
    }

    /// Returns the full-resolution original for `homeId`, or `nil` if none is stored.
    static func loadOriginal(for homeId: UUID) -> UIImage? {
        let url = originalURL(for: homeId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Deletes the entire home directory (original + any future variants) and clears the cache.
    @MainActor
    static func deleteOriginal(for homeId: UUID) {
        try? FileManager.default.removeItem(at: homeDirectory(for: homeId))
        renderCache.removeValue(forKey: homeId)
    }

    /// Returns a rendered 280×280 SwiftUI `Image` for `homeId` in the given `mode`.
    /// Returns `nil` for `.icon` mode or `nil` mode (callers show the icon placeholder instead).
    /// Results are cached by `homeId`; the cache is invalidated on `saveOriginal`/`deleteOriginal`.
    @MainActor
    static func renderedAvatar(for homeId: UUID, mode: AvatarMode?) -> Image? {
        guard case .image = mode else { return nil }
        if let cached = renderCache[homeId] { return Image(uiImage: cached) }
        guard let original = loadOriginal(for: homeId),
              let rendered = renderCrop(original: original, mode: mode!)
        else { return nil }
        let thumb = downscale(rendered, maxSize: CGSize(width: 280, height: 280))
        renderCache[homeId] = thumb
        return Image(uiImage: thumb)
    }

    /// Renders a crop from an in-memory original (used for the preview before saving).
    /// Does not touch the cache.
    @MainActor
    static func renderPending(_ image: UIImage, mode: AvatarMode) -> Image? {
        guard let rendered = renderCrop(original: image, mode: mode) else { return nil }
        let thumb = downscale(rendered, maxSize: CGSize(width: 280, height: 280))
        return Image(uiImage: thumb)
    }

    // MARK: - Internal rendering

    /// Renders a 280×280 crop of `original` according to `mode`.
    /// Returns `nil` if mode is `.icon` or if the image is missing.
    static func renderCrop(original: UIImage, mode: AvatarMode) -> UIImage? {
        guard case .image(let ox, let oy, let sz, let bg) = mode, sz > 0 else { return nil }
        let outputSize = CGSize(width: 280, height: 280)
        // Scale factor: how many output pixels per image-space point
        let scale = CGFloat(280.0 / sz)
        let drawRect = CGRect(
            x: -CGFloat(ox) * scale,
            y: -CGFloat(oy) * scale,
            width: original.size.width * scale,
            height: original.size.height * scale
        )
        let bgColor = Color(hex: bg).map { UIColor($0) } ?? UIColor.systemBlue
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { _ in
            bgColor.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))
            // UIImage.draw(in:) respects EXIF orientation — this is why UIKit is used over CG.
            original.draw(in: drawRect)
        }
    }

    /// Downscales `image` so neither dimension exceeds `maxSize`. Images within bounds are
    /// returned unchanged. Pure function — testable without a screen.
    static func downscale(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let size = image.size
        guard size.width > maxSize.width || size.height > maxSize.height else { return image }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - AvatarMode display helpers (app-target only, uses CGPoint/CGFloat)

extension AvatarMode {
    /// The SF Symbol name for `.icon` mode, or `nil` for `.image` mode.
    var iconName: String? {
        if case .icon(let name, _) = self { return name }
        return nil
    }

    /// The hex color string for either mode (background color for icons, fill color for images).
    var colorHex: String {
        switch self {
        case .icon(_, let c): return c
        case .image(_, _, _, let bg): return bg
        }
    }

    /// `true` when this is a `.image` mode.
    var isPhoto: Bool {
        if case .image = self { return true }
        return false
    }

    /// Returns a new mode with the color/background replaced by `hex`.
    func withColor(_ hex: String) -> AvatarMode {
        switch self {
        case .icon(let name, _): return .icon(name: name, color: hex)
        case .image(let x, let y, let s, _): return .image(originX: x, originY: y, size: s, background: hex)
        }
    }

    var cropOrigin: CGPoint? {
        if case .image(let x, let y, _, _) = self { return CGPoint(x: x, y: y) }
        return nil
    }

    var cropSize: CGFloat? {
        if case .image(_, _, let s, _) = self { return CGFloat(s) }
        return nil
    }
}
