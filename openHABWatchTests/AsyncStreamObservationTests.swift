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
@testable import openHABWatch
import Testing

@MainActor
@Observable
private final class Counter {
    var value = 0
}

@MainActor
struct AsyncStreamObservationTests {
    @Test("Emits the current value first")
    func emitsInitialValue() async {
        let counter = Counter()
        counter.value = 3
        var iterator = AsyncStream.observing { counter.value }.makeAsyncIterator()

        #expect(await iterator.next() == 3)
    }

    @Test("Emits the value after each change")
    func emitsChanges() async {
        let counter = Counter()
        var iterator = AsyncStream.observing { counter.value }.makeAsyncIterator()
        #expect(await iterator.next() == 0)

        counter.value = 1
        #expect(await iterator.next() == 1)

        counter.value = 2
        #expect(await iterator.next() == 2)
    }

    @Test("Skips a change that leaves the read value equal")
    func skipsEqualValues() async {
        let counter = Counter()
        var iterator = AsyncStream.observing { counter.value > 0 }.makeAsyncIterator()
        #expect(await iterator.next() == false)

        counter.value = 1
        #expect(await iterator.next() == true)

        counter.value = 2
        // The tracker re-reads in a main-actor task queued by this change; let it run first.
        await Task { @MainActor in }.value

        counter.value = 0
        #expect(await iterator.next() == false)
    }

    @Test("Cancelling the iterating task ends the iteration", .timeLimit(.minutes(1)))
    func cancellationEndsIteration() async {
        let counter = Counter()
        let values = AsyncStream.observing { counter.value }
        let consumer = Task { @MainActor in
            var count = 0
            for await _ in values {
                count += 1
            }
            return count
        }
        await Task.yield()

        consumer.cancel()

        // Before the stream, the loop waited in a continuation that cancellation never resumed,
        // so this would hang until the next change of the observed property.
        #expect(await consumer.value <= 1)
    }

    @Test("Cancelling the iterating task releases the observed model", .timeLimit(.minutes(1)))
    func cancellationReleasesObservedModel() async {
        weak var weakCounter: Counter?
        let consumer: Task<Void, Never>
        do {
            let counter = Counter()
            weakCounter = counter
            let values = AsyncStream.observing { counter.value }
            consumer = Task { @MainActor in
                for await _ in values {}
            }
        }
        await Task.yield()

        consumer.cancel()
        await consumer.value
        // Let the main-actor task queued by the termination handler run.
        await Task { @MainActor in }.value

        // The counter never changes again, so its pending registration never fires.
        #expect(weakCounter == nil)
    }
}
