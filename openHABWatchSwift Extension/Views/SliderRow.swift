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

import Kingfisher
import OpenHABCoreWatch
import os.log
import SwiftUI

// swiftlint:disable file_types_order
struct SliderRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var iconUrl: URL? {
        Endpoint.icon(rootUrl: settings.openHABRootUrl,
                      version: 2,
                      icon: widget.icon,
                      value: widget.item?.state ?? "",
                      iconType: .png).url
    }

    var body: some View {

        func adj(_ raw: Double) -> Double {
            var valueAdjustedToStep = floor((raw - widget.minValue) / widget.step) * widget.step
            valueAdjustedToStep += widget.minValue
            return min(max(valueAdjustedToStep, widget.minValue), widget.maxValue)
        }

        func valueText(_ widgetValue: Double) -> String {
            let digits = max(-Decimal(widget.step).exponent, 0)
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = digits
            numberFormatter.decimalSeparator = "."
            return numberFormatter.string(from: NSNumber(value: widgetValue)) ?? ""
        }

        let valueBinding = Binding<Double>(
            get: {
                if let item = self.widget.item {
                    return adj(item.stateAsDouble())
                } else {
                    return self.widget.minValue
                }
            },
            set: {
                os_log("Slider new value = %g", log: .default, type: .info, $0)
                self.widget.sendCommand(valueText($0))
                self.widget.stateDouble = $0
            }
        )

        return
            VStack {
            HStack {
                KFImage(iconUrl)
                    .onSuccess { retrieveImageResult in
                        os_log("Success loading icon: %{PUBLIC}s", log: .notifications, type: .debug, "\(retrieveImageResult)")
                    }
                    .onFailure { kingfisherError in
                        os_log("Failure loading icon: %{PUBLIC}s", log: .notifications, type: .debug, kingfisherError.localizedDescription)
                    }
                    .placeholder {
                        Image(systemName: "arrow.2.circlepath.circle")
                            .font(.callout)
                            .opacity(0.3)
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20.0, height: 20.0)
                VStack {
                    Text(widget.labelText ?? "")
                        .font(.caption)
                        .lineLimit(2)
                    widget.labelValue.map {
                        Text($0)
                            .font(.footnote)
                            .lineLimit(1)
                    }
                }
            }
            Slider(value: valueBinding, in: widget.minValue...widget.maxValue, step: widget.step)
            }
    }
}

struct SliderRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[3]
        return SliderRow(widget: widget)
            .previewLayout(.fixed(width: 300, height: 70))
//            .environmentObject(ObservableOpenHABDataObject(openHABRootUrl: PreviewConstants.remoteURLString))
    }
}
