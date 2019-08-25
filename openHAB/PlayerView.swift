//
//  PlayerView.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 05.03.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

// See https://developer.apple.com/documentation/avfoundation/avplayerlayer
// A convenient way of using AVPlayerLayer as the backing layer for a UIView

import AVFoundation
import AVKit

class PlayerView: UIView {

    // Override UIView property
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
}
