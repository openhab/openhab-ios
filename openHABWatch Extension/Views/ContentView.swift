// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import OpenHABCoreWatch
import os.log
import SwiftUI

// swiftlint:disable file_types_order
struct ContentView: View {
    @ObservedObject var viewModel: UserData
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        ScrollView {
            ForEach(viewModel.widgets) { widget in
                self.rowWidget(widget: widget)
                    .environmentObject(self.settings)
            }
        }
        .navigationBarTitle(Text("openHAB"))
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Error"),
                  message: Text(viewModel.errorDescription),
                  dismissButton: .default(Text("Retry in 30s")) {
                      DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                          self.viewModel.loadPage(urlString: self.settings.openHABRootUrl,
                                                  longPolling: false,
                                                  refresh: true)
                          os_log("reload after alert", log: .default, type: .info)
                      }
                  })
        }
    }

    func rowWidget(widget: ObservableOpenHABWidget) -> AnyView? {
        switch widget.stateEnum {
        case .switcher:
            return AnyView(SwitchRow(widget: widget))
        case .slider:
            return AnyView(SliderRow(widget: widget))
        case .segmented:
            return AnyView(SegmentRow(widget: widget))
        case .rollershutter:
            return AnyView(RollershutterRow(widget: widget))
        case .setpoint:
            return AnyView(SetpointRow(widget: widget))
        case .frame:
            return AnyView(FrameRow(widget: widget))
        case .image:
            if widget.item != nil {
                return AnyView(ImageRawRow(widget: widget))
            }
            return AnyView(ImageRow(widget: widget, url: URL(string: widget.url)))
        case .chart:
            let url = Endpoint.chart(rootUrl: settings.openHABRootUrl, period: widget.period, type: widget.item?.type, service: widget.service, name: widget.item?.name, legend: widget.legend, theme: .dark).url
            return AnyView(ImageRow(widget: widget, url: url))
        case .mapview:
            return AnyView(MapViewRow(widget: widget))
        case .colorpicker:
            return AnyView(ColorPickerRow(widget: widget))
        default:
            return AnyView(GenericRow(widget: widget))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(viewModel: UserData())
                .previewDevice("Apple Watch Series 4 - 44mm")
            ContentView(viewModel: UserData(urlString: PreviewConstants.remoteURLString))
                .previewDevice("Apple Watch Series 2 - 38mm")
        }
    }
}
