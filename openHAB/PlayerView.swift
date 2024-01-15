// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

// See https://developer.apple.com/documentation/avfoundation/avplayerlayer
// A convenient way of using AVPlayerLayer as the backing layer for a UIView

import AVFoundation
import AVKit

class PlayerView: UIView {
    // Override UIView property
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
