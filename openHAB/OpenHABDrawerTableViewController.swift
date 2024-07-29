// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import OpenHABCore
import os.log
import SafariServices
import UIKit

func deriveSitemaps(_ response: Data?) -> [OpenHABSitemap] {
    var sitemaps = [OpenHABSitemap]()

    if let response {
        do {
            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
            let sitemapsCodingData = try response.decoded(as: [OpenHABSitemap.CodingData].self)
            for sitemapCodingDatum in sitemapsCodingData {
                os_log("Sitemap %{PUBLIC}@", log: .remoteAccess, type: .info, sitemapCodingDatum.label)
                sitemaps.append(sitemapCodingDatum.openHABSitemap)
            }
        } catch {
            os_log("Should not throw %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
        }
    }

    return sitemaps
}

struct UiTile: Decodable, Hashable {
    var name: String
    var url: String
    var imageUrl: String
}

class OpenHABDrawerTableViewController: UITableViewController {
    static let tableViewCellIdentifier = "DrawerCell"

    var sitemaps: [OpenHABSitemap] = []
    var uiTiles: [OpenHABUiTile] = []
    var drawerItems: [OpenHABDrawerItem] = []
    var openHABUsername = ""
    var openHABPassword = ""
    weak var delegate: ModalHandler?

    // App wide data access
    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    var dataSource: DataSource!

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        loadSettings()
        configureDataSource()
        getData()
        os_log("OpenHABDrawerTableViewController did load", log: .viewCycle, type: .info)
    }

    func updateUI(animatingDifferences: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems([Item.main], toSection: .main)
        snapshot.appendSections([.tiles])
        snapshot.appendItems(uiTiles.map { Item.tiles($0) }, toSection: .tiles)
        snapshot.appendSections([.sitemaps])
        snapshot.appendItems(sitemaps.map { Item.sitemaps($0) }, toSection: .sitemaps)
        snapshot.appendSections([.system])
        snapshot.appendItems(getStandardDrawerItems().map { Item.system($0) }, toSection: .system)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    func getData() {
        NetworkConnection.sitemaps(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case let .success(data):
                os_log("Sitemap response", log: .viewCycle, type: .info)

                self.sitemaps = deriveSitemaps(data)

                if self.sitemaps.last?.name == "_default", self.sitemaps.count > 1 {
                    self.sitemaps = Array(self.sitemaps.dropLast())
                }

                // Sort the sitemaps according to Settings selection.
                switch SortSitemapsOrder(rawValue: Preferences.sortSitemapsby) ?? .label {
                case .label: self.sitemaps.sort { $0.label < $1.label }
                case .name: self.sitemaps.sort { $0.name < $1.name }
                }
                self.updateUI()
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }

        NetworkConnection.uiTiles(openHABRootUrl: appData?.openHABRootUrl ?? "") { response in
            switch response.result {
            case .success:
                os_log("ui tiles response", log: .viewCycle, type: .info)
                guard let responseData = response.data else {
                    os_log("Error: did not receive data", log: OSLog.remoteAccess, type: .info)
                    return
                }
                do {
                    self.uiTiles = try JSONDecoder().decode([OpenHABUiTile].self, from: responseData)
                    self.updateUI()
                } catch {
                    os_log("Error: did not receive data %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, error.localizedDescription)
                }
            case let .failure(error):
                os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
}

extension OpenHABDrawerTableViewController {
    typealias SectionType = Section

    enum Section: Int, CaseIterable, CustomStringConvertible {
        var description: String {
            switch self {
            case .main: "Main"
            case .tiles: "Tiles"
            case .sitemaps: "Sitemaps"
            case .system: "System"
            }
        }

        case main = 0
        case tiles
        case sitemaps
        case system
    }

    enum Item: Hashable {
        case main
        case tiles(OpenHABUiTile)
        case sitemaps(OpenHABSitemap)
        case system(OpenHABDrawerItem)
    }

    class DataSource: UITableViewDiffableDataSource<Section, Item> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            let sectionKind = Section(rawValue: section)
            return sectionKind?.description
        }
    }

    func cell(tableView: UITableView, indexPath: IndexPath, item: Item) -> UITableViewCell? {
        let cell = (tableView.dequeueReusableCell(withIdentifier: OpenHABDrawerTableViewController.tableViewCellIdentifier) as? DrawerUITableViewCell)!
        cell.customImageView.subviews.forEach { $0.removeFromSuperview() }
        cell.accessoryView = nil
        switch item {
        case .main:
            cell.customTextLabel?.text = "Home"
            cell.customImageView.image = UIImage(named: "openHABIcon")
            if let currentView = appData?.currentView {
                // if we already are on the webview, pressing this again will force a refresh
                if currentView == .webview {
                    cell.accessoryView = UIImageView(image: UIImage(named: "arrow.triangle.2.circlepath"))
                }
            }
        case let .tiles(tile):
            cell.customTextLabel?.text = tile.name
            let imageView = UIImageView(frame: cell.customImageView.bounds)
            let passedURL = tile.imageUrl
            // Dependent on $OPENHAB_CONF/services/runtime.cfg
            // Can either be an absolute URL, a path (sometimes malformed) or the content to be displayed (for imageURL)
            if !passedURL.isEmpty {
                switch passedURL {
                case _ where passedURL.hasPrefix("data:image"):
                    if let imageData = Data(base64Encoded: passedURL.deletingPrefix("data:image/png;base64,"), options: .ignoreUnknownCharacters) {
                        imageView.image = UIImage(data: imageData)
                    } // data;image/png;base64,
                case _ where passedURL.hasPrefix("http"):
                    os_log("Loading %{PUBLIC}@", log: .default, type: .info, String(describing: passedURL))
                    imageView.kf.setImage(with: URL(string: passedURL), placeholder: UIImage(named: "openHABIcon"))
                default:
                    if let builtURL = Endpoint.resource(openHABRootUrl: appData?.openHABRootUrl ?? "", path: passedURL.prepare()).url {
                        os_log("Loading %{PUBLIC}@", log: .default, type: .info, String(describing: builtURL))
                        imageView.kf.setImage(with: builtURL, placeholder: UIImage(named: "openHABIcon"))
                    }
                }
            } else {
                imageView.image = UIImage(named: "openHABIcon")
            }
            cell.customImageView.image = imageView.image
        case let .sitemaps(sitemap):
            let imageView = UIImageView(frame: cell.customImageView.bounds)
            cell.customTextLabel?.text = sitemap.label
            if !sitemap.icon.isEmpty {
                if let iconURL = Endpoint.iconForDrawer(rootUrl: appData?.openHABRootUrl ?? "", icon: sitemap.icon).url {
                    imageView.kf.setImage(with: iconURL, placeholder: UIImage(named: "openHABIcon"))
                }
            } else {
                imageView.image = UIImage(named: "openHABIcon")
            }
            cell.customImageView.image = imageView.image
        case let .system(drawerItem):
            cell.customTextLabel?.text = drawerItem.localizedString

            if #available(iOS 13, *) {
                switch drawerItem {
                case .notifications:
                    cell.customImageView.image = UIImage(systemName: "bell")
                case .settings:
                    cell.customImageView.image = UIImage(systemName: "gear")
                }
            } else {
                let buttonIcon = DynamicButton(frame: cell.customImageView.bounds)
                buttonIcon.bounceButtonOnTouch = false

                buttonIcon.strokeColor = .black
                buttonIcon.lineWidth = 1

                switch drawerItem {
                case .notifications:
                    buttonIcon.style = .custom(DynamicButtonStyleBell.self)
                case .settings:
                    buttonIcon.style = .custom(DynamicButtonStyleGear.self)
                }
                cell.customImageView.addSubview(buttonIcon)
            }
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 0)

        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = .zero

        return cell
    }

    func configureDataSource() {
        dataSource = DataSource(tableView: tableView) { [unowned self] (tableView, indexPath, item) -> UITableViewCell? in
            cell(tableView: tableView, indexPath: indexPath, item: item)
        }
    }
}

extension OpenHABDrawerTableViewController {
    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // open a alert with an OK and cancel button
        os_log("Clicked on drawer section %d row %d", log: .viewCycle, type: .info, indexPath.section, indexPath.row)

        tableView.deselectRow(at: indexPath, animated: false)

        guard let menuItem = dataSource.itemIdentifier(for: indexPath) else { return }

        switch menuItem {
        case .main:
            dismiss(animated: true) {
                self.delegate?.modalDismissed(to: .webview)
            }
        case let .tiles(tile):
            let passedURL = tile.url
            // Dependent on $OPENHAB_CONF/services/runtime.cfg
            // Can either be an absolute URL, a path (sometimes malformed)
            if !passedURL.isEmpty {
                switch passedURL {
                case _ where passedURL.hasPrefix("http"):
                    openURL(url: URL(string: passedURL))
                default:
                    let builtURL = Endpoint.resource(openHABRootUrl: appData?.openHABRootUrl ?? "", path: passedURL.prepare())
                    openURL(url: builtURL.url)
                }
            }
        case let .sitemaps(sitemap):
            Preferences.defaultSitemap = sitemap.name
            appData?.sitemapViewController?.pageUrl = ""
            dismiss(animated: true) {
                os_log("self delegate %d", log: .viewCycle, type: .info, self.delegate != nil)
                self.delegate?.modalDismissed(to: .sitemap)
            }

        case let .system(drawerItem):
            switch drawerItem {
            case .settings:
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .settings)
                }
            case .notifications:
                dismiss(animated: true) {
                    self.delegate?.modalDismissed(to: .notifications)
                }
            }
        }
    }

    private func getStandardDrawerItems() -> [OpenHABDrawerItem] {
        var drawerItems: [OpenHABDrawerItem] = []
        // check if we are using my.openHAB, add notifications menu item then
        // Actually this should better test whether the host of the remoteUrl is on openhab.org
        if Preferences.remoteUrl.contains("openhab.org"), !Preferences.demomode {
            drawerItems.append(.notifications)
        }
        // Settings always go last
        drawerItems.append(.settings)
        return drawerItems
    }

    private func loadSettings() {
        openHABUsername = Preferences.username
        openHABPassword = Preferences.password
    }

    private func openURL(url: URL?) {
        if let url {
            let config = SFSafariViewController.Configuration()
            config.entersReaderIfAvailable = true
            let vc = SFSafariViewController(url: url, configuration: config)
            present(vc, animated: true)
        }
    }
}
