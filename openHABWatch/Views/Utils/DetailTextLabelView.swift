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

import CommonUI
import SwiftUI

struct DetailTextLabelView: View {
    let text: String?
    let valueColor: String

    var body: some View {
        if let text {
            Text(text)
                .font(WatchTypography.detailFont)
                .lineLimit(WatchTypography.detailLineLimit)
                .minimumScaleFactor(WatchTypography.detailMinScale)
                .truncationMode(.tail)
                .foregroundStyle(!valueColor.isEmpty ? Color(fromString: valueColor) : .secondary)
        }
    }

    init(text: String?, valueColor: String = "") {
        self.text = text
        self.valueColor = valueColor
    }
}

#Preview {
    DetailTextLabelView(text: "450 W", valueColor: "#00AEEF")
}
