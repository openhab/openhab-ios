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

@testable import OpenHABCore
import Testing

private final class TestViewModel: SitemapPageViewModelBase {}

struct SitemapPageViewModelTaskTests {
    @Test @MainActor
    func sameKeyIsNoOpWhenTaskIsRunning() {
        let vm = TestViewModel()
        let first = vm.runNewHandlingTask(key: "k") {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        let second = vm.runNewHandlingTask(key: "k") {}
        #expect(first == true)
        #expect(second == false)
        vm.stopHandling()
    }

    @Test @MainActor
    func differentKeyReplacesRunningTask() {
        let vm = TestViewModel()
        vm.runNewHandlingTask(key: "a") {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        let second = vm.runNewHandlingTask(key: "b") {}
        #expect(second == true)
        #expect(vm.currentHandlingKey == "b")
        vm.stopHandling()
    }

    @Test @MainActor
    func forceRestartsSameKey() {
        let vm = TestViewModel()
        vm.runNewHandlingTask(key: "k") {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        let second = vm.runNewHandlingTask(key: "k", force: true) {}
        #expect(second == true)
        vm.stopHandling()
    }

    @Test @MainActor
    func taskSlotClearedAfterBodyReturns() async throws {
        let vm = TestViewModel()
        vm.runNewHandlingTask(key: "k") { /* returns immediately */ }
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.pageHandlingTask == nil)
        #expect(vm.currentHandlingKey == nil)
    }

    /// When a force-restart replaces a task whose body returns immediately, the first
    /// task's cleanup must not clobber the second task's slot (generation guard).
    @Test @MainActor
    func generationGuardPreventsStaleTaskCleanup() async throws {
        let vm = TestViewModel()
        // T1: immediate body (gen = 1)
        vm.runNewHandlingTask(key: "k") { /* returns immediately */ }
        // T2: long-running; supersedes T1 before either body executes (gen = 2)
        vm.runNewHandlingTask(key: "k", force: true) {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        // Yield so T1's body and its cleanup attempt both run
        try await Task.sleep(nanoseconds: 50_000_000)
        // T1's guard (gen 1 ≠ taskGeneration 2) must not have cleared T2's slot
        #expect(vm.currentHandlingKey == "k")
        vm.stopHandling()
    }
}
