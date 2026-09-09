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

// MARK: - Test helpers

private struct TestError: Error {}

/// Creates a service with SSE and notification observation disabled (no real network needed).
/// Retry backoff is zeroed out so async tests don't sleep.
@MainActor
private func makeService(retries: Int = 0) -> NotificationActionService {
    let svc = NotificationActionService(autoStart: false)
    svc.maxRetryCount = retries
    svc.retryBackoffBase = 0
    return svc
}

// MARK: - Suite

@Suite("NotificationActionService")
@MainActor
struct NotificationActionServiceTests {

    // MARK: - Navigation commands (synchronous dispatch)

    @Test("sitemap ui action sets navigationCommand for sitemap root")
    func uiSitemapRoot() {
        let svc = makeService()
        svc.handleNotificationInternal("ui:/basicui/app?sitemap=demo")
        #expect(svc.navigationCommand == .switchToSitemap(name: "demo", widgetId: nil))
    }

    @Test("sitemap ui action sets navigationCommand with widgetId")
    func uiSitemapWithWidget() {
        let svc = makeService()
        svc.handleNotificationInternal("ui:/basicui/app?sitemap=demo&w=0001")
        #expect(svc.navigationCommand == .switchToSitemap(name: "demo", widgetId: "0001"))
    }

    @Test("absolute path ui action sets switchToWebView navigationCommand")
    func uiAbsolutePath() {
        let svc = makeService()
        svc.handleNotificationInternal("ui:/some/path")
        #expect(svc.navigationCommand == .switchToWebView(path: "/some/path"))
    }

    @Test("non-path ui command sets switchToWebView with raw command string")
    func uiRawCommand() {
        let svc = makeService()
        svc.handleNotificationInternal("ui:navigate:/page/my_page")
        #expect(svc.navigationCommand == .switchToWebView(path: "navigate:/page/my_page"))
    }

    @Test("nil action string does nothing")
    func nilActionNoOp() {
        let svc = makeService()
        svc.handleNotificationInternal(nil)
        #expect(svc.navigationCommand == nil)
    }

    @Test("unknown prefix does nothing")
    func unknownPrefixNoOp() {
        let svc = makeService()
        svc.handleNotificationInternal("unknown:something")
        #expect(svc.navigationCommand == nil)
    }

    // MARK: - sendCommand dispatch

    @Test("command action calls commandSender with correct item and command")
    func sendCommandDispatch() async {
        let svc = makeService(retries: 0)
        var capturedItem: String?
        var capturedCommand: String?
        svc.commandSender = { item, command, _ in
            capturedItem = item
            capturedCommand = command
        }

        svc.handleNotificationInternal("command:KitchenLights:ON")
        await Task.yield()

        #expect(capturedItem == "KitchenLights")
        #expect(capturedCommand == "ON")
    }

    @Test("command action passes colon-containing value intact")
    func sendCommandColonInValue() async {
        let svc = makeService(retries: 0)
        var capturedCommand: String?
        svc.commandSender = { _, command, _ in capturedCommand = command }

        svc.handleNotificationInternal("command:myItem:2024-01-01T10:15:30")
        await Task.yield()

        #expect(capturedCommand == "2024-01-01T10:15:30")
    }

    // MARK: - executeRule dispatch

    @Test("rule action calls ruleSender with UUID and no properties")
    func ruleDispatchNoProps() async {
        let svc = makeService(retries: 0)
        var capturedUUID: String?
        var capturedProps: [String: String]?
        svc.ruleSender = { uuid, props in
            capturedUUID = uuid
            capturedProps = props
        }

        svc.handleNotificationInternal("rule:02ffc3a297")
        await Task.yield()

        #expect(capturedUUID == "02ffc3a297")
        #expect(capturedProps == [:])
    }

    @Test("rule action calls ruleSender with UUID and parsed properties")
    func ruleDispatchWithProps() async {
        let svc = makeService(retries: 0)
        var capturedUUID: String?
        var capturedProps: [String: String]?
        svc.ruleSender = { uuid, props in
            capturedUUID = uuid
            capturedProps = props
        }

        svc.handleNotificationInternal("rule:02ffc3a297:prop1=foo,prop2=bar")
        await Task.yield()

        #expect(capturedUUID == "02ffc3a297")
        #expect(capturedProps == ["prop1": "foo", "prop2": "bar"])
    }

    // MARK: - Device commands (synchronous dispatch via NotificationCenter)

