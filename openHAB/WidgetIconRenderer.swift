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

import Foundation
import Kingfisher
import OpenHABCore
import os.log
import UIKit

enum WidgetIconRenderer {
    static func loadIcon(for widget: OpenHABWidget,
                         into imageView: UIImageView?,
                         in traitCollection: UITraitCollection,
                         openHABRootUrl: String,
                         openHABVersion: Int,
                         iconType: IconType,
                         logger: Logger) {
        guard let imageView, !widget.icon.isEmpty else { return }

        var iconColor = widget.iconColor
        if iconColor.isEmpty, traitCollection.userInterfaceStyle == .dark {
            iconColor = "white"
        }

        guard let url = Endpoint.icon(
            rootUrl: openHABRootUrl,
            version: openHABVersion,
            icon: widget.icon,
            state: widget.iconState(),
            iconType: iconType,
            iconColor: iconColor
        ).url else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        imageView.kf.setImage(
            with: KF.ImageResource(downloadURL: url, cacheKey: url.path + (url.query ?? "")),
            placeholder: nil,
            options: [.processor(OpenHABImageProcessor())]
        ) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    imageView.setNeedsLayout()
                }
            case let .failure(error):
                logger.error("❌ Failed to load widget icon: \(error.localizedDescription)")
            }
        }
    }
}
