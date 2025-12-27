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

import OpenHABCore
import os.log
import SwiftUI

struct SitemapPageView: View {
    @ObservedObject var viewModel: UserData
    @EnvironmentObject var settings: AppSettings
    @State var title = "Sitemap"
    @State private var scrollPosition: String?
    var isRoot: Bool = true

    init(viewModel: UserData, isRoot: Bool = true) {
        self.viewModel = viewModel
        self.isRoot = isRoot
    }

    var body: some View {
        Group {
            if isRoot {
                NavigationStack {
                    pageContent
                        .navigationDestination(for: OpenHABPage.self) { linkedPage in
                            SitemapPageView(viewModel: UserData(linkedPage: linkedPage), isRoot: false)
                                .environmentObject(settings)
                        }
                }
            } else {
                pageContent
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        Group {
            if viewModel.isLoadingSitemap, viewModel.widgets.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading sitemap...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .font(.footnote)
                    Spacer()
                }
            } else if !viewModel.widgets.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.widgets) { widget in
                            WidgetRowView(widget: widget)
                                .id(widget.widgetId)
                        }

                        if viewModel.isLoadingSitemap {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                    .scaleEffect(0.7)
                                Text("Updating...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .navigationBarTitle(viewModel.openHABSitemapPage?.title ?? "Sitemap")
            } else {
                VStack {
                    Spacer()
                    Text("No widgets available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .alert(isPresented: $viewModel.showCertificateAlert) {
            Alert(
                title: Text(NSLocalizedString("ssl_certificate_warning", comment: "")),
                message: Text(viewModel.certificateErrorDescription),
                primaryButton: .default(Text(NSLocalizedString("always", comment: ""))) {
                    if let delegate = viewModel.currentClientDelegate {
                        delegate.completeEvaluation(.permitAlways)
                    }
                },
                secondaryButton: .destructive(Text(NSLocalizedString("deny", comment: ""))) {
                    if let delegate = viewModel.currentClientDelegate {
                        delegate.completeEvaluation(.deny)
                    }
                }
            )
        }
    }
}

/// A wrapper view that handles linkedPage navigation for widgets
struct WidgetRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        if let linkedPage = widget.linkedPage {
            NavigationLink(value: linkedPage) {
                rowWidget(widget: widget)
            }
            .buttonStyle(.plain)
        } else {
            rowWidget(widget: widget)
        }
    }

    @ViewBuilder func rowWidget(widget: OpenHABWidget) -> some View {
        switch widget.stateEnum {
        case .switcher:
            SwitchRow(widget: widget)
        case .slider:
            if widget.switchSupport {
                SliderRow(widget: widget)
            } else {
                SliderWithSwitchSupportRow(widget: widget)
            }
        case .segmented:
            SegmentRow(widget: widget)
        case .rollershutter:
            RollershutterRow(widget: widget)
        case .setpoint:
            SetpointRow(widget: widget)
        case .frame:
            FrameRow(widget: widget)
        case .image:
            // Encoded image
            if widget.item != nil {
                ImageRawRow(widget: widget)
            } else {
                ImageRow(url: URL(string: widget.url))
            }
        case .chart:
            let url = Endpoint.chart(
                rootUrl: settings.openHABRootUrl,
                period: widget.period,
                type: widget.item?.type ?? .none,
                service: widget.service,
                name: widget.item?.name,
                legend: widget.legend,
                theme: .dark,
                forceAsItem: widget.forceAsItem
            ).url
            ImageRow(url: url)
        case .mapview:
            MapViewRow(widget: widget)
        case .colorpicker:
            ColorPickerRow(widget: widget)
        default:
            GenericRow(widget: widget)
        }
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
