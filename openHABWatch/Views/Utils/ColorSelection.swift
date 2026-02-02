// Copyright (c) 2010-2026 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import OpenHABCore
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
    @ObservedObject var widget: OpenHABWidget
    @GestureState var thumb: DragState = .inactive

    @State private var hue = 0.0
    @State private var saturation = 1.0
    @State private var brightness = 1.0
    @State private var xpos: Double = 100
    @State private var ypos: Double = 100
    @State private var dragStart: CGPoint?
    @State private var lastSendTime: Date = .distantPast

    private let handleRadius = 12.5

    var body: some View {
        // Use a clockwise spectrum to match the handle's hue direction.
        let spectrum = Gradient(colors: [.red, .purple, .blue, .green, .yellow, .red])

        // Rotate so hue = 0 aligns with top (matching the handle math).
        let conic = AngularGradient(gradient: spectrum, center: .center, angle: .degrees(-90))

        return GeometryReader { (geometry: GeometryProxy) in
            ZStack(alignment: .topLeading) {
                Circle()
                    .size(geometry.size)
                    .fill(conic)
                    .overlay(generateHandle(geometry: geometry))

                Circle()
                    .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .padding(6)
            }
            .onAppear {
                initializeFromState(geometry.size)
            }
            .onChange(of: widget.item?.state ?? "") { _, newState in
                guard !newState.isEmpty else { return }
                updateFromState(newState, geometry.size)
            }
        }
    }

    /// Prevent the draggable element from going over its limit
    func limitDisplacement(_ value: Double, _ limit: CGFloat, _ state: CGFloat) -> CGFloat {
        (CGFloat(value) * limit + state).clamped(to: 0 ... limit)
    }

    /// Prevent the draggable element from going beyond the circle
    func limitCircle(_ point: CGPoint, _ geometry: CGSize) -> CGPoint {
        let center = CGPoint(x: geometry.width / 2, y: geometry.height / 2)
        let x1 = Double(point.x - center.x)
        let y1 = Double(point.y - center.y)
        let theta = atan2(x1, y1)
        // Circle limit.width = limit.height
        let maxRadius = max(0.0, Double(min(geometry.width, geometry.height) / 2))
        let radius = min(sqrt(x1 * x1 + y1 * y1), maxRadius)
        return CGPoint(
            x: CGFloat(sin(theta) * radius) + center.x,
            y: CGFloat(cos(theta) * radius) + center.y
        )
    }

    /// Creates the `Handle` and adds the drag gesture to it.
    func generateHandle(geometry: GeometryProxy) -> some View {
        let drag = DragGesture(minimumDistance: 0)
            .updating($thumb) { value, state, _ in
                state = .dragging(translation: value.translation)
            }
            .onChanged { value in
                let start = dragStart ?? CGPoint(x: xpos, y: ypos)
                if dragStart == nil {
                    dragStart = start
                }
                let proposed = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
                let limited = limitCircle(proposed, geometry.size)
                xpos = Double(limited.x)
                ypos = Double(limited.y)
                updateColorFromPosition(in: geometry.size, send: true)
            }
            .onEnded { value in
                Logger.rowViews.info("Translation x y = \(value.translation.width), \(value.translation.height)")
                let start = dragStart ?? CGPoint(x: xpos, y: ypos)
                let proposed = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
                let limited = limitCircle(proposed, geometry.size)
                xpos = Double(limited.x)
                ypos = Double(limited.y)
                dragStart = nil
                updateColorFromPosition(in: geometry.size, send: true, force: true)
            }

        // MARK: Customize Handle Here

        // Add the gestures and visuals to the handle
        return Circle()
            .overlay(thumb.isDragging ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .foregroundStyle(.white)
            .frame(width: 25, height: 25, alignment: .center)
            .position(limitCircle(CGPoint(x: xpos, y: ypos), geometry.size))
            .animation(.interactiveSpring(), value: thumb.isDragging)
            .gesture(drag)
    }

    private func initializeFromState(_ size: CGSize) {
        if let state = widget.item?.state, !state.isEmpty {
            updateFromState(state, size)
        } else {
            updateHandlePosition(in: size)
        }
    }

    private func updateFromState(_ state: String, _ size: CGSize) {
        let components = state.split(separator: ",")
        guard components.count >= 3,
              let hueValue = Double(components[0]),
              let saturationValue = Double(components[1]),
              let brightnessValue = Double(components[2]) else {
            return
        }
        hue = hueValue / 360.0
        saturation = saturationValue / 100.0
        brightness = brightnessValue / 100.0
        updateHandlePosition(in: size)
    }

    private func updateHandlePosition(in size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let usableRadius = max(0.0, Double(radius))
        // Reverse the 180° offset when placing the handle.
        let angle = (hue - 0.5) * 2.0 * Double.pi
        let dist = max(0.0, min(1.0, saturation)) * usableRadius
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // Match limitCircle's angle convention (x = sin, y = cos).
        xpos = Double(center.x) + sin(angle) * dist
        ypos = Double(center.y) + cos(angle) * dist
    }

    private func updateColorFromPosition(in size: CGSize, send: Bool, force: Bool = false) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = Double(xpos) - Double(center.x)
        let dy = Double(ypos) - Double(center.y)
        // Match limitCircle's angle convention (atan2(x, y)).
        let angle = atan2(dx, dy)
        let normalizedAngle = angle >= 0 ? angle : (2.0 * Double.pi + angle)
        hue = normalizedAngle / (2.0 * Double.pi)
        // Align with wheel orientation (current visual mapping is 180° offset).
        hue = (hue + 0.5).truncatingRemainder(dividingBy: 1.0)
        let radius = sqrt(dx * dx + dy * dy)
        let maxRadius = max(1.0, Double(min(size.width, size.height) / 2))
        saturation = max(0.0, min(1.0, radius / maxRadius))
        if send {
            let now = Date()
            if force || now.timeIntervalSince(lastSendTime) > 0.2 {
                lastSendTime = now
                sendColorCommand()
            }
        }
    }

    private func sendColorCommand() {
        let hueValue = Int(hue * 360.0)
        let saturationValue = Int(saturation * 100.0)
        let brightnessValue = Int(brightness * 100.0)
        let command = "\(hueValue),\(saturationValue),\(brightnessValue)"
        Logger.rowViews.info("Sending color command: \(command)")
        widget.sendCommand(command)
    }
}

#Preview {
    ColorSelection(widget: UserData(preview: true).widgets[10])
}
