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

import Foundation
import OpenHABCore
import os.log
import SFSafeSymbols
import SwiftUI
import UIKit

extension OpenHABWidget {
    @MainActor
    func iconRenderModel(fallbackSymbol: SFSymbol? = nil) -> IconRenderModel {
        let logicColor = !iconColor.isEmpty ? UIColor(fromString: iconColor) : .ohBlack
        let encodedIconColor = logicColor.semanticColorToHex() ?? "#FFFFFF"
        return IconRenderModel(
            icon: icon,
            iconState: iconState(),
            iconColorHex: encodedIconColor,
            staticIcon: staticIcon,
            stateToken: item?.state ?? state,
            fallbackSymbol: fallbackSymbol
        )
    }

    @ViewBuilder @MainActor func makeView(settings: AppSettings) -> some View {
        if linkedPage != nil {
            Image(systemSymbol: .chevronRight)
                .foregroundStyle(.secondary)
        }
    }
}
