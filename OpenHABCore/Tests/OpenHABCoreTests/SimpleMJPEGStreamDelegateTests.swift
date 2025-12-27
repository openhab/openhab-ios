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

import Foundation
@testable import OpenHABCore
import Testing
import UIKit

@MainActor
struct SimpleMJPEGStreamDelegateTests {
    // MARK: - Helpers

    /// Create a tiny valid JPEG so that UIImage(data:) succeeds.
    private func makeTestJPEG(color: UIColor = .red,
                              size: CGSize = CGSize(width: 2, height: 2)) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        // We expect this to always succeed in tests.
        return image.jpegData(compressionQuality: 1.0) ?? Data()
    }

    /// Dummy URLSession + task – we never start it, we just need instances for the delegate API.
    private func makeDummyTask() -> (URLSession, URLSessionDataTask) {
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        let url = URL(string: "https://example.com/mjpeg")!
        let task = session.dataTask(with: url)
        return (session, task)
    }

    /// Provide any valid ConnectionConfiguration for tests.
    /// This is a test fixture that doesn't require external dependencies.
    private func makeTestConnectionConfiguration() -> ConnectionConfiguration {
        ConnectionConfiguration(
            url: "https://example.com",
            username: "testuser",
            password: "testpass"
        )
    }

    // MARK: - Tests

    /// Verifies that a frame is emitted when a second JPEG header arrives,
    /// and that the first emitted frame is marked as `isFirst == true`.
    @Test
    func emitsFirstFrameWhenSecondHeaderArrives() async throws {
        let jpeg1 = makeTestJPEG(color: .red)
        let jpeg2 = makeTestJPEG(color: .blue)

        var receivedFrames: [(image: UIImage, isFirst: Bool)] = []
        var receivedErrors: [Error] = []

        let delegate = SimpleMJPEGStreamDelegate(
            connectionConfiguration: makeTestConnectionConfiguration(),
            onFrame: { image, isFirst in
                receivedFrames.append((image, isFirst))
            },
            onError: { error in
                receivedErrors.append(error)
            }
        )

        let (session, task) = makeDummyTask()

        // First chunk: first frame – no callback yet, only buffer fill.
        delegate.urlSession(session, dataTask: task, didReceive: jpeg1)

        // Second chunk: second frame – should trigger emission of first frame.
        delegate.urlSession(session, dataTask: task, didReceive: jpeg2)

        // Allow the Task { @MainActor in ... } to run
        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms

        #expect(receivedErrors.isEmpty)
        #expect(receivedFrames.count == 1)

        let firstFrame = receivedFrames[0]
        #expect(firstFrame.isFirst == true)
        #expect(firstFrame.image.size.width > 0)
        #expect(firstFrame.image.size.height > 0)
    }

    /// Verifies that a single frame can be built from multiple chunks,
    /// and is only emitted when the *next* header arrives.
    @Test
    func accumulatesSingleFrameAcrossMultipleChunks() async throws {
        let jpeg1 = makeTestJPEG(color: .red)
        let jpeg2 = makeTestJPEG(color: .blue)

        // Split first JPEG into two pieces.
        let splitIndex = jpeg1.count / 2
        let chunk1 = jpeg1.prefix(splitIndex) // starts with 0xFF, 0xD8
        let chunk2 = jpeg1.suffix(from: jpeg1.index(
            jpeg1.startIndex,
            offsetBy: splitIndex
        )) // rest

        var receivedFrames: [(image: UIImage, isFirst: Bool)] = []

        let delegate = SimpleMJPEGStreamDelegate(
            connectionConfiguration: makeTestConnectionConfiguration(),
            onFrame: { image, isFirst in
                receivedFrames.append((image, isFirst))
            },
            onError: { _ in }
        )

        let (session, task) = makeDummyTask()

        // First chunk: header + part of JPEG1 -> starts a new frame.
        delegate.urlSession(session, dataTask: task, didReceive: Data(chunk1))

        // Second chunk: rest of JPEG1 -> appended to current frame.
        delegate.urlSession(session, dataTask: task, didReceive: Data(chunk2))

        // Third chunk: JPEG2 (starts with header) -> should finalize JPEG1.
        delegate.urlSession(session, dataTask: task, didReceive: jpeg2)

        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms

        #expect(receivedFrames.count == 1)
        #expect(receivedFrames[0].isFirst == true)
    }

    /// Verifies that only the first emitted frame has `isFirst == true`,
    /// subsequent frames should have `isFirst == false`.
    @Test
    func marksOnlyFirstEmittedFrameAsFirst() async throws {
        let jpeg1 = makeTestJPEG(color: .red)
        let jpeg2 = makeTestJPEG(color: .green)
        let jpeg3 = makeTestJPEG(color: .blue)

        var isFirstFlags: [Bool] = []

        let delegate = SimpleMJPEGStreamDelegate(
            connectionConfiguration: makeTestConnectionConfiguration(),
            onFrame: { _, isFirst in
                isFirstFlags.append(isFirst)
            },
            onError: { _ in }
        )

        let (session, task) = makeDummyTask()

        // jpeg1 fills buffer.
        delegate.urlSession(session, dataTask: task, didReceive: jpeg1)
        // jpeg2 triggers emission of frame1 (isFirst == true).
        delegate.urlSession(session, dataTask: task, didReceive: jpeg2)
        // jpeg3 triggers emission of frame2 (isFirst == false).
        delegate.urlSession(session, dataTask: task, didReceive: jpeg3)

        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms

        // We expect 2 emitted frames: from jpeg1 and jpeg2.
        #expect(isFirstFlags == [true, false])
    }

    /// Verifies that non-JPEG data before the first header does not
    /// result in a frame being emitted, and that only the first
    /// valid JPEG frame is considered the first frame.
    @Test
    func ignoresInvalidDataBeforeFirstValidFrame() async throws {
        let junk = Data([0x00, 0x11, 0x22, 0x33]) // does not start with 0xFF,0xD8
        let jpeg1 = makeTestJPEG(color: .red)
        let jpeg2 = makeTestJPEG(color: .blue)

        var receivedFrames: [(image: UIImage, isFirst: Bool)] = []

        let delegate = SimpleMJPEGStreamDelegate(
            connectionConfiguration: makeTestConnectionConfiguration(),
            onFrame: { image, isFirst in
                receivedFrames.append((image, isFirst))
            },
            onError: { _ in }
        )

        let (session, task) = makeDummyTask()

        // First chunk: junk – appended to imageData, but will not decode as UIImage.
        delegate.urlSession(session, dataTask: task, didReceive: junk)

        // Second chunk: first valid JPEG – starts a new frame; no emission yet.
        delegate.urlSession(session, dataTask: task, didReceive: jpeg1)

        // Third chunk: second JPEG – triggers emission of JPEG1 frame.
        delegate.urlSession(session, dataTask: task, didReceive: jpeg2)

        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms

        #expect(receivedFrames.count == 1)
        #expect(receivedFrames[0].isFirst == true)
    }
}
