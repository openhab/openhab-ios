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

@testable import openHABWatch
import Testing

@MainActor
private final class Recorder {
    var values: [Int] = []
}

@MainActor
struct AsyncStreamDebounceTests {
    @Test("Runs the action only for the last value of a burst", .timeLimit(.minutes(1)))
    func keepsLastValueOfBurst() async throws {
        let (values, continuation) = AsyncStream.makeStream(of: Int.self)
        let recorder = Recorder()
        let consumer = Task { @MainActor in
            await values.debounce(for: .milliseconds(50)) { recorder.values.append($0) }
        }

        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        try await Task.sleep(for: .milliseconds(500))

        #expect(recorder.values == [3])
        continuation.finish()
        await consumer.value
    }

    @Test("Runs the action for each value that stays unchanged for the interval", .timeLimit(.minutes(1)))
    func runsSeparatedValues() async throws {
        let (values, continuation) = AsyncStream.makeStream(of: Int.self)
        let recorder = Recorder()
        let consumer = Task { @MainActor in
            await values.debounce(for: .milliseconds(50)) { recorder.values.append($0) }
        }

        continuation.yield(1)
        try await Task.sleep(for: .milliseconds(500))
        continuation.yield(2)
        try await Task.sleep(for: .milliseconds(500))

        #expect(recorder.values == [1, 2])
        continuation.finish()
        await consumer.value
    }

    @Test("Cancelling the calling task drops the pending action", .timeLimit(.minutes(1)))
    func cancellationDropsPendingAction() async throws {
        let (values, continuation) = AsyncStream.makeStream(of: Int.self)
        let recorder = Recorder()
        let consumer = Task { @MainActor in
            await values.debounce(for: .milliseconds(300)) { recorder.values.append($0) }
        }

        continuation.yield(1)
        // Let the consumer receive the value and start its delay.
        try await Task.sleep(for: .milliseconds(50))
        consumer.cancel()
        await consumer.value
        try await Task.sleep(for: .milliseconds(600))

        #expect(recorder.values.isEmpty)
    }
}
