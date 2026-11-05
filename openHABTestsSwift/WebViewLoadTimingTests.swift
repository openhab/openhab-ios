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

import Foundation
@testable import openHAB
import Testing
import WebKit

/// Keeps every mark the script posts.
@MainActor
private final class MarkCollector: NSObject, WKScriptMessageHandler {
    var events: [WebViewLoadTimingEvent] = []

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let event = WebViewLoadTimingEvent(body: message.body) {
            events.append(event)
        }
    }
}

/// Answers the page's requests without a network, so the test doesn't depend on how fast a
/// lookup for a missing host fails.
@MainActor
private final class FakeServer: NSObject, WKURLSchemeHandler {
    static let scheme = "ohtest"

    private let page: String

    init(page: String) {
        self.page = page
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let (status, type, body): (Int, String, String) = switch url.path {
        case "/": (200, "text/html", page)
        case "/rest/items": (200, "application/json", "[]")
        case "/rest/ui/components/ui:page": (200, "application/json", "{}")
        // The connection id, then one update. The stream then ends, which the page sees as an error.
        case "/rest/events/states": (200, "text/event-stream", "event: ready\ndata: c1\n\ndata: {}\n\n")
        default: (404, "text/plain", "")
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": type]) else { return }
        task.didReceive(response)
        // `?drop`: the connection drops after the headers, before any update.
        if url.query == "drop" {
            task.didFailWithError(URLError(.networkConnectionLost))
            return
        }
        task.didReceive(Data(body.utf8))
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

/// A web view with the timing script, as the app installs it.
@MainActor
private final class TimingPage {
    let collector = MarkCollector()
    let webView: WKWebView

    init(page: String) {
        let controller = WKUserContentController()
        controller.add(collector, name: WebViewLoadTiming.messageHandlerName)
        controller.addUserScript(WKUserScript(source: WebViewLoadTiming.script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.setURLSchemeHandler(FakeServer(page: page), forURLScheme: FakeServer.scheme)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
    }

    func load() {
        guard let url = URL(string: "\(FakeServer.scheme)://openhab/") else { return }
        webView.load(URLRequest(url: url))
    }

    /// Waits until `count` marks named `event` have come in.
    func waitForCount(of event: String, _ count: Int) async throws -> Bool {
        for _ in 0 ..< 100 {
            if collector.events.count(where: { $0.event == event }) >= count {
                return true
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("timed out; got \(collector.events.map(\.event))")
        return false
    }

    /// Waits until a mark matching `predicate` has come in.
    func waitForEvent(_ predicate: (WebViewLoadTimingEvent) -> Bool) async throws -> WebViewLoadTimingEvent? {
        for _ in 0 ..< 100 {
            if let event = collector.events.first(where: predicate) {
                return event
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("timed out; got \(collector.events.map(\.event))")
        return nil
    }
}

@Suite("Web view load timing")
@MainActor
struct WebViewLoadTimingTests {
    /// One page for every script check: each web view starts its own web content process, and
    /// the other web view suites time out when too many start at once.
    @Test("Reports the document, REST calls without their query, and the item-state stream")
    func pageMarks() async throws {
        let page = TimingPage(page: """
        <!DOCTYPE html><html><body><script>
          var xhr = new XMLHttpRequest();
          xhr.open('get', '/rest/items?metadata=semantics&accessToken=secret');
          xhr.send();
          fetch('/rest/ui/components/ui:page?accessToken=secret', { method: 'POST' });
          fetch('/images/logo.png');
          window.__isNative = new EventSource('/rest/events?topics=x') instanceof EventSource;
          new EventSource('/rest/events/states?accessToken=secret');
          fetch('/rest/events/states?accessToken=secret').then(function (r) { return r.text() }).then(function (body) { window.__fetchedStates = body });
          fetch('/rest/events/states?drop').then(function (r) { return r.text() }).catch(function () {});
        </script></body></html>
        """)
        page.load()

        _ = try await page.waitForEvent { $0.event == "load" }
        let names = page.collector.events.map(\.event)
        #expect(names.first == "documentStart")
        let domReady = try #require(names.firstIndex(of: "domContentLoaded"))
        let loaded = try #require(names.firstIndex(of: "load"))
        #expect(domReady < loaded)

        let xhr = try await page.waitForEvent { $0.event == "rest" && $0.path == "/rest/items" }
        #expect(xhr?.method == "GET")
        #expect(xhr?.status == 200)
        #expect(xhr?.duration != nil)
        let fetched = try await page.waitForEvent { $0.event == "rest" && $0.path == "/rest/ui/components/ui:page" }
        #expect(fetched?.method == "POST")

        // Over EventSource and over fetch, as different Main UI versions do, plus a fetch whose
        // connection drops before the first update.
        let created = page.collector.events.filter { $0.event == "statesStreamCreated" }
        #expect(created.map(\.detail) == ["EventSource", "fetch", "fetch"])
        #expect(created.allSatisfy { $0.path == "/rest/events/states" }, "Other streams are left alone")
        for step in ["statesStreamOpen", "statesStreamReady", "statesFirstUpdate"] {
            #expect(try await page.waitForCount(of: step, 2), "\(step)")
        }
        let error = try await page.waitForEvent { $0.event == "statesStreamError" && $0.detail != "read failed" }
        #expect(error != nil, "A stream that ends is reported too")
        let dropped = try await page.waitForEvent { $0.event == "statesStreamError" && $0.detail == "read failed" }
        #expect(dropped != nil, "A fetch stream that drops before its first update is a failure, not a delay")
        #expect(!page.collector.events.contains { $0.event == "rest" && $0.path == "/rest/events/states" }, "The stream is not a REST call")
        let fetchedStates = try await page.webView.evaluateJavaScript("window.__fetchedStates || ''") as? String
        #expect(fetchedStates?.contains("event: ready") == true, "The page still reads the whole stream")
        let isNative = try await page.webView.evaluateJavaScript("String(window.__isNative)") as? String
        #expect(isNative == "true", "Streams keep working with instanceof")

        #expect(page.collector.events.allSatisfy { !($0.path ?? "").contains("secret") })
        #expect(!page.collector.events.contains { $0.path == "/images/logo.png" }, "Only REST calls are reported")
    }

    @Test("Reads a mark the page posted")
    func parsesMark() {
        let event = WebViewLoadTimingEvent(body: [
            "event": "rest", "ms": NSNumber(value: 812), "method": "GET", "path": "/rest/items", "status": NSNumber(value: 200), "duration": NSNumber(value: 140)
        ] as [String: Any])
        #expect(event?.logLine == "+812 ms rest GET /rest/items 200 in 140 ms")
        #expect(WebViewLoadTimingEvent(body: ["ms": NSNumber(value: 1)] as [String: Any]) == nil)
        #expect(WebViewLoadTimingEvent(body: "documentStart") == nil)
    }

    @Test("Cuts long text from the page")
    func capsLength() {
        let event = WebViewLoadTimingEvent(body: ["event": "x", "ms": NSNumber(value: 0), "path": String(repeating: "a", count: 1000)] as [String: Any])
        #expect(event?.path?.count == 200)
    }

    @Test("Logs which page a load asks for", arguments: [
        (
            WebRouteRestore.Seed(history: ["/", "/page/kitchen"], props: ["{}", "{}"], url: "/page/kitchen"),
            nil,
            "/page/home",
            "restoring 2 saved page(s), showing /page/kitchen, default page /page/home skipped"
        ),
        (
            WebRouteRestore.Seed(history: ["/page/kitchen"], props: ["{}"], url: "/page/kitchen"),
            nil,
            "",
            "restoring 1 saved page(s), showing /page/kitchen"
        ),
        (
            WebRouteRestore.Seed(history: ["/page/kitchen?token=secret"], props: ["{}"], url: "/page/kitchen?token=secret"),
            nil,
            "/page/home#top",
            "restoring 1 saved page(s), showing /page/kitchen, default page /page/home skipped"
        ),
        (nil, "/settings/", "/page/home", "opening requested page /settings/"),
        (nil, "/page/kitchen?token=secret", "", "opening requested page /page/kitchen"),
        (nil, nil, "/page/home", "opening default page /page/home"),
        (nil, nil, "", "opening the front page")
    ] as [(WebRouteRestore.Seed?, String?, String, String)])
    func logDescription(restore: WebRouteRestore.Seed?, path: String?, defaultPath: String, expected: String) {
        #expect(WebRouteRestore.logDescription(restore: restore, path: path, defaultPath: defaultPath) == expected)
    }
}
