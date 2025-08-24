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

import Combine
import os.log
import SwiftUI

struct ScreenSaverView: View {
    // Constants for text dimension estimation
    private static let timeTextWidthMultiplier: CGFloat = 4.0
    private static let dateTextHeightMultiplier: CGFloat = 1.4

    private let logger = Logger(subsystem: "org.openhab", category: "ScreenSaverView")

    let configuration: ScreenSaverConfiguration

    @State private var currentPosition: CGPoint = .zero
    @State private var screenSize: CGSize = .zero
    @State private var fadeOpacity = 1.0
    @State private var movementTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var isTimerActive = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)
                    }

                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    VStack(spacing: 0) {
                        if configuration.showsDate {
                            Text(dateString(for: context.date))
                                .font(dateFont(for: geometry.size))
                                .monospacedDigit()
                                .foregroundColor(.white.opacity(0.85 * alphaFactor))
                        }

                        if configuration.showsTime {
                            Text(timeString(for: context.date))
                                .font(timeFont(for: geometry.size))
                                .monospacedDigit()
                                .foregroundColor(.white.opacity(alphaFactor))
                        }
                    }
                    .opacity(fadeOpacity)
                    .position(currentPosition)
                }
            }
            .onReceive(movementTimer) { _ in
                guard isTimerActive else { return }

                let half = max(configuration.fadeDuration / 2.0, 0.01)

                Task {
                    // Fade out on the main actor
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: half)) {
                            fadeOpacity = 0.0
                        }
                    }

                    // Wait for half the duration before moving
                    try? await Task.sleep(nanoseconds: UInt64(half * 1_000_000_000))

                    // Move and fade back in on the main actor
                    await MainActor.run {
                        currentPosition = calculateRandomPosition(for: screenSize)
                        withAnimation(.easeInOut(duration: half)) {
                            fadeOpacity = 1.0
                        }
                    }
                }
            }
            .onAppear {
                screenSize = geometry.size
                currentPosition = calculateRandomPosition(for: geometry.size)
                startMovementTimer()
            }
            .onDisappear {
                stopMovementTimer()
            }
            .onChange(of: geometry.size) { newSize in
                screenSize = newSize
                currentPosition = calculateRandomPosition(for: newSize)
            }
        }
    }

    private var alphaFactor: CGFloat {
        let clamped = min(max(configuration.dimLevel, 0.0), 1.0)
        let alpha = 0.5 + 0.5 * sqrt(clamped)
        return min(1.0, alpha)
    }

    // MARK: - Private Methods

    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        if configuration.showsSeconds {
            formatter.dateFormat = configuration.uses24HourTime ? "H:mm:ss" : "h:mm:ss a"
        } else {
            formatter.dateFormat = configuration.uses24HourTime ? "H:mm" : "h:mm a"
        }
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func timeFont(for size: CGSize) -> Font {
        let shortSide = min(size.width, size.height)
        let fontSize = max(shortSide * configuration.timeFontSizeRatio, 48)

        if let fontName = configuration.fontName {
            if isFontAvailable(fontName) {
                return .custom(fontName, size: fontSize)
            } else {
                logger.warning("Custom font '\(fontName)' not found. Falling back to system font.")
                return .system(size: fontSize, weight: .thin)
            }
        } else {
            return .system(size: fontSize, weight: .thin)
        }
    }

    private func dateFont(for size: CGSize) -> Font {
        let shortSide = min(size.width, size.height)
        let timeFontSize = max(shortSide * configuration.timeFontSizeRatio, 48)
        let dateFontSize = timeFontSize * configuration.dateFontRelativeSize

        if let fontName = configuration.fontName {
            return .custom(fontName, size: dateFontSize)
        } else {
            return .system(size: dateFontSize, weight: .regular)
        }
    }

    private func startMovementTimer() {
        // Create a new timer with the correct interval
        movementTimer = Timer.publish(every: configuration.movementInterval, on: .main, in: .common).autoconnect()
        isTimerActive = true
    }

    private func stopMovementTimer() {
        isTimerActive = false
    }

    private func calculateRandomPosition(for size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let edgeMargin: CGFloat = 20

        // Estimate label size (this is approximate since we can't measure exactly in SwiftUI)
        let shortSide = min(size.width, size.height)
        let timeFontSize = max(shortSide * configuration.timeFontSizeRatio, 48)
        let estimatedWidth = timeFontSize * Self.timeTextWidthMultiplier
        let estimatedHeight = timeFontSize * (configuration.showsDate ? Self.dateTextHeightMultiplier : 1.0)

        let availableWidth = size.width - estimatedWidth - edgeMargin * 2
        let availableHeight = size.height - estimatedHeight - edgeMargin * 2

        if availableWidth > 0, availableHeight > 0 {
            let randomX = edgeMargin + estimatedWidth / 2 + CGFloat.random(in: 0 ... availableWidth)
            let randomY = edgeMargin + estimatedHeight / 2 + CGFloat.random(in: 0 ... availableHeight)
            return CGPoint(x: randomX, y: randomY)
        } else {
            // Fallback for small screens - use full screen area with minimum margins
            let minMargin: CGFloat = 10
            let safeWidth = max(size.width - minMargin * 2, size.width * 0.1)
            let safeHeight = max(size.height - minMargin * 2, size.height * 0.1)
            let fallbackX = minMargin + CGFloat.random(in: 0 ... safeWidth)
            let fallbackY = minMargin + CGFloat.random(in: 0 ... safeHeight)
            return CGPoint(x: fallbackX, y: fallbackY)
        }
    }

    func isFontAvailable(_ fontName: String) -> Bool {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return UIFont(name: fontName, size: 12) != nil
        #elseif os(macOS)
        return NSFont(name: fontName, size: 12) != nil
        #else
        return false
        #endif
    }
}

#Preview {
    ScreenSaverView(configuration: ScreenSaverConfiguration(
        showsTime: true,
        showsDate: true,
        showsSeconds: false,
        uses24HourTime: true
    ))
    .frame(width: 400, height: 300)
}
