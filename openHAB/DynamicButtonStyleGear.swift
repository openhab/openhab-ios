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

/// Gear symbol style: ⚙
struct DynamicButtonStyleGear: DynamicButtonBuildableStyle {
    /// "Gear" style.
    static var styleName: String {
        "Gear"
    }

    let pathVector: DynamicButtonPathVector

    init(center: CGPoint, size: CGFloat, offset: CGPoint, lineWidth: CGFloat) {
        let shape = UIBezierPath()
        shape.move(to: CGPoint(x: 19.4, y: 13))
        shape.addCurve(to: CGPoint(x: 19.5, y: 12), controlPoint1: CGPoint(x: 19.4, y: 12.7), controlPoint2: CGPoint(x: 19.5, y: 12.3))
        shape.addCurve(to: CGPoint(x: 19.4, y: 11), controlPoint1: CGPoint(x: 19.5, y: 11.7), controlPoint2: CGPoint(x: 19.5, y: 11.3))
        shape.addLine(to: CGPoint(x: 21.5, y: 9.5))
        shape.addCurve(to: CGPoint(x: 21.6, y: 8.8), controlPoint1: CGPoint(x: 21.7, y: 9.4), controlPoint2: CGPoint(x: 21.8, y: 9.1))
        shape.addLine(to: CGPoint(x: 19.6, y: 5.3))
        shape.addCurve(to: CGPoint(x: 19, y: 5), controlPoint1: CGPoint(x: 19.5, y: 5), controlPoint2: CGPoint(x: 19.2, y: 4.9))
        shape.addLine(to: CGPoint(x: 16.6, y: 6.1))
        shape.addCurve(to: CGPoint(x: 14.8, y: 5.1), controlPoint1: CGPoint(x: 16.1, y: 5.7), controlPoint2: CGPoint(x: 15.4, y: 5.3))
        shape.addLine(to: CGPoint(x: 14.5, y: 2.5))
        shape.addCurve(to: CGPoint(x: 14, y: 2), controlPoint1: CGPoint(x: 14.5, y: 2.2), controlPoint2: CGPoint(x: 14.3, y: 2))
        shape.addLine(to: CGPoint(x: 10, y: 2))
        shape.addCurve(to: CGPoint(x: 9.5, y: 2.5), controlPoint1: CGPoint(x: 9.7, y: 2), controlPoint2: CGPoint(x: 9.5, y: 2.2))
        shape.addLine(to: CGPoint(x: 9.2, y: 5))
        shape.addCurve(to: CGPoint(x: 7.4, y: 6), controlPoint1: CGPoint(x: 8.5, y: 5.3), controlPoint2: CGPoint(x: 7.9, y: 5.6))
        shape.addLine(to: CGPoint(x: 5, y: 5))
        shape.addCurve(to: CGPoint(x: 4.4, y: 5.2), controlPoint1: CGPoint(x: 4.8, y: 4.9), controlPoint2: CGPoint(x: 4.5, y: 5))
        shape.addLine(to: CGPoint(x: 2.4, y: 8.7))
        shape.addCurve(to: CGPoint(x: 2.5, y: 9.4), controlPoint1: CGPoint(x: 2.2, y: 9), controlPoint2: CGPoint(x: 2.2, y: 9.3))
        shape.addLine(to: CGPoint(x: 4.6, y: 11))
        shape.addCurve(to: CGPoint(x: 4.5, y: 12), controlPoint1: CGPoint(x: 4.6, y: 11.3), controlPoint2: CGPoint(x: 4.5, y: 11.7))
        shape.addCurve(to: CGPoint(x: 4.6, y: 13), controlPoint1: CGPoint(x: 4.5, y: 12.3), controlPoint2: CGPoint(x: 4.5, y: 12.7))
        shape.addLine(to: CGPoint(x: 2.5, y: 14.5))
        shape.addCurve(to: CGPoint(x: 2.4, y: 15.2), controlPoint1: CGPoint(x: 2.3, y: 14.6), controlPoint2: CGPoint(x: 2.2, y: 14.9))
        shape.addLine(to: CGPoint(x: 4.4, y: 18.7))
        shape.addCurve(to: CGPoint(x: 5, y: 19), controlPoint1: CGPoint(x: 4.5, y: 19), controlPoint2: CGPoint(x: 4.8, y: 19.1))
        shape.addLine(to: CGPoint(x: 7.4, y: 17.9))
        shape.addCurve(to: CGPoint(x: 9.2, y: 18.9), controlPoint1: CGPoint(x: 7.9, y: 18.3), controlPoint2: CGPoint(x: 8.6, y: 18.7))
        shape.addLine(to: CGPoint(x: 9.5, y: 21.5))
        shape.addCurve(to: CGPoint(x: 10, y: 22), controlPoint1: CGPoint(x: 9.5, y: 21.8), controlPoint2: CGPoint(x: 9.7, y: 22))
        shape.addLine(to: CGPoint(x: 14, y: 22))
        shape.addCurve(to: CGPoint(x: 14.5, y: 21.5), controlPoint1: CGPoint(x: 14.3, y: 22), controlPoint2: CGPoint(x: 14.5, y: 21.8))
        shape.addLine(to: CGPoint(x: 14.8, y: 18.9))
        shape.addCurve(to: CGPoint(x: 16.6, y: 17.9), controlPoint1: CGPoint(x: 15.5, y: 18.6), controlPoint2: CGPoint(x: 16.1, y: 18.3))
        shape.addLine(to: CGPoint(x: 19, y: 19))
        shape.addCurve(to: CGPoint(x: 19.6, y: 18.8), controlPoint1: CGPoint(x: 19.2, y: 19.1), controlPoint2: CGPoint(x: 19.5, y: 19))
        shape.addLine(to: CGPoint(x: 21.6, y: 15.3))
        shape.addCurve(to: CGPoint(x: 21.5, y: 14.6), controlPoint1: CGPoint(x: 21.7, y: 15.1), controlPoint2: CGPoint(x: 21.7, y: 14.8))
        shape.addLine(to: CGPoint(x: 19.4, y: 13))
        shape.close()

        shape.apply(CGAffineTransform(scaleX: (size - 2 * lineWidth) / 21.6, y: (size - 2 * lineWidth) / 21.6))

        let radius = size / 4.8 - lineWidth

        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x + radius, y: center.y))
        path.addArc(center: CGPoint(x: center.x, y: center.y), radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)

        pathVector = DynamicButtonPathVector(p1: shape.cgPath, p2: shape.cgPath, p3: path, p4: path)
    }
}
