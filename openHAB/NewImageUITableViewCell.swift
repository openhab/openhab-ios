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

import Combine
import OpenHABCore
import os.log
import UIKit

enum ImageType {
    case link(url: URL?)
    case embedded(image: UIImage?)
    case empty
}

class NewImageUITableViewCell: GenericUITableViewCell, NoIconDisplayableCell {
    // Shared image cache across all cells - keyed by widget ID
    // Using NSCache for thread-safety and automatic memory management
    private static let sharedImageCache = NSCache<NSString, UIImage>()

    private var mainImageView: ScaleAspectFitImageView!
    private var refreshTimer: Timer?
    private var currentRefreshInterval: TimeInterval = 0
    private var chartStyle: ChartStyle = .light
    private var activeTask: Task<Void, Never>?
    private var displayedWidgetId: String? // Track which widget this cell is currently displaying

    var didLoad: (() -> Void)?

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

        // Cancel any active image loading task to prevent race conditions where a task
        // started for a previous widget updates the shared cache or UI for a newly assigned widget
        activeTask?.cancel()
        activeTask = nil

        // Reset chart style
        chartStyle = OHInterfaceStyle.current == .light ? ChartStyle.light : ChartStyle.dark
    }

    override func displayWidget() {
        let widgetId = widget?.id ?? ""
        // Set displayedWidgetId before cache check to ensure consistency
        displayedWidgetId = widgetId

        // Check shared cache for this widget's image
        if let cachedImage = Self.sharedImageCache.object(forKey: widgetId as NSString) {
            // Found in shared cache - use it immediately without reloading
            mainImageView?.image = cachedImage
        } else {
            // Not in cache - need to load
            mainImageView?.image = nil
            loadImage()
        }

        // Handle refresh timer - only update if the interval has changed
        let newRefreshInterval = widget.refresh != 0 ? TimeInterval(Double(widget.refresh) / 1000) : 0

        if newRefreshInterval != currentRefreshInterval {
            // Refresh interval changed, update the timer
            refreshTimer?.invalidate()
            refreshTimer = nil
            currentRefreshInterval = newRefreshInterval

            if newRefreshInterval > 0.09 {
                Logger.widgets.info("Scheduling image refresh every \(newRefreshInterval) seconds")
                refreshTimer = Timer.scheduledTimer(
                    timeInterval: newRefreshInterval,
                    target: self,
                    selector: #selector(NewImageUITableViewCell.refreshImage(_:)),
                    userInfo: nil,
                    repeats: true
                )
            }
        }
    }

    func loadImage() {
        let widgetId = widget?.id ?? ""
        switch widgetPayload {
        case let .embedded(image):
            if let image {

                Self.sharedImageCache.setObject(image, forKey: widgetId as NSString)
                mainImageView.image = image
                didLoad?()
            }
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
        let widgetId = widget?.id ?? ""
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
                let client = HTTPClient(connectionConfiguration: config)
                let (data, _): (Data, URLResponse) = try await client.doRequest(baseURL: url, timeout: 10.0, type: .data, cacheingPolicy: !shouldCache ? .reloadIgnoringCacheData : .useProtocolCachePolicy)
                await MainActor.run {
                    guard let image = UIImage(data: data) else { return }

                    // Store in shared cache
                    Self.sharedImageCache.setObject(image, forKey: widgetId as NSString)
                    // Only update UI if this cell is still displaying the same widget
                    if self.displayedWidgetId == widgetId {
                        Self.sharedImageCache.setObject(image, forKey: widgetId as NSString)
                        self.mainImageView?.image = image
                        self.didLoad?()
                    }
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
    /// Clears the entire shared image cache (call when sitemap changes, etc.)
    static func clearSharedCache() {
        sharedImageCache.removeAllObjects()
    }

    func invalidateCache() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        currentRefreshInterval = 0
        // Clear this widget from shared cache
        if let widgetId = displayedWidgetId {
            Self.sharedImageCache.removeObject(forKey: widgetId as NSString)
        }
        displayedWidgetId = nil
    }
}
