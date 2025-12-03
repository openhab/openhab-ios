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
    @State private var scrollPosition: CGFloat = 0

    var body: some View {
        NavigationStack {
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
                        ForEach(viewModel.widgets) { widget in
                            rowWidget(widget: widget)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: geo.frame(in: .named("scroll")).minY
                                            )
                                    }
                                )
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
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollPosition = value
                    }
                    .sensoryFeedback(.selection, trigger: scrollPosition)
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
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoadingSitemap)
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

    // https://www.swiftbysundell.com/tips/adding-swiftui-viewbuilder-to-functions/
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
