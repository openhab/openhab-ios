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
import SwiftUI
import UIKit

@MainActor
final class AppShellCoordinator: ObservableObject {
    static let shared = AppShellCoordinator()

    @Published var isCompactMenuPresented = false
    @Published var splitViewVisibility: NavigationSplitViewVisibility = .all

    weak var rootViewController: OpenHABRootViewController?

    func attach(rootViewController: OpenHABRootViewController) {
        self.rootViewController = rootViewController
        rootViewController.onMenuRequested = { [weak self] in
            self?.requestMenu()
        }
    }

    func requestMenu() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitViewVisibility = .all
        } else {
            isCompactMenuPresented = true
        }
    }

    func dismissCompactMenu() {
        isCompactMenuPresented = false
    }

    func selectMenu(target: TargetController) {
        resolveRootViewControllerIfNeeded()?.navigateFromMenu(to: target)
        dismissCompactMenu()
    }

    func handleNotification(action: String?, cloudUserId: String?) {
        resolveRootViewControllerIfNeeded()?.handleNotification(action: action, cloudUserId: cloudUserId)
    }

    private func resolveRootViewControllerIfNeeded() -> OpenHABRootViewController? {
        if let rootViewController {
            return rootViewController
        }
        guard let keyWindowRoot = UIApplication.shared.firstKeyWindow?.rootViewController else {
            return nil
        }
        let discoveredRootViewController = findRootViewController(in: keyWindowRoot)
        rootViewController = discoveredRootViewController
        return discoveredRootViewController
    }

    private func findRootViewController(in viewController: UIViewController) -> OpenHABRootViewController? {
        if let rootViewController = viewController as? OpenHABRootViewController {
            return rootViewController
        }
        for childViewController in viewController.children {
            if let rootViewController = findRootViewController(in: childViewController) {
                return rootViewController
            }
        }
        if let navigationController = viewController as? UINavigationController {
            for childViewController in navigationController.viewControllers {
                if let rootViewController = findRootViewController(in: childViewController) {
                    return rootViewController
                }
            }
        }
        if let presentedViewController = viewController.presentedViewController {
            return findRootViewController(in: presentedViewController)
        }
        return nil
    }
}
