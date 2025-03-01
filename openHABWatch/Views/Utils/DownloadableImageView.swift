// Copyright (c) 2010-2025 Contributors to the openHAB project
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
import OSLog
import SDWebImage
import SDWebImageSVGCoder
import SwiftUI
import WatchKit

enum DownloadableImageError: Error {
    case failedToDecode
    case failedToLoad
    case nohttpClient
}

class SVGImageLoader: ObservableObject {
    @Published var uiImage: UIImage?

    func updateImage(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.uiImage = image
        }
    }
}

class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSURL, CachedImage>()
    private let expirationTime: TimeInterval = 300 // 5 minutes

    private init() {}

    func getCachedImage(for url: URL) -> UIImage? {
        guard let cachedImage = cache.object(forKey: url as NSURL) else {
            return nil
        }

        if Date().timeIntervalSince(cachedImage.timestamp) > expirationTime {
            cache.removeObject(forKey: url as NSURL) // Expired, remove it
            return nil
        }

        return cachedImage.image
    }

    func cacheImage(_ image: UIImage, for url: URL) {
        let cachedImage = CachedImage(image: image, timestamp: Date())
        cache.setObject(cachedImage, forKey: url as NSURL)
    }
}

// A wrapper for storing images with timestamps
class CachedImage: NSObject {
    let image: UIImage
    let timestamp: Date

    init(image: UIImage, timestamp: Date) {
        self.image = image
        self.timestamp = timestamp
    }
}

struct DownloadableImageView: View {
    let url: URL?
    @StateObject private var imageLoader = SVGImageLoader()
    @State private var isLoading = true
    @State private var asyncOperation: Task<Void, Never>?
    private let logger = Logger(subsystem: "org.openhab.app", category: "DownloadableImageView")

    var body: some View {
        Group {
            if let uiImage = imageLoader.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .id(uiImage) // Forces re-render
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemSymbol: .arrowTriangle2CirclepathCircle)
                    .font(.callout)
                    .opacity(0.3)
            }
        }
        .onAppear {
            fetchImage()
        }
        .onDisappear { cancelDownload() }
        .scaledToFit()
    }

    // Add an explicit initializer
    init(url: URL?) {
        self.url = url
    }

    private func fetchImage() {
        print("Fetching Image from \(String(describing: url))")
        guard let url else {
            print("fetchImage() skipped: URL is nil")
            isLoading = false
            return
        }

        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getCachedImage(for: url) {
            print("Loaded from cache: \(url)")
            imageLoader.updateImage(cachedImage)
            return
        }

        print("Fetching fresh image from \(url)")
        asyncOperation = Task {
            do {
                guard let client = NetworkTracker.shared.httpClient else {
                    throw DownloadableImageError.nohttpClient
                }
                let (data, _): (Data, URLResponse) = try await client.doRequest(baseURL: url, type: .data)
                try await MainActor.run {
                    let scaleFactor = WKInterfaceDevice.current().screenScale
                    let options: [SDImageCoderOption: Any] = [
                        .decodeScaleFactor: scaleFactor,
                        .decodeThumbnailPixelSize: CGSize(width: 200, height: 200)
                    ]

                    if let image = SDImageCodersManager.shared.decodedImage(with: data, options: options) {
                        logger.info("Downloaded and decoded image from \(url)")
                        ImageCacheManager.shared.cacheImage(image, for: url) // Cache it
                        imageLoader.updateImage(image)
                    } else {
                        throw DownloadableImageError.failedToDecode
                    }
                }
            } catch {
                logger.error("Image loading failed")
            }
        }
    }

    private func cancelDownload() {
        asyncOperation?.cancel()
    }
}
