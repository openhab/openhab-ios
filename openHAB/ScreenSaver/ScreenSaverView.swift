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

import UIKit

final class ScreenSaverView: UIView {
    private let configuration: ScreenSaverConfiguration

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0.0 // start invisible
        return label
    }()

    private var movementTimer: Timer?
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()

    init(configuration: ScreenSaverConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        backgroundColor = UIColor.black
        addSubview(label)
        // pin label size but not position (we move it manually)
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9)
        ])

        updateLabelText()
    }

    deinit {
        movementTimer?.invalidate()
    }

    // MARK: - Public API

    func startAnimation() {
        scheduleMovement()
    }

    func stopAnimation() {
        movementTimer?.invalidate()
    }

    // MARK: - Private helpers

    private func scheduleMovement() {
        movementTimer?.invalidate()
        movementTimer = Timer.scheduledTimer(withTimeInterval: configuration.movementInterval, repeats: true) { [weak self] _ in
            self?.moveLabelToRandomPosition(animated: true)
        }
        // perform first move immediately
        moveLabelToRandomPosition(animated: false)
    }

    private func updateLabelText() {
        let now = Date()

        // Prepare strings
        var timeString: String?
        var dateString: String?

        if configuration.showsTime {
            let tf = DateFormatter()
            tf.dateStyle = .none
            if configuration.showsSeconds {
                tf.dateFormat = configuration.uses24HourTime ? "H:mm:ss" : "h:mm:ss a"
            } else {
                tf.dateFormat = configuration.uses24HourTime ? "H:mm" : "h:mm a"
            }
            timeString = tf.string(from: now)
        }

        if configuration.showsDate {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            dateString = df.string(from: now)
        }

        // Compute dynamic font sizes based on the current view size.
        let shortSide = min(bounds.width, bounds.height)
        let timeFontSize = max(shortSide * configuration.timeFontSizeRatio, 48)
        let dateFontSize = timeFontSize * configuration.dateFontRelativeSize

        let timeFont: UIFont = if let name = configuration.fontName, let custom = UIFont(name: name, size: timeFontSize) {
            custom
        } else {
            UIFont.monospacedDigitSystemFont(ofSize: timeFontSize, weight: .thin)
        }

        let dateFont: UIFont = if let name = configuration.fontName, let custom = UIFont(name: name, size: dateFontSize) {
            custom
        } else {
            UIFont.systemFont(ofSize: dateFontSize, weight: .regular)
        }

        let attributed = NSMutableAttributedString()

        // Date above time
        if let dateString {
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            attributed.append(NSAttributedString(string: dateString, attributes: dateAttr))
        }

        if let timeString {
            if attributed.length > 0 {
                attributed.append(NSAttributedString(string: "\n"))
            }
            let timeAttr: [NSAttributedString.Key: Any] = [
                .font: timeFont,
                .foregroundColor: UIColor.white
            ]
            attributed.append(NSAttributedString(string: timeString, attributes: timeAttr))
        }

        label.attributedText = attributed
    }

    private func moveLabelToRandomPosition(animated: Bool) {
        updateLabelText()
        // Ensure layout pass so we know label size
        layoutIfNeeded()

        let labelSize = label.intrinsicContentSize
        guard bounds.width > labelSize.width, bounds.height > labelSize.height else { return }

        let maxX = bounds.width - labelSize.width
        let maxY = bounds.height - labelSize.height

        let randomX = CGFloat.random(in: 0 ... maxX)
        let randomY = CGFloat.random(in: 0 ... maxY)

        let animations = {
            self.label.frame = CGRect(origin: CGPoint(x: randomX, y: randomY), size: labelSize)
        }

        if animated {
            UIView.animate(withDuration: configuration.fadeDuration, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.label.alpha = 0.0
            } completion: { _ in
                animations()
                UIView.animate(withDuration: self.configuration.fadeDuration, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                    self.label.alpha = 1.0
                }
            }
        } else {
            label.alpha = 1.0
            animations()
        }
    }
}
