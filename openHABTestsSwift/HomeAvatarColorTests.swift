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

@testable import openHAB
import SwiftUI
import Testing
import UIKit

// MARK: - Helpers

/// Resolve gamma-corrected sRGB components. Works for fixed sRGB colors in any environment.
private func rgb(_ color: Color, env: EnvironmentValues = EnvironmentValues()) -> (r: Double, g: Double, b: Double) {
    let c = color.resolve(in: env)
    return (Double(c.red), Double(c.green), Double(c.blue))
}

private func approx(_ a: Double, _ b: Double, tol: Double = 0.003) -> Bool {
    abs(a - b) < tol
}

private func hslLightness(_ color: Color, env: EnvironmentValues = EnvironmentValues()) -> Double {
    let (r, g, b) = rgb(color, env: env)
    return (max(r, g, b) + min(r, g, b)) / 2
}

private var lightEnv: EnvironmentValues {
    var e = EnvironmentValues()
    e.colorScheme = .light
    return e
}

private var darkEnv: EnvironmentValues {
    var e = EnvironmentValues()
    e.colorScheme = .dark
    return e
}

// Three test tints covering each lightness zone:
//   darkTint  L ≈ 0.15  < 0.30  (very dark zone)
//   midTint   L ≈ 0.58  in 0.30–0.70  (mid zone)
//   lightTint L ≈ 0.90  > 0.70  (very light zone)
private let darkTint  = Color(hex: "#001A4D")!  // dark navy
private let midTint   = Color(hex: "#3478F6")!  // system blue (palette entry)
private let lightTint = Color(hex: "#FFE8CC")!  // warm peach

// MARK: - hex parsing

// Explicit `Color?` annotations force Swift to pick the failable `openHAB` init
// over `CommonUI`'s non-failable `init(hex:)`, which are both in scope here.
@Suite("Color hex parsing")
struct ColorHexParsingTests {
    @Test("6-digit hex with leading hash")
    func sixDigitWithHash() {
        let c: Color? = Color(hex: "#FF0000")
        #expect(c != nil)
        let (r, g, b) = rgb(c!)
        #expect(approx(r, 1.0))
        #expect(approx(g, 0.0))
        #expect(approx(b, 0.0))
    }

    @Test("6-digit hex without hash")
    func sixDigitWithoutHash() {
        let c: Color? = Color(hex: "00FF00")
        #expect(c != nil)
        let (r, g, b) = rgb(c!)
        #expect(approx(r, 0.0))
        #expect(approx(g, 1.0))
        #expect(approx(b, 0.0))
    }

    @Test("8-digit hex sets alpha; blue component correct")
    func eightDigitHex() {
        let c: Color? = Color(hex: "#0000FFCC")
        #expect(c != nil)
        let (r, g, b) = rgb(c!)
        #expect(approx(r, 0.0))
        #expect(approx(g, 0.0))
        #expect(approx(b, 1.0))
    }

    @Test("Case-insensitive parsing")
    func caseInsensitive() {
        let upper: Color? = Color(hex: "#3478F6")
        let lower: Color? = Color(hex: "#3478f6")
        #expect(upper != nil)
        #expect(lower != nil)
        let (ru, gu, bu) = rgb(upper!)
        let (rl, gl, bl) = rgb(lower!)
        #expect(approx(ru, rl))
        #expect(approx(gu, gl))
        #expect(approx(bu, bl))
    }

    @Test("5-digit hex returns nil")
    func fiveDigitReturnsNil() {
        #expect(Color(hex: "#12345") == nil)
    }

    @Test("7-digit hex returns nil")
    func sevenDigitReturnsNil() {
        #expect(Color(hex: "#1234567") == nil)
    }

    @Test("Empty string returns nil")
    func emptyStringReturnsNil() {
        #expect(Color(hex: "") == nil)
    }

    @Test("Non-hex characters return nil")
    func nonHexCharactersReturnNil() {
        #expect(Color(hex: "#GGGGGG") == nil)
        #expect(Color(hex: "red") == nil)
    }

