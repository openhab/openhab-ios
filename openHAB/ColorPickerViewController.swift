//
//  ColorPickerViewController.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import UIKit
import os.log

class ColorPickerViewController: UIViewController {
    @objc var widget: OpenHABWidget?
    var colorPickerView: NKOColorPickerView?

    required init?(coder: NSCoder) {
        os_log("ColorPickerViewController initWithCoder", log: .viewCycle, type: .info)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        os_log("ColorPickerViewController viewDidLoad", log: .viewCycle, type: .info)
        let colorDidChangeBlock: NKOColorPickerDidChangeColorBlock = { color in
            var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
            color?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            hue *= 360
            saturation *= 100
            brightness *= 100
            os_log("Color changed to %{PUBLIC}@ %{PUBLIC}@ %{PUBLIC}@", log: .default, type: .info, hue, saturation, brightness)

            let command = "\(hue),\(saturation),\(brightness)"
            self.widget?.sendCommand(command)

        }
        let viewFrame: CGRect = view.frame
        let pickerFrame = CGRect(x: viewFrame.origin.x, y: viewFrame.origin.y + viewFrame.size.height / 10, width: viewFrame.size.width, height: viewFrame.size.height - viewFrame.size.height / 5)
        colorPickerView = NKOColorPickerView(frame: pickerFrame, color: UIColor.blue, andDidChangeColorBlock: colorDidChangeBlock)
        if let colorPickerView = colorPickerView {
            view.addSubview(colorPickerView)
        }
        if widget != nil {
            colorPickerView?.color = widget?.item?.stateAsUIColor()
        }
        super.viewDidLoad()
    }

    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        os_log("Rotation!", log: .viewCycle, type: .info)
        let viewFrame: CGRect = view.frame
        let pickerFrame = CGRect(x: viewFrame.origin.x, y: viewFrame.origin.y, width: viewFrame.size.width, height: viewFrame.size.height - viewFrame.size.height / 5)
        colorPickerView?.frame = pickerFrame
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
