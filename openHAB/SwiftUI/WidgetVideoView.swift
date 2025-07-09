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

import AVKit
import OpenHABCore
import SwiftUI

struct WidgetVideoView: View {
    @ObservedObject var widget: OpenHABWidget
    @State private var player: AVPlayer?

    private var videoURL: URL? {
        guard !widget.url.isEmpty else { return nil }
        return URL(string: widget.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundColor(widget.labelcolor.isEmpty ? .primary : Color(UIColor(fromString: widget.labelcolor)))
            }

            if let videoURL {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .cornerRadius(8)
                    .onAppear {
                        player = AVPlayer(url: videoURL)
                    }
                    .onDisappear {
                        player?.pause()
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Text("No Video URL")
                            .foregroundColor(.secondary)
                    )
                    .cornerRadius(8)
            }

            if let labelValue = widget.labelValue, !labelValue.isEmpty {
                Text(labelValue)
                    .font(.caption)
                    .foregroundColor(widget.valuecolor.isEmpty ? .secondary : Color(UIColor(fromString: widget.valuecolor)))
            }
        }
    }
}
