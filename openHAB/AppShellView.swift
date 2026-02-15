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
import SwiftUI
import UIKit

struct OpenHABRootContainerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> OpenHABNavigationController {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let rootViewController = storyboard.instantiateViewController(withIdentifier: "OpenHABRootViewController") as! OpenHABRootViewController
        let navigationController = OpenHABNavigationController(rootViewController: rootViewController)
        AppShellCoordinator.shared.attach(rootViewController: rootViewController)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: OpenHABNavigationController, context: Context) {}
}

final class AppShellHostingController: UIHostingController<AppShellView> {
    override var childForStatusBarHidden: UIViewController? { nil }

    override var prefersStatusBarHidden: Bool {
        Preferences.shared.hideStatusBar
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
}

struct AppShellView: View {
    @StateObject private var coordinator = AppShellCoordinator.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView(columnVisibility: $coordinator.splitViewVisibility) {
                sidebar
                    .navigationTitle(LocalizedStringKey("menu"))
            } detail: {
                OpenHABRootContainerView()
                    .ignoresSafeArea()
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            OpenHABRootContainerView()
                .ignoresSafeArea()
                .sheet(isPresented: $coordinator.isCompactMenuPresented) {
                    NavigationStack {
                        sidebar
                            .navigationTitle(LocalizedStringKey("menu"))
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(LocalizedStringKey("close")) {
                                        coordinator.dismissCompactMenu()
                                    }
                                }
                            }
                    }
                }
        }
    }

    private var sidebar: some View {
        DrawerView { target in
            coordinator.selectMenu(target: target)
        }
        .environmentObject(MainActorNetworkTracker.shared)
        .environmentObject(CurrentViewState.shared)
    }
}
