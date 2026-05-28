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

import Combine
import CommonUI
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import SFSafeSymbols
import SwiftUI

struct ImageView: View {
    let url: String

    @EnvironmentObject var networkTracker: MainActorNetworkTracker

    var body: some View {
        if !url.isEmpty {
            switch url {
            case _ where url.hasPrefix("data:image"):
                if let imageData = url.dataImageBase64Data {
                    let provider = RawImageDataProvider(data: imageData, cacheKey: UUID().uuidString)
                    KFImage(source: .provider(provider))
                        .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                        .resizable()
                } else {
                    Image("openHABIcon").resizable()
                }
            case _ where url.hasPrefix("http"):
                KFImage(URL(string: url))
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                    .resizable()
            default:
                let builtURL = Endpoint.resource(
                    openHABRootUrl: networkTracker.activeConnection?.configuration.url ?? "",
                    path: url.prepare()
                ).url
                KFImage(builtURL)
                    .withOpenHABCredentials(for: networkTracker.activeConnection)
                    .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                    .resizable()
            }
        } else {
            // This will always fallback to placeholder
            KFImage(URL(string: "bundle://openHABIcon")).placeholder { Image("openHABIcon").resizable() }
        }
    }
}
