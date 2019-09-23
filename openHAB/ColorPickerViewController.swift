//
//  ColorPickerViewController.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import FlexColorPicker
import os.log
import UIKit

class ColorPickerViewController: DefaultColorPickerViewController {
    var widget: OpenHABWidget?
    let tapMaxDelay: Double = 0.3

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
            self.view.backgroundColor = .systemBackground
        } else {
            // do nothing - DefaultColorPickerViewController will handle this
        }

        super.viewDidLoad()
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
        sendColorUpdate(color: selectedColor)
    }

    func colorPicker(_ colorPicker: ColorPickerController, confirmedColor: UIColor, usingControl: ColorControl) {
        sendColorUpdate(color: confirmedColor)
    }
}
