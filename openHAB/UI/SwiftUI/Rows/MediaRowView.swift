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

struct MediaRowView: View {
    let input: MediaRowInput

    private var genericFallbackInput: GenericRowInput {
        GenericRowInput(
            widgetId: input.widgetId,
            displayState: input.displayState,
            labelColor: input.labelColor,
            valueColor: input.valueColor,
            icon: RowIconInput(icon: "", iconColor: "", staticIcon: false, iconState: nil, showIcon: false)
        )
    }

    var body: some View {
        let content = mediaContent
        if let link = input.linkedPageLink {
            NavigationLink(value: LinkedPageNavigation(pageLink: link, pageTitle: input.linkedPageTitle ?? "")) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        switch input.renderingKind {
        case .image, .chart:
            ImageRowView(input: input)
        case .video:
            VideoRowView(input: input)
        case .webview:
            WidgetWebViewContainerView(input: input)
        case .mapview:
            MapRowView(input: input)
        default:
            GenericRowView(input: genericFallbackInput)
        }
    }
}
