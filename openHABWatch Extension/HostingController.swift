// Copyright (c) 2010-2023 Contributors to the openHAB project
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
import Kingfisher
import OpenHABCore
import os.log
import SwiftUI
import WatchKit

class HostingController: WKHostingController<ContentView> {
    @ObservedObject var settings = ObservableOpenHABDataObject.shared
    let userData = UserData(sitemapName: ObservableOpenHABDataObject.shared.sitemapName)

    override var body: ContentView {
        ContentView(viewModel: userData, settings: settings)
    }

    override init() {
        super.init()
        ExtensionDelegate.extensionDelegate.viewModel = userData
    }
}
