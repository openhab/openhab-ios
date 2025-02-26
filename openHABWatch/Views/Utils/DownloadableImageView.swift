//
//  DownloadableImageView.swift
//  openHAB
//
//  Created by Daniel Cunningham on 2/23/25.
//  Copyright © 2025 openHAB e.V. All rights reserved.
//


import SwiftUI
import SDWebImage
import SDWebImageSVGCoder
import OpenHABCore
import WatchKit


struct DownloadableImageView: View {
    let url: URL?
    @StateObject private var imageLoader = SVGImageLoader()
    @State private var isLoading = true
    @State private var task: URLSessionTask?
    
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
    
    private func fetchImage() {
        print("Fetching Image from \(String(describing: url))")
        guard let url = url else {
            print("fetchImage() skipped: URL is nil")
            isLoading = false
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getCachedImage(for: url) {
            print("Loaded from cache: \(url)")
            self.imageLoader.updateImage(cachedImage)
            return
        }
        
        print("Fetching fresh image from \(url)")
        task = NetworkTracker.shared.httpClient?.doGet(baseURL: url, path: nil) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else { return }
                
                let scaleFactor = WKInterfaceDevice.current().screenScale
                let options: [SDImageCoderOption: Any] = [
                    .decodeScaleFactor: scaleFactor,
                    .decodeThumbnailPixelSize: CGSize(width: 200, height: 200)
                ]
                
                if let image = SDImageCodersManager.shared.decodedImage(with: data, options: options) {
                    print("Downloaded and decoded image from \(url)")
                    ImageCacheManager.shared.cacheImage(image, for: url) // Cache it
                    self.imageLoader.updateImage(image)
                } else {
                    print("Image decoding failed")
                }
            }
        }
    }
    
    private func cancelDownload() {
        task?.cancel()
        task = nil
    }
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
