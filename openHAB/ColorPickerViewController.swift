// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import os.log
import UIKit

class ColorPickerViewController: DefaultColorPickerViewController {
    var widget: OpenHABWidget?

    /// Throttle engine
    private var throttler: Throttler?

    /// Throttling interval
    public var throttlingInterval: TimeInterval? = 0 {
        didSet {
            guard let interval = throttlingInterval else {
                self.throttler = nil
                return
            }
            self.throttler = Throttler(maxInterval: interval)
        }
    }

    required init?(coder: NSCoder) {
        os_log("ColorPickerViewController initWithCoder", log: .viewCycle, type: .info)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        os_log("ColorPickerViewController viewDidLoad", log: .viewCycle, type: .info)

        if let color = widget?.item?.stateAsUIColor() {
            selectedColor = color
        }

        delegate = self

        if #available(iOS 13.0, *) {
            // if nothing is set DefaultColorPickerViewController will fall back to .white
            // if we set this manually DefaultColorPickerViewController will go with that
            self.view.backgroundColor = .ohSystemBackground
        } else {
            // do nothing - DefaultColorPickerViewController will handle this
        }

        super.viewDidLoad()
        throttlingInterval = 0.3
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func sendColorUpdate(color: UIColor) {
        var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        hue *= 360
        saturation *= 100
        brightness *= 100

        os_log("Color changed to HSB(%g, %g, %g).", log: .default, type: .info, hue, saturation, brightness)

        widget?.sendCommand("\(hue),\(saturation),\(brightness)")
    }
}

extension ColorPickerViewController: ColorPickerDelegate {
    func colorPicker(_ colorPicker: ColorPickerController, selectedColor: UIColor, usingControl: ColorControl) {
        if let throttler = self.throttler {
            throttler.throttle { DispatchQueue.main.async { self.sendColorUpdate(color: selectedColor) } }
        } else {
            sendColorUpdate(color: selectedColor)
        }
    }

    func colorPicker(_ colorPicker: ColorPickerController, confirmedColor: UIColor, usingControl: ColorControl) {
        sendColorUpdate(color: confirmedColor)
    }
}
