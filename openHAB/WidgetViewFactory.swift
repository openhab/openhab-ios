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
import SwiftUI

enum WidgetViewFactory {
    @ViewBuilder
    static func view(for widget: OpenHABWidget) -> some View {
        switch widget.type {
        case .switchWidget:
            WidgetSwitchView(widget: widget)
        case .slider:
            WidgetSliderView(widget: widget)
        case .text:
            WidgetTextView(widget: widget)
        case .frame:
            EmptyView() // ignore frames
        default:
            WidgetGenericView(widget: widget)
        }
    }
}
