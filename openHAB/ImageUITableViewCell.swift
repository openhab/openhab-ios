//
//  ImageUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 18/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import SDWebImage

@objc protocol ImageUITableViewCellDelegate: NSObjectProtocol {
    func didLoadImageOf(_ cell: ImageUITableViewCell?)
}

var refreshTimer: Timer?

class ImageUITableViewCell: GenericUITableViewCell {
    @IBOutlet weak var widgetImage: UIImageView!
    @objc weak var delegate: ImageUITableViewCellDelegate?

    @objc override var widget: OpenHABWidget! {
        get {
            return super.widget
        }
        set(widget) {
            super.widget = widget
            // Remove image from SDImage cache
        }
    }

    override func displayWidget() {
        if widget?.image == nil {
            loadImage()
        } else {
            widgetImage?.image = widget?.image
        }
        // If widget have a refresh rate configured, schedule an image update timer
        if widget.refresh != "" && refreshTimer == nil {
            let refreshInterval = TimeInterval(widget.refresh.floatValue / 1000)
            refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
                                                selector: #selector(ImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
        }
    }

    func imageURL() -> URL {
        let random = Int.random(in: 0..<1000)
        var components = URLComponents(string: widget.url)
        components?.queryItems?.append(contentsOf: [
            URLQueryItem(name: "random", value: String(random))
            ])
        return components?.url ?? URL(string: "")!
    }

    func loadImage() {
        widgetImage?.sd_setImage(with: imageURL(), placeholderImage: nil)
//        { (image, error, cacheType, imageURL) in
//            // Perform operation.
//            self.widget.image = image
//        }
    }

    @objc func refreshImage(_ timer: Timer?) {
        widgetImage?.sd_setImage(with: imageURL(), placeholderImage: widgetImage?.image)
    }

    func willMove(to newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil && refreshTimer != nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}

struct Endpoint {
    let baseURL: String
    let path: String
    let queryItems: [URLQueryItem]
}

extension Endpoint {
    // We still have to keep 'url' as an optional, since we're
    // dealing with dynamic components that could be invalid.
    var url: URL? {
        var components = URLComponents(string: baseURL)
        components?.path = path
        components?.queryItems = queryItems
        return components?.url
    }
}

//class DataLoader {
//    func request(_ endpoint: Endpoint,
//                 then handler: @escaping (Result<Data>) -> Void) {
//        guard let url = endpoint.url else {
//            return handler(.failure(Error.invalidURL))
//        }
//
//        let task = urlSession.dataTask(with: url) {
//            data, _, error in
//
//            let result = data.map(Result.success) ??
//                .failure(Error.network(error))
//
//            handler(result)
//        }
//
//        task.resume()
//    }
//}
