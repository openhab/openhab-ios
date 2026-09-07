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
import OpenHABCore
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

    @Test("saveOriginal then loadOriginal returns a non-nil image")
    func saveLoadOriginalRoundTrip() {
        let homeId = UUID()
        defer { AvatarImageHelper.deleteOriginal(for: homeId) }

        let img = makeImage(width: 64, height: 64)
        AvatarImageHelper.saveOriginal(img, for: homeId)
        let loaded = AvatarImageHelper.loadOriginal(for: homeId)
        #expect(loaded != nil)
    }

    @Test("deleteOriginal removes the file")
    func deleteOriginalRemovesFile() {
        let homeId = UUID()
        AvatarImageHelper.saveOriginal(makeImage(width: 64, height: 64), for: homeId)
        AvatarImageHelper.deleteOriginal(for: homeId)
        #expect(AvatarImageHelper.loadOriginal(for: homeId) == nil)
    }

    @Test("originalURL uses deterministic path")
    func originalURLIsDeterministic() {
        let homeId = UUID()
        let url1 = AvatarImageHelper.originalURL(for: homeId)
        let url2 = AvatarImageHelper.originalURL(for: homeId)
        #expect(url1 == url2)
        #expect(url1.lastPathComponent == "avatarImage.jpg")
    }

    // MARK: - renderCrop

    @Test("renderCrop with icon mode returns nil")
    func renderCropIconModeNil() {
        let img = makeImage(width: 100, height: 100)
        let mode = AvatarMode.icon(name: "house.fill", color: "#3478F6")
        let result = AvatarImageHelper.renderCrop(original: img, mode: mode)
        #expect(result == nil)
    }

    @Test("renderCrop with image mode returns 280×280")
    func renderCropImageModeSize() {
        let img = makeImage(width: 500, height: 500)
        let mode = AvatarMode.image(originX: 0, originY: 0, size: 500, background: "#3478F6")
        let result = AvatarImageHelper.renderCrop(original: img, mode: mode)
        #expect(result != nil)
        #expect(result?.size == CGSize(width: 280, height: 280))
    }

    @Test("renderedAvatar returns nil for icon mode")
    func renderedAvatarNilForIcon() {
        let homeId = UUID()
        let mode = AvatarMode.icon(name: "house.fill", color: "#3478F6")
        let result = AvatarImageHelper.renderedAvatar(for: homeId, mode: mode)
        #expect(result == nil)
    }

    @Test("renderedAvatar returns nil when no original is stored")
    func renderedAvatarNilWhenNoFile() {
        let homeId = UUID()
        let mode = AvatarMode.image(originX: 0, originY: 0, size: 280, background: "#3478F6")
        let result = AvatarImageHelper.renderedAvatar(for: homeId, mode: mode)
        #expect(result == nil)
    }

    @Test("renderedAvatar returns non-nil after saving original")
    func renderedAvatarAfterSave() {
        let homeId = UUID()
        defer { AvatarImageHelper.deleteOriginal(for: homeId) }

        let img = makeImage(width: 500, height: 500)
        AvatarImageHelper.saveOriginal(img, for: homeId)
        let mode = AvatarMode.image(originX: 0, originY: 0, size: 500, background: "#3478F6")
        let result = AvatarImageHelper.renderedAvatar(for: homeId, mode: mode)
        #expect(result != nil)
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
