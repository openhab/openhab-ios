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

import Combine
import Foundation
import OpenHABCore

final class ObservableOpenHABDataObject: ObservableObject {
    static let shared = ObservableOpenHABDataObject()

    var openHABVersion: Int = 2

    @Published var localConnectionConfig: ConnectionConfiguration?
    @Published var remoteConnectionConfig: ConnectionConfiguration?
    @Published var haveReceivedAppContext: Bool = false

    @Published var openHABRootUrl = ""
    @Published var sitemapName = ""
    @Published var sitemapForWatch = ""
    @Published var iconType: IconType = .svg
}

extension ObservableOpenHABDataObject {
    convenience init(openHABRootUrl: String) {
        self.init()
        self.openHABRootUrl = openHABRootUrl
    }
}
