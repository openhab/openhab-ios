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

import SwiftUI

/// Renders a circular home avatar. Shows the custom photo when set;
/// otherwise fills the circle with `color` and overlays `iconName`.
struct HomeAvatarView: View {
    let photo: Image?
    let iconName: String
    let color: Color
    let size: CGFloat
    var isActive: Bool = false

    static let defaultColor = Color(hex: "#3478F6") ?? .blue
    static let defaultIconName = "house.fill"

    static let availableIcons: [String] = [
        "house.fill", "building.2.fill", "house.and.flag.fill", "leaf.fill",
        "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "moon.fill", "drop.fill", "sun.max.fill", "cloud.fill"
    ]

    static let colorPalette: [String] = [
        "#3478F6", "#5856D6", "#AF52DE", "#FF2D55",
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#8E8E93"
    ]

    @Environment(\.self) var environment

    var body: some View {
        Group {
            if let photo {
                photo
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(color.circleFillColor(in: environment))
                    Image(systemName: iconName)
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(color.iconForegroundColor(in: environment))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay {
            if isActive {
                Circle().strokeBorder(.blue, lineWidth: 2)
            }
        }
    }
}

// MARK: - Color ↔ hex helpers

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }
        let r, g, b, a: Double
        if cleaned.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - Avatar color pair
    //
    // Three lightness zones: L < 0.30 (very dark), 0.30–0.70 (mid), L > 0.70 (very light)
    //
    //   Zone   │ dark env                           │ light env
    //   ───────┼────────────────────────────────────┼──────────────────────────────────
    //   < 0.30 │ lightened circle,  full-tint icon  │ full-tint circle,  lightened icon
    //   mid    │ full-tint circle,  darkened icon   │ full-tint circle,  lightened icon
    //   > 0.70 │ full-tint circle,  darkened icon   │ darkened circle,   full-tint icon
    //
    // Circle adapts only when it would blend into the environment (extremes only).
    // Icon is full tint exactly when the circle was adapted; otherwise icon adapts to mode.

    private func avatarLightness(in environment: EnvironmentValues) -> (r: Double, g: Double, b: Double, isDark: Bool, lightness: Double) {
        let c = resolve(in: environment)
        let r = Double(c.red), g = Double(c.green), b = Double(c.blue)
        let L = (max(r, g, b) + min(r, g, b)) / 2
        return (r, g, b, environment.colorScheme == .dark, L)
    }

    /// Circle fill color that contrasts the ambient environment.
    func circleFillColor(in environment: EnvironmentValues) -> Color {
        let (r, g, b, isDark, L) = avatarLightness(in: environment)
        if isDark, L < 0.3 {
            return Color(.sRGB, red: r + (1-r)*0.7, green: g + (1-g)*0.7, blue: b + (1-b)*0.7)
        }
        if !isDark, L > 0.7 {
            return Color(.sRGB, red: r * 0.3, green: g * 0.3, blue: b * 0.3)
        }
        return self
    }

    /// Icon foreground color that contrasts the circle fill.
    func iconForegroundColor(in environment: EnvironmentValues) -> Color {
        let (r, g, b, isDark, L) = avatarLightness(in: environment)
        // Full tint when circle was adapted (complementarity).
        if isDark, L < 0.3 { return self }
        if !isDark, L > 0.7 { return self }
        return isDark
            ? Color(.sRGB, red: r * 0.3, green: g * 0.3, blue: b * 0.3)
            : Color(.sRGB, red: r + (1-r)*0.7, green: g + (1-g)*0.7, blue: b + (1-b)*0.7)
    }

    /// Converts the color to a hex string. Bridges through UIColor because hex serialization
    /// doesn't need environment-aware resolution — we always store concrete sRGB values.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255))
    }
}
