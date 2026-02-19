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

struct MediaRowInputView: View {
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
        switch input.renderingKind {
        case .image, .chart:
            ImageRowInputView(input: input)
        case .video:
            VideoRowInputView(input: input)
        case .webview:
            WidgetWebViewContainerInputView(input: input)
        case .mapview:
            MapRowInputView(input: input)
        default:
            GenericRowInputView(input: genericFallbackInput)
        }
    }
}
