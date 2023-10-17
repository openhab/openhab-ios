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

import os.log
import SwiftUI

/// Drag State describing the combination of a long press and drag gesture.
///  - seealso:
///  [Reference]: https://developer.apple.com/documentation/swiftui/gestures/composing_swiftui_gestures "Composing SwiftUI Gestures "
enum DragState {
    case inactive
    case pressing
    case dragging(translation: CGSize)

    var translation: CGSize {
        switch self {
        case .inactive, .pressing:
            .zero
        case let .dragging(translation):
            translation
        }
    }

    var isActive: Bool {
        switch self {
        case .inactive:
            false
        case .pressing, .dragging:
            true
        }
    }

    var isDragging: Bool {
        switch self {
        case .inactive, .pressing:
            false
        case .dragging:
            true
        }
    }
}

struct ColorSelection: View {
    @GestureState var thumb: DragState = .inactive

    @State var hue: Double = 0.5
    @State var xpos: Double = 100
    @State var ypos: Double = 100

    var body: some View {
        let spectrum = Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red])

        let conic = AngularGradient(gradient: spectrum, center: .center, angle: .degrees(0))

        return GeometryReader { (geometry: GeometryProxy) in
            Circle()
                .size(geometry.size)
                .fill(conic)
                .overlay(generateHandle(geometry: geometry))
        }
    }

    /// Prevent the draggable element from going over its limit
    func limitDisplacement(_ value: Double, _ limit: CGFloat, _ state: CGFloat) -> CGFloat {
        max(0, min(limit, CGFloat(value) * limit + state))
    }

    /// Prevent the draggable element from going beyond the circle
    func limitCircle(_ point: CGPoint, _ geometry: CGSize, _ state: CGSize) -> (CGPoint) {
        let x1 = point.x + state.width - geometry.width / 2
        let y1 = point.y + state.height - geometry.height / 2
        let theta = atan2(x1, y1)
        // Circle limit.width = limit.height
        let radius = min(sqrt(x1 * x1 + y1 * y1), geometry.width / 2)
        return CGPoint(x: sin(theta) * radius + geometry.width / 2, y: cos(theta) * radius + geometry.width / 2)
    }

    /// Creates the `Handle` and adds the drag gesture to it.
    func generateHandle(geometry: GeometryProxy) -> some View {
        ///  [Reference]: https://developer.apple.com/documentation/swiftui/gestures/composing_swiftui_gestures "Composing SwiftUI Gestures "
        let longPressDrag = LongPressGesture(minimumDuration: 0.05)
            .sequenced(before: DragGesture())
            .updating($thumb) { value, state, _ in
                switch value {
                // Long press begins.
                case .first(true):
                    state = .pressing
                // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    state = .dragging(translation: drag?.translation ?? .zero)
                // Dragging ended or the long press cancelled.
                default:
                    state = .inactive
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                os_log("Translation x y = %g, %g", log: .default, type: .info, drag.translation.width, drag.translation.height)

                xpos += Double(drag.translation.width)
                ypos += Double(drag.translation.height)
            }

        // MARK: Customize Handle Here

        // Add the gestures and visuals to the handle
        return Circle()
            .overlay(thumb.isDragging ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .foregroundColor(.white)
            .frame(width: 25, height: 25, alignment: .center)
            .position(limitCircle(CGPoint(x: xpos, y: ypos), geometry.size, thumb.translation))
            .animation(.interactiveSpring())
            .gesture(longPressDrag)
    }
}

struct ColorSelection_Previews: PreviewProvider {
    static var previews: some View {
        ColorSelection()
    }
}