    @Test("Black and white parse correctly")
    func blackAndWhite() {
        let (br, bg, bb) = rgb(Color(hex: "#000000")!)
        let (wr, wg, wb) = rgb(Color(hex: "#FFFFFF")!)
        #expect(approx(br, 0.0) && approx(bg, 0.0) && approx(bb, 0.0))
        #expect(approx(wr, 1.0) && approx(wg, 1.0) && approx(wb, 1.0))
    }
}

// MARK: - hexString round-trip

@Suite("Color hexString round-trip")
@MainActor
struct ColorHexStringTests {
    @Test("Pure primaries round-trip without loss")
    func primariesRoundTrip() {
        for hex in ["#FF0000", "#00FF00", "#0000FF", "#000000", "#FFFFFF"] {
            let result = Color(hex: hex)!.hexString
            #expect(result == hex, "Expected \(hex), got \(result)")
        }
    }

    @Test("All palette colors round-trip")
    func paletteRoundTrip() {
        for hex in HomeAvatarView.colorPalette {
            let result = Color(hex: hex)!.hexString
            #expect(result == hex, "Palette round-trip failed: expected \(hex), got \(result)")
        }
    }
}

// MARK: - circleFillColor + iconForegroundColor (6-branch, 3 zones)

// Three lightness zones — dark env / light env:
//   L < 0.30  → lightened circle / full icon  |  full circle / lightened icon
//   mid       → full circle     / darkened     |  full circle / lightened icon
//   L > 0.70  → full circle     / darkened     |  darkened circle / full icon

@Suite("Avatar color pair — six branches (3 zones)")
@MainActor
struct AvatarColorPairTests {

    // MARK: Branch 1 — dark env + dark tint

    @Test("dark env + dark tint: circle is lightened")
    func darkEnvDarkTintCircleLightened() {
        let circle = darkTint.circleFillColor(in: darkEnv)
        #expect(hslLightness(circle) > hslLightness(darkTint))
    }

    @Test("dark env + dark tint: icon is full tint")
    func darkEnvDarkTintIconIsFull() {
        let icon = darkTint.iconForegroundColor(in: darkEnv)
        let (tr, tg, tb) = rgb(darkTint)
        let (ir, ig, ib) = rgb(icon)
        #expect(approx(tr, ir) && approx(tg, ig) && approx(tb, ib))
    }

    // MARK: Branch 2 — light env + dark tint

    @Test("light env + dark tint: circle is full tint")
    func lightEnvDarkTintCircleIsFull() {
        let circle = darkTint.circleFillColor(in: lightEnv)
        let (tr, tg, tb) = rgb(darkTint)
        let (cr, cg, cb) = rgb(circle)
        #expect(approx(tr, cr) && approx(tg, cg) && approx(tb, cb))
    }

    @Test("light env + dark tint: icon is lightened")
    func lightEnvDarkTintIconLightened() {
        let icon = darkTint.iconForegroundColor(in: lightEnv)
        #expect(hslLightness(icon) > hslLightness(darkTint))
    }

    // MARK: Branch 3 — dark env + light tint

    @Test("dark env + light tint: circle is full tint")
    func darkEnvLightTintCircleIsFull() {
        let circle = lightTint.circleFillColor(in: darkEnv)
        let (tr, tg, tb) = rgb(lightTint)
        let (cr, cg, cb) = rgb(circle)
        #expect(approx(tr, cr) && approx(tg, cg) && approx(tb, cb))
    }

    @Test("dark env + light tint: icon is darkened")
    func darkEnvLightTintIconDarkened() {
        let icon = lightTint.iconForegroundColor(in: darkEnv)
        #expect(hslLightness(icon) < hslLightness(lightTint))
    }

    // MARK: Branch 4 — light env + light tint

    @Test("light env + light tint: circle is darkened")
    func lightEnvLightTintCircleDarkened() {
        let circle = lightTint.circleFillColor(in: lightEnv)
        #expect(hslLightness(circle) < hslLightness(lightTint))
    }

    @Test("light env + light tint: icon is full tint")
    func lightEnvLightTintIconIsFull() {
        let icon = lightTint.iconForegroundColor(in: lightEnv)
        let (tr, tg, tb) = rgb(lightTint)
        let (ir, ig, ib) = rgb(icon)
        #expect(approx(tr, ir) && approx(tg, ig) && approx(tb, ib))
    }

