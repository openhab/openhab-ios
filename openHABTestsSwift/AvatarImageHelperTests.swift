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
import Testing
import UIKit

@Suite("AvatarImageHelper")
@MainActor
struct AvatarImageHelperTests {
    // MARK: - Downscale logic

    @Test("Image within bounds is returned unchanged")
    func imageWithinBoundsUnchanged() {
        let img = makeImage(width: 100, height: 100)
        let result = AvatarImageHelper.downscale(img, maxSize: CGSize(width: 200, height: 200))
        #expect(result.size == CGSize(width: 100, height: 100))
    }

    @Test("Image exactly at bounds is returned unchanged")
    func imageAtBoundsUnchanged() {
        let img = makeImage(width: 500, height: 500)
        let result = AvatarImageHelper.downscale(img, maxSize: CGSize(width: 500, height: 500))
        #expect(result.size == CGSize(width: 500, height: 500))
    }

    @Test("Oversized square image is scaled down uniformly")
    func oversizedSquareScaledDown() {
        let img = makeImage(width: 2000, height: 2000)
        let result = AvatarImageHelper.downscale(img, maxSize: CGSize(width: 1000, height: 1000))
        #expect(result.size.width <= 1000)
        #expect(result.size.height <= 1000)
        #expect(abs(result.size.width - result.size.height) < 1)
    }

    @Test("Wide landscape image is constrained by width")
    func wideLandscapeConstrainedByWidth() {
        let img = makeImage(width: 4000, height: 1000)
        let result = AvatarImageHelper.downscale(img, maxSize: CGSize(width: 2000, height: 2000))
        #expect(result.size.width <= 2000)
        #expect(result.size.height <= 2000)
        let aspectInput = Double(4000) / Double(1000)
        let aspectOutput = Double(result.size.width) / Double(result.size.height)
        #expect(abs(aspectInput - aspectOutput) < 0.01)
    }

    @Test("Tall portrait image is constrained by height")
    func tallPortraitConstrainedByHeight() {
        let img = makeImage(width: 1000, height: 4000)
        let result = AvatarImageHelper.downscale(img, maxSize: CGSize(width: 2000, height: 2000))
        #expect(result.size.width <= 2000)
        #expect(result.size.height <= 2000)
    }

    // MARK: - Save / load round-trip

    @Test("Save then load returns a non-nil image")
    func saveLoadRoundTrip() throws {
        let homeId = UUID()
        defer { AvatarImageHelper.delete(for: homeId) }

        let data = try #require(makeImage(width: 64, height: 64).jpegData(compressionQuality: 0.9))
        let saved = AvatarImageHelper.save(data, for: homeId)
        #expect(saved != nil)

        let loaded = AvatarImageHelper.load(for: homeId)
        #expect(loaded != nil)
    }

    @Test("Deterministic URL can be used with load(atPath:)")
    func pathMatchesStoredFile() throws {
        let homeId = UUID()
        defer { AvatarImageHelper.delete(for: homeId) }

        let data = try #require(makeImage(width: 64, height: 64).jpegData(compressionQuality: 0.9))
        let saved = AvatarImageHelper.save(data, for: homeId)
        #expect(saved != nil)

        let path = AvatarImageHelper.avatarURL(for: homeId).path
        let loaded = AvatarImageHelper.load(atPath: path)
        #expect(loaded != nil)
    }

    @Test("Delete removes the file")
    func deleteRemovesFile() throws {
        let homeId = UUID()
        let data = try #require(makeImage(width: 64, height: 64).jpegData(compressionQuality: 0.9))
        let saved = AvatarImageHelper.save(data, for: homeId)
        #expect(saved != nil)

        AvatarImageHelper.delete(for: homeId)
        #expect(AvatarImageHelper.load(for: homeId) == nil)
    }

    @Test("load(atPath:) with nil returns nil")
    func loadNilPathReturnsNil() {
        #expect(AvatarImageHelper.load(atPath: nil) == nil)
    }

    // MARK: - Helper

    private func makeImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