    @Test("device:screensaver:activate posts activateScreenSaver notification")
    func screensaverActivate() {
        let svc = makeService()
        var received = false
        let token = NotificationCenter.default.addObserver(forName: .activateScreenSaver, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { received = true }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        svc.handleNotificationInternal("device:screensaver:activate")

        #expect(received)
    }

    @Test("device:screensaver:disable posts disableScreenSaver notification")
    func screensaverDisable() {
        let svc = makeService()
        var received = false
        let token = NotificationCenter.default.addObserver(forName: .disableScreenSaver, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { received = true }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        svc.handleNotificationInternal("device:screensaver:disable")

        #expect(received)
    }

    @Test("device:screensaver:wake posts wakeScreenSaver notification")
    func screensaverWake() {
        let svc = makeService()
        var received = false
        let token = NotificationCenter.default.addObserver(forName: .wakeScreenSaver, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { received = true }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        svc.handleNotificationInternal("device:screensaver:wake")

        #expect(received)
    }

    @Test("device:idleTimer:disable disables idle timer")
    func idleTimerDisable() {
        let svc = makeService()
        IdleTimerService.shared.isDisabled = false
        svc.handleNotificationInternal("device:idleTimer:disable")
        #expect(IdleTimerService.shared.isDisabled == true)
    }

    @Test("device:idleTimer:enable enables idle timer")
    func idleTimerEnable() {
        let svc = makeService()
        IdleTimerService.shared.isDisabled = true
        svc.handleNotificationInternal("device:idleTimer:enable")
        #expect(IdleTimerService.shared.isDisabled == false)
    }

    // MARK: - withRetry

    @Test("withRetry succeeds immediately when operation does not throw")
    func withRetryImmediateSuccess() async throws {
        let svc = makeService()
        var callCount = 0
        try await svc.withRetry { callCount += 1 }
        #expect(callCount == 1)
    }

    @Test("withRetry calls operation maxRetryCount+1 times before throwing")
    func withRetryExhaustRetries() async {
        let svc = makeService()
        svc.maxRetryCount = 2 // 1 initial + 2 retries = 3 total
        var callCount = 0

        do {
            try await svc.withRetry {
                callCount += 1
                throw TestError()
            }
            Issue.record("Expected TestError to be thrown")
        } catch is TestError {
            #expect(callCount == 3)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("withRetry succeeds on the nth attempt without exhausting retries")
    func withRetrySucceedsEventually() async throws {
        let svc = makeService()
        svc.maxRetryCount = 3
        var callCount = 0

        try await svc.withRetry {
            callCount += 1
            if callCount < 3 { throw TestError() }
        }

        #expect(callCount == 3)
    }

    @Test("withRetry throws the last error when all attempts fail")
    func withRetryThrowsLastError() async {
        let svc = makeService()
        svc.maxRetryCount = 2
        var callCount = 0

        do {
            try await svc.withRetry {
                callCount += 1
                throw NSError(domain: "test", code: callCount)
            }
            Issue.record("Expected error")
        } catch let error as NSError {
            #expect(callCount == 3)
            #expect(error.code == 3) // last attempt's error code
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("withRetry propagates CancellationError without retrying")
    func withRetryCancellationPropagates() async {
        let svc = makeService()
        svc.maxRetryCount = 3
        var callCount = 0

        do {
            try await svc.withRetry {
                callCount += 1
                throw CancellationError()
            }
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            #expect(callCount == 1) // cancelled immediately, no retries
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - commandSender retry integration

    @Test("sendCommand retries commandSender on failure and succeeds eventually")
    func sendCommandRetrySuccess() async {
        let svc = makeService(retries: 2)
        var callCount = 0
        svc.commandSender = { _, _, _ in
            callCount += 1
            if callCount < 3 { throw NetworkTrackerError.noActiveConnection }
        }

        svc.handleNotificationInternal("command:item:ON")

        // Allow up to (retries + 1) Task.yield cycles for the spawned task plus retry delays.
        for _ in 0..<20 { await Task.yield() }

        #expect(callCount == 3)
    }

    @Test("sendCommand calls commandSender exactly once when it succeeds first try")
    func sendCommandSingleAttempt() async {
        let svc = makeService(retries: 2)
        var callCount = 0
        svc.commandSender = { _, _, _ in callCount += 1 }

        svc.handleNotificationInternal("command:item:ON")
        await Task.yield()

        #expect(callCount == 1)
    }
}
