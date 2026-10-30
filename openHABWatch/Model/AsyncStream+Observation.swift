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

import Observation

@MainActor
private final class ObservationTracker<Value: Equatable & Sendable> {
    private let read: @MainActor () -> Value
    private let continuation: AsyncStream<Value>.Continuation
    private var last: Value?
    private var isFinished = false

    init(read: @escaping @MainActor () -> Value, continuation: AsyncStream<Value>.Continuation) {
        self.read = read
        self.continuation = continuation
    }

    /// Reads the value and registers for its next change. `onChange` fires in `willSet`, before
    /// the new value is stored, so the re-read happens in a later main-actor task.
    func track() {
        // Stops a re-read that was already queued when the stream terminated.
        guard !isFinished else { return }
        // Weak, so a registration that never fires again doesn't keep the tracker, `read` and the
        // observed model alive after the stream has terminated.
        let value = withObservationTracking {
            read()
        } onChange: { [weak self] in
            Task { @MainActor in self?.track() }
        }
        guard value != last else { return }
        last = value
        continuation.yield(value)
    }

    func finish() {
        isFinished = true
    }
}

extension AsyncStream where Element: Equatable & Sendable {
    /// Bridges `withObservationTracking` to a stream, like `Observations` does from watchOS 26 on.
    ///
    /// The stream emits the current value of `read`, then every distinct value after a change to an
    /// observable property that `read` accesses. Ending the iteration, including by cancelling the
    /// iterating task, finishes the stream; `onChange` only yields and re-registers, so nothing has
    /// to be resumed exactly once.
    @MainActor
    static func observing(_ read: @escaping @MainActor () -> Element) -> AsyncStream<Element> {
        let (stream, continuation) = makeStream(bufferingPolicy: .bufferingNewest(1))
        let tracker = ObservationTracker(read: read, continuation: continuation)
        // The only strong reference to the tracker. The stream keeps this handler until it
        // terminates and releases it after calling it, so the tracker lives as long as the stream.
        continuation.onTermination = { _ in
            Task { @MainActor in tracker.finish() }
        }
        tracker.track()
        return stream
    }
}

extension AsyncStream where Element: Sendable {
    /// Runs `action` with each element that is not followed by another within `interval`.
    /// Returns when the stream ends, which cancelling the calling task causes.
    @MainActor
    func debounce(for interval: Duration, _ action: @escaping @MainActor (Element) async -> Void) async {
        var pending: Task<Void, Never>?
        for await element in self {
            pending?.cancel()
            pending = Task { @MainActor in
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await action(element)
            }
        }
        pending?.cancel()
    }
}
