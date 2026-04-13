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
                    return AnyView(
                        KFImage(source: .provider(provider))
                            .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                            .resizable()
                    )
                } else {
                    return AnyView(Image("openHABIcon").resizable())
                }
            case _ where url.hasPrefix("http"):
                return KFImage(URL(string: url))
                    .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                    .resizable()
            default:
                let builtURL = Endpoint.resource(
                    openHABRootUrl: networkTracker.activeConnection?.configuration.url ?? "",
                    path: url.prepare()
                ).url
                return KFImage(builtURL)
                    .setProcessor(OpenHABImageProcessor(svgMaxSize: nil))
                    .resizable()
            }
        } else {
            // This will always fallback to placeholder
            return KFImage(URL(string: "bundle://openHABIcon")).placeholder { Image("openHABIcon").resizable() }
        }
    }
}