    // MARK: Branch 5 — dark env + mid tint

    @Test("dark env + mid tint: circle is full tint")
    func darkEnvMidTintCircleIsFull() {
        let circle = midTint.circleFillColor(in: darkEnv)
        let (tr, tg, tb) = rgb(midTint)
        let (cr, cg, cb) = rgb(circle)
        #expect(approx(tr, cr) && approx(tg, cg) && approx(tb, cb))
    }

    @Test("dark env + mid tint: icon is darkened")
    func darkEnvMidTintIconDarkened() {
        let icon = midTint.iconForegroundColor(in: darkEnv)
        #expect(hslLightness(icon) < hslLightness(midTint))
    }

    // MARK: Branch 6 — light env + mid tint

    @Test("light env + mid tint: circle is full tint")
    func lightEnvMidTintCircleIsFull() {
        let circle = midTint.circleFillColor(in: lightEnv)
        let (tr, tg, tb) = rgb(midTint)
        let (cr, cg, cb) = rgb(circle)
        #expect(approx(tr, cr) && approx(tg, cg) && approx(tb, cb))
    }

    @Test("light env + mid tint: icon is lightened")
    func lightEnvMidTintIconLightened() {
        let icon = midTint.iconForegroundColor(in: lightEnv)
        #expect(hslLightness(icon) > hslLightness(midTint))
    }

    // MARK: Complementarity invariant

    @Test("circleFill and iconForeground are always different (contrast guaranteed)")
    func circleFillAndIconAlwaysDiffer() {
        for env in [lightEnv, darkEnv] {
            for hex in HomeAvatarView.colorPalette {
                let tint = Color(hex: hex)!
                let circle = tint.circleFillColor(in: env)
                let icon = tint.iconForegroundColor(in: env)
                let (cr, cg, cb) = rgb(circle)
                let (ir, ig, ib) = rgb(icon)
                let same = approx(cr, ir, tol: 0.02)
                        && approx(cg, ig, tol: 0.02)
                        && approx(cb, ib, tol: 0.02)
                let modeLabel = (env.colorScheme == .dark) ? "dark" : "light"
                #expect(!same, "Circle == icon for \(hex) in \(modeLabel) mode — no contrast")
            }
        }
    }

    @Test("Exactly one of the pair is always the full tint")
    func exactlyOneIsFull() {
        // The two functions are exact complements: when circleFill == self, iconFg != self, and vice versa.
        for env in [lightEnv, darkEnv] {
            for hex in HomeAvatarView.colorPalette {
                let tint = Color(hex: hex)!
                let (tr, tg, tb) = rgb(tint)
                let (cr, cg, cb) = rgb(tint.circleFillColor(in: env))
                let (ir, ig, ib) = rgb(tint.iconForegroundColor(in: env))
                let circleIsFull = approx(cr, tr) && approx(cg, tg) && approx(cb, tb)
                let iconIsFull   = approx(ir, tr) && approx(ig, tg) && approx(ib, tb)
                // Exactly one must be full (XOR)
                #expect(circleIsFull != iconIsFull,
                    "Both or neither are full tint for \(hex) — complement invariant broken")
            }
        }
    }

    // MARK: Hue preservation

    @Test("Lightening preserves hue direction")
    func lighteningPreservesHue() {
        // dark env + dark tint → circle is lightened; blue should remain dominant
        let navy = Color(.sRGB, red: 0, green: 0.1, blue: 0.3)
        let circle = navy.circleFillColor(in: darkEnv)
        let (_, cg, cb) = rgb(circle)
        #expect(cb > cg) // blue-dominant preserved after lifting
    }

    @Test("Darkening preserves R:G:B ratio")
    func darkeningPreservesHue() {
        // light env + very light tint (L > 0.7) → circle is darkened; ratio must be preserved.
        // warmTint: L = (1.0 + 0.5) / 2 = 0.75
        let warmTint = Color(.sRGB, red: 1.0, green: 0.85, blue: 0.5)
        let circle = warmTint.circleFillColor(in: lightEnv)
        let (cr, cg, _) = rgb(circle)
        // All channels scaled by 0.3, so R:G ratio preserved
        #expect(approx(cr / cg, 1.0 / 0.85, tol: 0.01))
    }
}
