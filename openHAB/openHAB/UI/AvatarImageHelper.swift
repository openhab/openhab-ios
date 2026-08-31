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

import SwiftUI

/// Saves and loads per-home avatar images to/from Application Support.
///
/// Images are stored as JPEG files at:
///   `<App Support>/homes/<uuid>.jpg`
///
/// Before writing, the image is downscaled so neither dimension exceeds the
/// device's full native screen resolution (in pixels). Only the file path is
/// persisted in `HomePreferences` — raw image data is never written to
/// UserDefaults.
///
/// Public API uses SwiftUI `Image`. UIKit is an implementation detail.
enum AvatarImageHelper {
    private static var homesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("homes", isDirectory: true)
    }

    static func avatarURL(for homeId: UUID) -> URL {
        homesDirectory.appendingPathComponent("\(homeId.uuidString).jpg")
    }

    // MARK: - Public SwiftUI API

    /// Saves photo `data` for `homeId` after downscaling to screen resolution.
    /// Returns the resulting `Image` for immediate display, or `nil` on failure.
    @MainActor
    @discardableResult
    static func save(_ data: Data, for homeId: UUID) -> Image? {
        guard let uiImage = UIImage(data: data) else { return nil }
        let downscaled = downscale(uiImage)
        guard writeJPEG(downscaled, to: avatarURL(for: homeId)) else { return nil }
        return Image(uiImage: downscaled)
    }

    /// Loads the stored avatar for `homeId` as a SwiftUI `Image`, or `nil` if none is saved.
    static func load(for homeId: UUID) -> Image? {
        let url = avatarURL(for: homeId)
        guard FileManager.default.fileExists(atPath: url.path),
              let uiImage = UIImage(contentsOfFile: url.path)
        else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Loads the avatar from an explicit file path stored in `HomePreferences`.
    static func load(atPath path: String?) -> Image? {
        guard let path, !path.isEmpty,
              let uiImage = UIImage(contentsOfFile: path)
        else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Deletes the stored avatar for `homeId`. Safe to call when no file exists.
    static func delete(for homeId: UUID) {
        try? FileManager.default.removeItem(at: avatarURL(for: homeId))
    }

    // MARK: - Internal image processing

    /// Downscales `image` so neither dimension exceeds the device's native screen
    /// resolution (in pixels). Images already within bounds are returned unchanged.
    @MainActor
    static func downscale(_ image: UIImage) -> UIImage {
        downscale(image, maxSize: nativeScreenSize())
    }

    /// Pure downscale with an explicit `maxSize` — testable without a screen.
    static func downscale(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let size = image.size
        guard size.width > maxSize.width || size.height > maxSize.height else {
            return image
        }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Returns the native pixel dimensions of the main screen (already includes scale factor).
    @MainActor
    static func nativeScreenSize() -> CGSize {
        UIScreen.main.nativeBounds.size
    }

    private static func writeJPEG(_ image: UIImage, to url: URL) -> Bool {
        let dir = url.deletingLastPathComponent()
        guard (try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)) != nil,
              let data = image.jpegData(compressionQuality: 0.85),
              (try? data.write(to: url, options: .atomic)) != nil
        else { return false }
        return true
    }
}
