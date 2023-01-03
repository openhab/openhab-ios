// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import DynamicButton
import UIKit

/// Bell symbol style: 🔔
struct DynamicButtonStyleBell: DynamicButtonBuildableStyle {
    /// "Bell" style.
    static var styleName: String {
        "Bell"
    }

    let pathVector: DynamicButtonPathVector

    init(center: CGPoint, size: CGFloat, offset: CGPoint, lineWidth: CGFloat) {
        let gongRadius = size / 7
        let gongCenter = CGPoint(x: center.x, y: size - gongRadius - lineWidth)

        let startAngle = CGFloat.pi
        let endAngle = startAngle + CGFloat.pi
        let gongPath = UIBezierPath(arcCenter: gongCenter, radius: gongRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

        let bellHeight = gongCenter.y - (lineWidth / 2.0)

        let bellTop = UIBezierPath()
        bellTop.move(to: CGPoint(x: 0, y: 26))
        bellTop.addCurve(to: CGPoint(x: 6, y: 12), controlPoint1: CGPoint(x: 0, y: 26), controlPoint2: CGPoint(x: 4.5, y: 22))
        bellTop.addCurve(to: CGPoint(x: 16, y: 2), controlPoint1: CGPoint(x: 6, y: 6), controlPoint2: CGPoint(x: 10.5, y: 2))
        bellTop.addCurve(to: CGPoint(x: 26, y: 12), controlPoint1: CGPoint(x: 21.5, y: 2), controlPoint2: CGPoint(x: 26, y: 6))
        bellTop.addCurve(to: CGPoint(x: 32, y: 26), controlPoint1: CGPoint(x: 27.5, y: 22), controlPoint2: CGPoint(x: 32, y: 26))
        bellTop.apply(CGAffineTransform(scaleX: size / 32.0, y: bellHeight / 26.0))

        let bellBottom = UIBezierPath()
        bellBottom.move(to: CGPoint(x: 0, y: bellHeight))
        bellBottom.addLine(to: CGPoint(x: size, y: bellHeight))

        pathVector = DynamicButtonPathVector(p1: bellTop.cgPath, p2: bellBottom.cgPath, p3: bellBottom.cgPath, p4: gongPath.cgPath)
    }
}
