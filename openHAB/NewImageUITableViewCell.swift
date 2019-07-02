//
//  NewImageUITableViewCell.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 16.02.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

//import Kingfisher
import os.log
import SDWebImage
import UIKit

protocol NewImageUITableViewCellDelegate: class {
    func didLoadImageOf(_ cell: NewImageUITableViewCell?)
}

class NewImageUITableViewCell: GenericUITableViewCell {

    var mainImageView: ScaleAspectFitImageView!
    weak var delegate: NewImageUITableViewCellDelegate?
    private var refreshTimer: Timer?

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
        case let image as UIImage:
            mainImageView.image = image
            delegate?.didLoadImageOf(self)
        case let url as URL:
            loadRemoteImage(withURL: url)
        default:
            os_log("Failed to determine widget payload.", log: .urlComposition, type: .debug)
        }
    }

    private var widgetPayload: Any? {
        guard let widget = widget else { return  nil }

        switch widget.type {
        case "Chart":
            return Endpoint.chart(rootUrl: appData!.openHABRootUrl, period: widget.period, type: widget.item?.type, service: widget.service, name: widget.item?.name, legend: widget.legend).url
        case "Image":
            if let item = widget.item {
                return widgetPayload(fromItem: item)
            }
            return URL(string: widget.url)
        default:
            return nil
        }
    }

    private func widgetPayload(fromItem item: OpenHABItem) -> Any? {
        switch item.type {
        case "Image":
            os_log("Image base64Encoded.", log: .urlComposition, type: .debug)
            guard let data = item.state.components(separatedBy: ",")[safe: 1], let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
                return nil
            }
            return UIImage(data: decodedData)
        case "String":
            return URL(string: item.state)
        default:
            return nil
        }
    }

    private var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    // https://github.com/SDWebImage/SDWebImage/wiki/Common-Problems#handle-self-capture-in-completion-block
    private func loadRemoteImage(withURL url: URL) {
        os_log("Image URL: %{PUBLIC}@", log: OSLog.urlComposition, type: .debug, url.absoluteString)
        mainImageView?.sd_setImage(with: url, placeholderImage: widget?.image ?? UIImage(named: "blankicon.png"), options: .imageOptionFromLoaderOnlyIgnoreInvalidCert) { [weak self] (image, error, cacheType, imageURL) in
            if let error = error {
                os_log("Download failed: %{PUBLIC}@", log: .urlComposition, type: .debug, error.localizedDescription)
                return
            }
            self?.widget?.image = image
            self?.delegate?.didLoadImageOf(self)
        }
    }

    @objc func refreshImage(_ timer: Timer?) {
        os_log("Refreshing image on %g seconds schedule", log: .viewCycle, type: .info, Double(widget.refresh) / 1000)
        loadImage()
    }
}
