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
internal import SFSafeSymbols
import SwiftUI

// MARK: - Shared Icon Overlay

struct OpenHABIconOverlay: View {
    let size: CGFloat
    var leadingPadding: CGFloat = 14
    var topPadding: CGFloat = 14

    var body: some View {
        Image("openHABIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(0.5)
            .padding(.leading, leadingPadding)
            .padding(.top, topPadding)
    }
}

// MARK: - Item Type Icons

/// Returns an SF Symbol icon for the given openHAB item type
func itemTypeIcon(for type: OpenHABItem.ItemType?) -> SFSymbol {
    guard let type else { return .circleFill }
    switch type {
    case .switchItem: return .power
    case .color: return .paintpalette
    case .dimmer: return .lightMax
    case .number: return .number
    case .stringItem: return .textformat
    case .contact: return .doorLeftHandOpen
    case .rollershutter: return .blindsVerticalClosed
    default: return .circleFill
    }
}
