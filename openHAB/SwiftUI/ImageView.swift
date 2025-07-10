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
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

struct ImageView: View {
    let url: String

    @EnvironmentObject var networkTracker: NetworkTracker

    var body: some View {
        if !url.isEmpty {
            switch url {
            case _ where url.hasPrefix("data:image"):
                let provider = Base64ImageDataProvider(base64String: url.deletingPrefix("data:image/png;base64,"), cacheKey: UUID().uuidString)
                return KFImage(source: .provider(provider)).resizable()
            case _ where url.hasPrefix("http"):
                return KFImage(URL(string: url)).resizable()
            default:
                let builtURL = Endpoint.resource(
                    openHABRootUrl: networkTracker.activeConnection?.configuration.url ?? "",
                    path: url.prepare()
                ).url
                return KFImage(builtURL).resizable()
            }
        } else {
            // This will always fallback to placeholder
            return KFImage(URL(string: "bundle://openHABIcon")).placeholder { Image("openHABIcon").resizable() }
        }
    }
}
