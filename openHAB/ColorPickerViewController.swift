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

import FlexColorPicker
import OpenHABCore
import os.log
import UIKit

class ColorPickerViewController: DefaultColorPickerViewController {
    var widget: OpenHABWidget?

    /// Throttle engine
    private var throttler: Throttler?

    /// Throttling interval
    var throttlingInterval: TimeInterval? = 0 {
        didSet {
            guard let interval = throttlingInterval else {
                throttler = nil
                return
            }
            throttler = Throttler(maxInterval: interval)
        }
    }

    required init?(coder: NSCoder) {
        Logger.widgets.info("ColorPickerViewController initWithCoder")
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        Logger.widgets.info("ColorPickerViewController viewDidLoad")

        if let color = widget?.item?.stateAsUIColor() {
            selectedColor = color
        }

        delegate = self

        if #available(iOS 13.0, *) {
            // if nothing is set DefaultColorPickerViewController will fall back to .white
            // if we set this manually DefaultColorPickerViewController will go with that
            view.backgroundColor = .ohSystemBackground
        } else {
            // do nothing - DefaultColorPickerViewController will handle this
        }

        super.viewDidLoad()
        throttlingInterval = 0.3
    }

    func sendColorUpdate(color: UIColor) {
        // swiftlint:disable:next large_tuple
        var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        hue *= 360
        saturation *= 100
        brightness *= 100

        Logger.widgets.info("Color changed to HSB(\(hue), \(saturation), \(brightness)).")

        widget?.sendCommand("\(hue),\(saturation),\(brightness)")
    }
}

extension ColorPickerViewController: @preconcurrency ColorPickerDelegate {
    func colorPicker(_ colorPicker: ColorPickerController, selectedColor: UIColor, usingControl: any ColorControl) {
        if let throttler {
            throttler.throttle { DispatchQueue.main.async { self.sendColorUpdate(color: selectedColor) } }
        } else {
            sendColorUpdate(color: selectedColor)
        }
    }

    func colorPicker(_ colorPicker: ColorPickerController, confirmedColor: UIColor, usingControl: any ColorControl) {
        sendColorUpdate(color: confirmedColor)
    }
}
