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

import CommonUI
import Kingfisher
import OpenHABCore
import SwiftUI

struct ImageRowView: View {
    @ObservedObject var widget: OpenHABWidget
    @EnvironmentObject var viewModel: SitemapPageViewModel

    private var imageURL: URL? {
        guard !widget.url.isEmpty else { return nil }
        return URL(string: widget.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
            }

            if let imageURL {
                KFImage(imageURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Text("No Image URL")
                            .foregroundColor(.secondary)
                    )
                    .cornerRadius(8)
            }

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(fromString: widget.valuecolor))
            }
        }
    }
}
