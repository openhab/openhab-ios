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

import Kingfisher
import OpenHABCore
import os.log
import SwiftUI

/// A SwiftUI view that displays widget icons with openHAB-specific styling and caching
struct IconURLView: View {
    @State var iconURL: URL

    let size: CGSize

    private let logger = Logger(subsystem: "org.openhab", category: "IconURLView")

    var body: some View {
        ZStack {
            // No icon or failed to load - show empty space
            Rectangle()
                .fill(Color.clear)
                .frame(width: size.width, height: size.height)

            KFImage(iconURL)
                .retry(maxCount: 3, interval: .seconds(5))
                .resizable()
                .setProcessor(OpenHABImageProcessor())
                .onFailure { error in
                    logger.error("Icon loading failed for URL : \(iconURL): \(error.localizedDescription)")
                }
                .onSuccess { _ in
                    logger.info("Loading succeeded for URL : \(iconURL)")
                }
                .fade(duration: 0.25)
                .cancelOnDisappear(true)
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
        }
    }
}

#Preview {
    IconURLView(iconURL: URL(string: "https://github.com/onevcat/Flower-Data-Set/raw/master/rose/rose-1.jpg")!, size: CGSize(width: 100, height: 100))
}
