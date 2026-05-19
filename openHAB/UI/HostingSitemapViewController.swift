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
import os.log
import SwiftMessages
import SwiftUI
import UIKit

class HostingSitemapViewController: UIHostingController<SitemapNavigationView>, OpenHABViewable {
    private let viewModel: SitemapPageViewModel

    private weak var rootViewController: OpenHABRootViewController?

    init() {
        viewModel = SitemapPageViewModel()
        super.init(rootView: SitemapNavigationView(viewModel: viewModel) {})
    }

    init(viewModel: SitemapPageViewModel) {
        self.viewModel = viewModel
        super.init(rootView: SitemapNavigationView(viewModel: viewModel) {})
    }

    @available(*, unavailable)
    @objc dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide UIKit navigation bar since SwiftUI now handles navigation
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure UIKit navigation bar stays hidden when transitioning from other views
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    func setRootViewController(_ rootViewController: OpenHABRootViewController) {
        self.rootViewController = rootViewController
        // Update the closure after initialization
        rootView = SitemapNavigationView(viewModel: viewModel) { [weak self] in
            self?.rootViewController?.showSideMenu()
        }
    }

    func getSitemapTitle() -> String {
        viewModel.pageTitle
    }

    func viewName() -> String { "sitemap" }

    nonisolated func reloadView() {
        Task { @MainActor in
            await viewModel.reload()
        }
    }

    func pushSitemap(name: String, path: String?) async {
        guard let path, !path.isEmpty else {
            await viewModel.pushSitemap(name: name, path: nil)
            return
        }

        guard let activeConnection = await NetworkTracker.shared.waitForActiveConnection() else {
            Logger.viewController.error("pushSitemap: No active connection available")
            return
        }

        guard let baseURL = URL(string: activeConnection.configuration.url) else {
            Logger.viewController.error("pushSitemap: Invalid base URL")
            return
        }

        let pageURL = baseURL
            .appending(path: "rest")
            .appending(path: "sitemaps")
            .appending(path: name)
            .appending(path: path)

        // Load the root sitemap so the back button returns to it, then navigate to the sub-page
        // within the existing SwiftUI NavigationStack so SwiftUI manages back-navigation.
        await viewModel.pushSitemap(name: name, path: nil)
        viewModel.navigateToLinkedPage(LinkedPageNavigation(pageLink: pageURL.absoluteString, pageTitle: name))
    }

    @MainActor
    func refreshOnForegroundIfNeeded() {
        // Avoid restarting the very first page load on initial app activation.
        guard viewModel.currentPage != nil || !viewModel.isLoading else { return }
        viewModel.refreshOnForeground()
    }

    // swiftlint:disable:next  function_parameter_count
    func showPopupMessage(seconds: Double,
                          title: String,
                          message: String,
                          theme: Theme,
                          viewTapAction: (() -> Void)?,
                          buttonTitle: String,
                          buttonAction: (() -> Void)?) {}

    func hidePopupMessages() {}
}
