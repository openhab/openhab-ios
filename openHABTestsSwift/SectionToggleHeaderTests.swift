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

@testable import openHAB
import SwiftUI
import Testing
import UIKit

@MainActor
struct SectionToggleHeaderTests {
    private func height(expanded: Bool, size: DynamicTypeSize) -> CGFloat {
        let header = SectionToggleHeader(title: "Sitemaps", isExpanded: .constant(expanded))
            .dynamicTypeSize(size)
        return UIHostingController(rootView: header)
            .sizeThatFits(in: CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude))
            .height
    }

    @Test(arguments: [DynamicTypeSize.xSmall, .large, .accessibility3], [true, false])
    func meetsMinimumTapTarget(size: DynamicTypeSize, expanded: Bool) {
        #expect(height(expanded: expanded, size: size) >= SectionToggleHeader.minTapTarget)
    }

    /// Equal heights with symmetric padding keep the title in place when the section toggles.
    @Test(arguments: [DynamicTypeSize.xSmall, .large, .accessibility3])
    func keepsHeightWhenToggled(size: DynamicTypeSize) {
        #expect(height(expanded: true, size: size) == height(expanded: false, size: size))
    }
}
