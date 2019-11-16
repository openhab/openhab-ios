// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SwiftUI

// swiftlint:disable file_types_order
struct NotificationView: View {
    let customTextLabel: String?
    let customDetailTextLabel: String?

    var body: some View {
        VStack {
            Text(customTextLabel ?? "Unknown Message Text")
                .font(.headline)
                .lineLimit(0)

            Text(customDetailTextLabel ?? "Unknown Message Text")
                .font(.caption)
                .lineLimit(0)
        }
    }

    init(customTextLabel: String? = nil, customDetailTextLabel: String? = nil) {
        self.customTextLabel = customTextLabel
        self.customDetailTextLabel = customDetailTextLabel
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NotificationView()

            NotificationView(customTextLabel: "Light 2", customDetailTextLabel: "Off")
        }
        .previewLayout(.sizeThatFits)
    }
}
