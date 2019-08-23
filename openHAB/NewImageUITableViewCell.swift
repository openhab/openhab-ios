//
//  NewImageUITableViewCell.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 16.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Alamofire
import os.log
import UIKit

enum ImageType {
    case link(url: URL?)
    case embedded(image: UIImage?)
    case empty
}

class NewImageUITableViewCell: GenericUITableViewCell {

    var didLoad: (() -> Void)?

    private var mainImageView: ScaleAspectFitImageView!
    private var refreshTimer: Timer?
    private var downloadRequest: Alamofire.Request?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mainImageView = ScaleAspectFitImageView()

        contentView.addSubview(mainImageView)

        let positionGuide = contentView //contentView.layoutMarginsGuide if more margin would be appreciated

        mainImageView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout

        NSLayoutConstraint.activate([
            mainImageView.leftAnchor.constraint(equalTo: positionGuide.leftAnchor),
            mainImageView.rightAnchor.constraint(equalTo: positionGuide.rightAnchor),
            mainImageView.topAnchor.constraint(equalTo: positionGuide.topAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: positionGuide.bottomAnchor)
            ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil {
            refreshTimer?.invalidate()
        }
    }

    override func displayWidget() {
        if widget?.image == nil {
            loadImage()
        } else {
            mainImageView.image = widget?.image
        }
        // If widget have a refresh rate configured, i.e. different from zero, schedule an image update timer
        if widget.refresh != 0 {
            refreshTimer?.invalidate()
            refreshTimer = nil
            let refreshInterval = TimeInterval(Double(widget.refresh) / 1000)
            if refreshInterval > 0.09 {
                os_log("Sheduling image refresh every %g seconds", log: .viewCycle, type: .info, refreshInterval)
                refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: self,
                                                    selector: #selector(NewImageUITableViewCell.refreshImage(_:)), userInfo: nil, repeats: true)
            }
        }
    }

    func loadImage() {
        switch widgetPayload {
        case .embedded(let image):
            mainImageView.image = image
            didLoad?()
        case .link(let url):
            guard let url = url else { return }
            loadRemoteImage(withURL: url)
        default:
            os_log("Failed to determine widget payload.", log: .urlComposition, type: .debug)
        }
    }

    private var widgetPayload: ImageType {
        guard let widget = widget else { return .empty }

        switch widget.type {
        case "Chart":
            return .link(url: Endpoint.chart(rootUrl: appData!.openHABRootUrl, period: widget.period, type: widget.item?.type, service: widget.service, name: widget.item?.name, legend: widget.legend).url)
        case "Image":
            if let item = widget.item {
                return widgetPayload(fromItem: item)
            }
            return .link(url: URL(string: widget.url))
        default:
            return .empty
        }
    }

    private func widgetPayload(fromItem item: OpenHABItem) -> ImageType {
        switch item.type {
        case "Image":
            os_log("Image base64Encoded.", log: .urlComposition, type: .debug)
            guard let data = item.state.components(separatedBy: ",")[safe: 1], let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
                return .empty
            }
            return .embedded(image: UIImage(data: decodedData))
        case "String":
            return .link(url: URL(string: item.state))
        default:
            return .empty
        }
    }

    private var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    private func loadRemoteImage(withURL url: URL) {
        os_log("Image URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, url.absoluteString)

        var imageRequest = URLRequest(url: url)
        imageRequest.timeoutInterval = 10.0

        if downloadRequest != nil {
            downloadRequest?.cancel()
            downloadRequest = nil
        }

        downloadRequest = NetworkConnection.shared.manager.request(imageRequest)
            .validate(statusCode: 200..<300)
            .responseData { (response) in

                switch response.result {
                case .success:
                    if let data = response.data {
                        self.mainImageView?.image = UIImage(data: data)
                        self.widget?.image = UIImage(data: data)
                        self.didLoad?()
                    }
                case .failure(let error):
                    os_log("Download failed: %{PUBLIC}@", log: .urlComposition, type: .debug, error.localizedDescription)
                }
        }
        downloadRequest?.resume()
    }

    @objc func refreshImage(_ timer: Timer?) {
        os_log("Refreshing image on %g seconds schedule", log: .viewCycle, type: .info, Double(widget.refresh) / 1000)
        loadImage()
    }
}

extension NewImageUITableViewCell: GenericCellCacheProtocol {
    func invalidateCache() {
        refreshTimer?.invalidate()
    }
}
