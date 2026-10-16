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

import CommonUI
import CoreText
import Kingfisher
import OpenHABCore
import os.log
import SDWebImageSVGCoder
import SFSafeSymbols
import SwiftUI

/// Framework7 Icons, bundled so `f7:` icons draw offline. The font maps each icon name to one glyph
/// through ligatures, so the name itself is the text to draw.
enum F7IconFont {
    static let fontName: String? = {
        guard let url = Bundle.main.url(forResource: "Framework7Icons-Regular", withExtension: "ttf"),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let name = descriptors.first.flatMap({ CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }) else {
            Logger.viewController.error("Framework7Icons-Regular.ttf is missing from the app bundle")
            return nil
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            // Already registered is fine; anything else leaves the font unusable.
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            if code != CTFontManagerError.alreadyRegistered.rawValue {
                Logger.viewController.error("Could not register Framework7Icons-Regular.ttf")
                return nil
            }
        }
        return name
    }()

    private static let lock = NSLock()
    private nonisolated(unsafe) static var known: [String: Bool] = [:]

    /// True when the font has a glyph for `name`. An unknown name would draw as its letters.
    static func hasIcon(_ name: String) -> Bool {
        guard let fontName else { return false }
        lock.lock()
        defer { lock.unlock() }
        if let cached = known[name] { return cached }
        let font = CTFontCreateWithName(fontName as CFString, 17, nil)
        let text = NSAttributedString(string: name, attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
        let found = CTLineGetGlyphCount(CTLineCreateWithAttributedString(text)) == 1
        known[name] = found
        return found
    }
}

/// Draws an icon sent over the bridge the way Main UI would.
struct OHBridgeIconView: View {
    let icon: OHBridgeIcon?
    var size: CGFloat = 20
    var fallback: SFSymbol = .squareGrid2x2

    var networkTracker = MainActorNetworkTracker.shared

    var body: some View {
        content
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var content: some View {
        if let name = icon?.name, name.hasPrefix("f7:"),
           let fontName = F7IconFont.fontName,
           F7IconFont.hasIcon(String(name.dropFirst(3))) {
            Text(verbatim: String(name.dropFirst(3)))
                .font(.custom(fontName, fixedSize: size))
                .lineLimit(1)
                .fixedSize()
        } else if let name = icon?.name, !name.isEmpty,
                  let url = Self.imageURL(for: name, rootURL: networkTracker.activeConnection?.configuration.url) {
            KFImage(url)
                .withOpenHABCredentials(for: networkTracker.activeConnection)
                .setProcessor(OpenHABImageProcessor())
                .placeholder { fallbackImage }
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let svg = icon?.svg, let image = Self.image(fromSVG: svg) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(systemSymbol: fallback)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    /// `oh:` and bare names come from the server; `material:`, `iconify:` and any `f7:` name the
    /// bundled font lacks come from Iconify, as they do in Main UI.
    static func imageURL(for name: String, rootURL: String?) -> URL? {
        Endpoint.icon(
            rootUrl: rootURL ?? "",
            version: 2,
            icon: name,
            state: nil,
            iconType: .svg,
            iconColor: ""
        )?.url
    }

    private static func image(fromSVG svg: String) -> UIImage? {
        SDImageSVGCoder.shared.decodedImage(with: Data(svg.utf8), options: [.decodeThumbnailPixelSize: CGSize(width: 64, height: 64)])
    }
}
