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
import SwiftUI

/// A wrapper view that handles linkedPage navigation for widgets
struct WidgetRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings

    private var refreshToken: String {
        let displayState = widget.displayState
        return "\(widget.widgetId)|\(displayState.effectiveState)|\(displayState.labelValue ?? "")"
    }

    var body: some View {
        if let linkedPage = widget.linkedPage {
            NavigationLink(value: linkedPage) {
                WidgetRowFactory.make(widget: widget, settings: settings)
                    .id(refreshToken)
            }
            .buttonStyle(.plain)
        } else {
            WidgetRowFactory.make(widget: widget, settings: settings)
                .id(refreshToken)
        }
    }
}

/// Owns the model of a linked page. Created inline in `navigationDestination`, the model was
/// replaced, and its long poll restarted, each time SwiftUI evaluated the destination again.
private struct LinkedSitemapPageView: View {
    @StateObject private var viewModel: UserData

    var body: some View {
        SitemapPageView(viewModel: viewModel, isRoot: false)
    }

    init(linkedPage: OpenHABPage) {
        _viewModel = StateObject(wrappedValue: UserData(linkedPage: linkedPage))
    }
}

struct SitemapPageView: View {
    @ObservedObject var viewModel: UserData
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State var title = "Sitemap"
    @State private var isVisible = false
    @State private var scrollPosition: String?
    var isRoot = true

    var body: some View {
        if isRoot {
            NavigationStack {
                followedPageContent
                    .navigationDestination(for: OpenHABPage.self) { linkedPage in
                        LinkedSitemapPageView(linkedPage: linkedPage)
                            .environmentObject(settings)
                    }
            }
        } else {
            followedPageContent
        }
    }

    /// Follows the server only while this page is on screen and the app is in the foreground.
    private var followedPageContent: some View {
        pageContent
            .onAppear {
                isVisible = true
                viewModel.resumePageHandling()
            }
            .onDisappear {
                isVisible = false
                viewModel.pausePageHandling()
            }
            .onChange(of: scenePhase) { _, phase in
                guard isVisible else { return }
                switch phase {
                case .background:
                    viewModel.pausePageHandling()
                case .active:
                    viewModel.resumePageHandling()
                default:
                    break
                }
            }
    }

    private var pageContent: some View {
        Group {
            if viewModel.isLoadingSitemap, viewModel.widgets.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading sitemap…")
                        .progressViewStyle(CircularProgressViewStyle())
                        .watchTextStyle(.detail)
                    Spacer()
                }
            } else if !viewModel.widgets.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.visibleWidgets) { widget in
                            WidgetRowView(widget: widget)
                                .id(widget.widgetId)
                        }

                        if viewModel.isLoadingSitemap {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                    .scaleEffect(0.7)
                                Text("Updating…")
                                    .watchTextStyle(.secondary)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .navigationBarTitle(viewModel.pageTitle?.labelValueTitle ?? "Sitemap")
            } else {
                VStack {
                    Spacer()
                    Text("No widgets available.")
                        .watchTextStyle(.detail)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .alert(isPresented: $viewModel.showCertificateAlert) {
            Alert(
                title: Text(String(localized: "ssl_certificate_warning", comment: "")),
                message: Text(viewModel.certificateErrorDescription),
                primaryButton: .default(Text(String(localized: "Always", comment: ""))) {
                    if let delegate = viewModel.currentClientDelegate {
                        delegate.completeEvaluation(.permitAlways)
                    }
                },
                secondaryButton: .destructive(Text(String(localized: "Deny", comment: ""))) {
                    if let delegate = viewModel.currentClientDelegate {
                        delegate.completeEvaluation(.deny)
                    }
                }
            )
        }
        .refreshable {
            await viewModel.refreshUrl(force: true)
        }
    }

    init(viewModel: UserData, isRoot: Bool = true) {
        self.viewModel = viewModel
        self.isRoot = isRoot
    }
}

#Preview {
    let userData = UserData()
    let appSettings = AppSettings()

    return Group {
        SitemapPageView(viewModel: userData)
            .environmentObject(userData)

        SitemapPageView(viewModel: userData)
    }
    .environmentObject(appSettings)
}
