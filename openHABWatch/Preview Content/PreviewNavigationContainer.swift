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

#if DEBUG
import SwiftUI

struct PreviewNavigationContainer<Content: View>: View {
    @State private var settings = AppSettings()
    private let content: Content

    var body: some View {
        NavigationStack {
            content
        }
        .environmentObject(settings)
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
}
#endif
