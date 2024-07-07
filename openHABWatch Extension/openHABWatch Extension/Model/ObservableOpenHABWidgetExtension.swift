// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import os.log
import SwiftUI

extension ObservableOpenHABWidget {
    @ViewBuilder func makeView(settings: ObservableOpenHABDataObject) -> some View {
        if let linkedPage {
            let title = linkedPage.title.components(separatedBy: "[")[0]
            let pageUrl = linkedPage.link
            // os_log("Selected %{public}@", log: .viewCycle, type: .info, pageUrl)
            NavigationLink(destination:
                LazyView(
                    ContentView(viewModel: UserData(url: URL(string: pageUrl)), settings: settings, title: title))
            ) {
                Image(systemName: "chevron.right")
            }
        } else {
            EmptyView()
        }
    }
}
