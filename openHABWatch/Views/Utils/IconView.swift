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
import SDWebImageSwiftUI
import SwiftUI

struct IconView: View {
    @ObservedObject var widget: OpenHABWidget
    @ObservedObject var settings = AppSettings.shared

    var iconURL: URL? {
        var iconColor = widget.iconColor
        if iconColor.isEmpty {
            iconColor = "white"
        }
        return Endpoint.icon(
            rootUrl: settings.openHABRootUrl,
            version: settings.openHABVersion,
            icon: widget.icon,
            state: widget.item?.state ?? "",
            iconType: settings.iconType,
            iconColor: iconColor
        ).url
    }

    var body: some View {
        DownloadableImageView(url: iconURL)
            .transition(.fade(duration: 0.3))
            .frame(width: 20.0, height: 20.0)
            .id(iconURL?.absoluteString ?? "")
    }
}

#Preview {
    
    let item = OpenHABItem(name: "PreviewItem", type: "Preview Light", state: "Switch", link: "ON", label: nil, groupType: nil, stateDescription: nil, commandDescription: nil, members: [], category: nil, options: nil)
    let widget = OpenHABWidget(widgetId: "00",
                               label: "Lights",
                               icon: "lightbulb",
                               type: .slider,
                               url: nil,
                               period: nil,
                               minValue: nil,
                               maxValue: nil,
                               step: nil,
                               refresh: nil,
                               height: nil,
                               isLeaf: nil,
                               iconColor: nil,
                               labelColor: nil,
                               valueColor: nil,
                               service: nil,
                               state: nil,
                               text: nil,
                               legend: true,
                               inputHint: nil,
                               encoding: nil,
                               item: item,
                               linkedPage: nil,
                               mappings: [],
                               widgets: [],
                               visibility: nil,
                               switchSupport: nil,
                               forceAsItem: nil)
    
    
    let mockSettings = {
        let obj = AppSettings()
        obj.openHABRootUrl = PreviewConstants.remoteURLString
        return obj
    }()
    
    IconView(widget: widget, settings: mockSettings)
}
