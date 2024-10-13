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

import OpenHABCore
import os.log
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: UserData
    @EnvironmentObject var settings: ObservableOpenHABDataObject
    @State var title = "openHAB"

    var body: some View {
        ZStack {
            ScrollView {
                HStack {
                    Text(viewModel.openHABSitemapPage?.title ?? "Sitemap without title")
                        .font(.body)
                        .lineLimit(1)
                    Spacer()
                }
                ForEach(viewModel.widgets) { widget in
                    rowWidget(widget: widget)
                }
            }
            .navigationBarTitle(Text(title))
            .actionSheet(isPresented: $viewModel.showCertificateAlert) {
                ActionSheet(
                    title: Text(NSLocalizedString("warning", comment: "")),
                    message: Text(viewModel.certificateErrorDescription),
                    buttons: [
                        .default(Text(NSLocalizedString("abort", comment: ""))) {
                            NetworkConnection.shared.serverCertificateManager.evaluateResult = .deny
                        },
                        .default(Text(NSLocalizedString("once", comment: ""))) {
                            NetworkConnection.shared.serverCertificateManager.evaluateResult = .permitOnce
                        },
                        .default(Text(NSLocalizedString("always", comment: ""))) {
                            NetworkConnection.shared.serverCertificateManager.evaluateResult = .permitAlways
                        }
                    ]
                )
            }
            if viewModel.showAlert {
                Text("Refreshing...")
                    .onAppear {
                        DispatchQueue.main.async {
                            viewModel.refreshUrl()
                            os_log("reload after alert", log: .default, type: .info)
                        }
                        viewModel.showAlert = false
                    }
            }
        }
    }

    // https://www.swiftbysundell.com/tips/adding-swiftui-viewbuilder-to-functions/
    @ViewBuilder func rowWidget(widget: ObservableOpenHABWidget) -> some View {
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
    Group {
        ContentView(viewModel: UserData())

            .environmentObject({ () -> UserData in
                let envObj = UserData()
                return envObj
            }())

        ContentView(viewModel: UserData())
    }
    .environmentObject(ObservableOpenHABDataObject())
}
