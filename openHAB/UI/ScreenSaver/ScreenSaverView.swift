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

import Combine
import OpenHABCore
import os.log
import SwiftUI

struct ScreenSaverView: View {
    let configuration: ScreenSaverConfiguration

    @State private var currentAnchor = CGPoint(x: 0.5, y: 0.5)
    @State private var fadeOpacity = 1.0
    @State private var movementTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var isTimerActive = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        NotificationCenter.default.post(name: .wakeScreenSaver, object: nil)
                    }

                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let fontName = validatedFontName()
                    let layout = currentLayout(for: context.date, size: geometry.size, fontName: fontName)

                    VStack(spacing: 0) {
                        if configuration.showsDate {
                            Text(dateString(for: context.date))
                                .font(dateFont(size: layout.dateFontSize, fontName: fontName))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.85 * alphaFactor))
                        }

                        if configuration.showsTime {
                            Text(timeString(for: context.date))
                                .font(timeFont(size: layout.timeFontSize, fontName: fontName))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(alphaFactor))
                        }
                    }
                    .opacity(fadeOpacity)
                    .position(layout.position(
                        in: geometry.size,
                        anchor: currentAnchor,
                        edgeMargin: ScreenSaverLayoutCalculator.edgeMargin
                    ))
                }
            }
            .onReceive(movementTimer) { _ in
                guard isTimerActive else { return }

                let half = max(configuration.fadeDuration / 2.0, 0.01)

                animationTask?.cancel()
                animationTask = Task {
                    withAnimation(.easeInOut(duration: half)) {
                        fadeOpacity = 0.0
                    }

                    try? await Task.sleep(nanoseconds: UInt64(half * 1_000_000_000))
                    guard !Task.isCancelled else { return }

                    currentAnchor = randomAnchor()
                    withAnimation(.easeInOut(duration: half)) {
                        fadeOpacity = 1.0
                    }
                }
            }
            .onAppear {
                currentAnchor = randomAnchor()
                startMovementTimer()
            }
            .onDisappear {
                stopMovementTimer()
            }
            .onChange(of: geometry.size) { _ in
                currentAnchor = randomAnchor()
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
        let amPM: Date.FormatStyle.Symbol.Hour.AMPMStyle = configuration.uses24HourTime ? .omitted : .abbreviated
        var formatStyle: Date.FormatStyle = configuration.uses24HourTime
            ? .dateTime.hour(.twoDigits(amPM: amPM)).minute(.twoDigits)
            : .dateTime.hour(.defaultDigits(amPM: amPM)).minute(.twoDigits)

        if configuration.showsSeconds {
            formatStyle = formatStyle.second(.twoDigits)
        }

        if configuration.uses24HourTime {
            return date.formatted(formatStyle)
        }

        return date.formatted(formatStyle.locale(Locale(identifier: "en_US_POSIX")))
    }

    private func dateString(for date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func timeFont(size: CGFloat, fontName: String?) -> Font {
        if let fontName {
            .custom(fontName, size: size)
        } else {
            .system(size: size, weight: .thin)
        }
    }

    private func dateFont(size: CGFloat, fontName: String?) -> Font {
        if let fontName {
            .custom(fontName, size: size)
        } else {
            .system(size: size, weight: .regular)
        }
    }

    private func startMovementTimer() {
        // Create a new timer with the correct interval
        movementTimer = Timer.publish(every: configuration.movementInterval, on: .main, in: .common).autoconnect()
        isTimerActive = true
    }

    private func stopMovementTimer() {
        isTimerActive = false
        animationTask?.cancel()
        animationTask = nil
        movementTimer.upstream.connect().cancel()
    }

    private func currentLayout(for date: Date, size: CGSize, fontName: String?) -> ScreenSaverTextLayout {
        ScreenSaverLayoutCalculator.layout(
            containerSize: size,
            configuration: configuration,
            dateText: configuration.showsDate ? dateString(for: date) : nil,
            timeText: configuration.showsTime ? timeString(for: date) : nil,
            fontName: fontName
        )
    }

    private func randomAnchor() -> CGPoint {
        CGPoint(x: CGFloat.random(in: 0 ... 1), y: CGFloat.random(in: 0 ... 1))
    }

    private func validatedFontName() -> String? {
        guard let fontName = configuration.fontName else {
            return nil
        }

        guard isFontAvailable(fontName) else {
            Logger.screenSaver.warning("Custom font '\(fontName)' not found. Falling back to system font.")
            return nil
        }

        return fontName
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
