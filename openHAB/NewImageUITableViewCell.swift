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

import Combine
import OpenHABCore
import os.log
import UIKit

class NewImageUITableViewCell: GenericUITableViewCell, NoIconDisplayableCell {
    var didLoad: (() -> Void)?

    private var mainImageView: ScaleAspectFitImageView!
    private var refreshTimer: Timer?
    private var chartStyle: ChartStyle = .light
    private var activeTask: Task<Void, Never>?
    private var cachedImage: UIImage?
    private var cachedWidgetId: String?

    var openHABRootUrl: String?

    private var shouldCache: Bool {
        widget?.refresh == 0
    }

    private var widgetPayload: ImageType {
        guard let widget else { return .empty }

        switch widget.type {
        case .chart:
            guard let openHABRootUrl else {
                Logger.widgets.error("Missing openHABRootUrl in NewImageUITableViewCell")
                return .empty
            }
            return .link(url: Endpoint.chart(
                rootUrl: openHABRootUrl,
                period: widget.period,
                type: widget.item?.type,
                service: widget.service,
                name: widget.item?.name,
                legend: widget.legend,
                theme: chartStyle,
                forceAsItem: widget.forceAsItem,
                yAxisDecimalPattern: widget.yAxisDecimalPattern
            ).url)
        case .image:
            if let item = widget.item {
                return widgetPayload(fromItem: item)
            }
            return .link(url: URL(string: widget.url))
        default:
            return .empty
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mainImageView = ScaleAspectFitImageView()

        contentView.addSubview(mainImageView)

        let positionGuide = contentView // contentView.layoutMarginsGuide if more margin would be appreciated

        mainImageView.translatesAutoresizingMaskIntoConstraints = false // enable autolayout

        NSLayoutConstraint.activate([
            mainImageView.leftAnchor.constraint(equalTo: positionGuide.leftAnchor),
            mainImageView.rightAnchor.constraint(equalTo: positionGuide.rightAnchor),
            mainImageView.topAnchor.constraint(equalTo: positionGuide.topAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: positionGuide.bottomAnchor)
        ])

        chartStyle = OHInterfaceStyle.current == .light ? ChartStyle.light : ChartStyle.dark
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview == nil {
            refreshTimer?.invalidate()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Cancel any active image loading task
        activeTask?.cancel()
        activeTask = nil

        // Invalidate and clear timer
        refreshTimer?.invalidate()
        refreshTimer = nil

        // Clear cached image and widget ID to prevent showing wrong content in reused cells
        cachedImage = nil
        cachedWidgetId = nil
        mainImageView?.image = nil

        // Reset chart style
        chartStyle = OHInterfaceStyle.current == .light ? ChartStyle.light : ChartStyle.dark
    }

    override func displayWidget() {
        // Check if we can reuse the cached image for the same widget
        let currentWidgetId = widget?.id
        let canReuseCache = cachedImage != nil && cachedWidgetId == currentWidgetId

        if canReuseCache {
            mainImageView.image = cachedImage
        } else {
            // Different widget, clear cache and load new image
            cachedImage = nil
            cachedWidgetId = currentWidgetId
            loadImage()
        }
        // If widget have a refresh rate configured, i.e. different from zero, schedule an image update timer
        if widget.refresh != 0 {
            refreshTimer?.invalidate()
            refreshTimer = nil
            let refreshInterval = TimeInterval(Double(widget.refresh) / 1000)
            if refreshInterval > 0.09 {
                Logger.widgets.info("Scheduling image refresh every \(refreshInterval) seconds")
                refreshTimer = Timer.scheduledTimer(
                    timeInterval: refreshInterval,
                    target: self,
                    selector: #selector(NewImageUITableViewCell.refreshImage(_:)),
                    userInfo: nil,
                    repeats: true
                )
            }
        }
    }

    func loadImage() {
        switch widgetPayload {
        case let .embedded(image):
            cachedImage = image
            cachedWidgetId = widget?.id
            mainImageView.image = image
            didLoad?()
        case let .link(url):
            guard let url else { return }
            loadRemoteImage(withURL: url)
        default:
            Logger.widgets.debug("Failed to determine widget payload.")
        }
    }

    private func widgetPayload(fromItem item: OpenHABItem) -> ImageType {
        switch item.type {
        case .image:
            Logger.widgets.debug("Image base64Encoded.")
            guard let data = item.state?.components(separatedBy: ",")[safe: 1], let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
                return .empty
            }
            return .embedded(image: UIImage(data: decodedData))
        case .stringItem:
            return .link(url: URL(string: item.state ?? ""))
        default:
            return .empty
        }
    }

    private func loadRemoteImage(withURL url: URL) {
        Logger.widgets.debug("Image URL: \(url.absoluteString)")

        if activeTask != nil {
            activeTask?.cancel()
            activeTask = nil
        }

        activeTask = Task {
            do {
                guard let config = await NetworkTracker.shared.activeConnection?.configuration else {
                    Logger.widgets.warning("No openHAB connection found.")
                    throw HTTPClientError.noConfiguration
                }
                let client = HTTPClient(configuration: config)
                let (data, _): (Data, URLResponse) = try await client.doRequest(baseURL: url, timeout: 10.0, type: .data, cacheingPolicy: !shouldCache ? .reloadIgnoringCacheData : .useProtocolCachePolicy)
                await MainActor.run {
                    self.cachedImage = UIImage(data: data)
                    self.cachedWidgetId = self.widget?.id
                    self.mainImageView?.image = self.cachedImage
                    self.didLoad?()
                }
            } catch {
                Logger.widgets.info("Downloading image failed: \(error.localizedDescription)")
            }
        }
    }

    @objc
    func refreshImage(_ timer: Timer?) {
        // swiftformat:disable:next redundantSelf
        Logger.widgets.info("Refreshing image on \(Double(self.widget.refresh) / 1000) seconds schedule")
        loadImage()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        chartStyle = OHInterfaceStyle.current == .light ? ChartStyle.light : ChartStyle.dark
        if widget.type == .chart {
            loadImage()
        }
    }
}

extension NewImageUITableViewCell: GenericCellCacheProtocol {
    func invalidateCache() {
        refreshTimer?.invalidate()
        cachedImage = nil
        cachedWidgetId = nil
    }
}
