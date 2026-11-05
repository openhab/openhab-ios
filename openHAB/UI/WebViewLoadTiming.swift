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

/// One mark the script posted, as a log line.
struct WebViewLoadTimingEvent: Equatable {
    /// Anything longer is cut, the page decides what it sends.
    private static let maxLength = 200

    let event: String
    let milliseconds: Int
    let path: String?
    let method: String?
    let status: Int?
    let duration: Int?
    let detail: String?

    /// e.g. `+812 ms rest GET /rest/items 200 in 140 ms`
    var logLine: String {
        var parts = ["+\(milliseconds) ms", event]
        if let method {
            parts.append(method)
        }
        if let path, !path.isEmpty {
            parts.append(path)
        }
        if let status {
            parts.append(String(status))
        }
        if let duration {
            parts.append("in \(duration) ms")
        }
        if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        return parts.joined(separator: " ")
    }

    /// Nil unless `body` is a dictionary with an event name and a time.
    init?(body: Any) {
        guard let dict = body as? [String: Any],
              let event = dict["event"] as? String, !event.isEmpty,
              let milliseconds = (dict["ms"] as? NSNumber)?.intValue else { return nil }
        self.event = String(event.prefix(Self.maxLength))
        self.milliseconds = milliseconds
        path = (dict["path"] as? String).map { String($0.prefix(Self.maxLength)) }
        method = (dict["method"] as? String).map { String($0.prefix(16)) }
        status = (dict["status"] as? NSNumber)?.intValue
        duration = (dict["duration"] as? NSNumber)?.intValue
        detail = (dict["detail"] as? String).map { String($0.prefix(Self.maxLength)) }
    }
}

/// How long Main UI takes to show item states, as seen from inside the page. The app's own log
/// stops once the page has loaded, and Main UI fetches its states itself, so a slow start (#1380)
/// left nothing to go on.
///
/// The script reports when the document starts and finishes, every REST call Main UI makes in
/// its first minute, and each step of the item-state stream: opened, ready, first update. Times
/// are milliseconds since the page started loading. Queries are dropped, they can hold an access
/// token.
enum WebViewLoadTiming {
    /// The message handler the script posts to.
    static let messageHandlerName = "loadTiming"

    /// Runs at document start, before the bridge, so the bridge shim can add its own marks
    /// through `window.OHLoadTiming.mark`.
    static let script = """
    (function () {
      if (window.OHLoadTiming) return
      var handlers = window.webkit && window.webkit.messageHandlers
      var handler = handlers && handlers.\(messageHandlerName)
      if (!handler) return

      var MAX_MESSAGES = 200
      var REST_WINDOW_MS = 60000
      var sent = 0

      function now() {
        return Math.round(performance.now())
      }

      function pathOf(url) {
        try {
          return new URL(String(url), location.href).pathname
        } catch (e) {
          return ''
        }
      }

      function mark(event, fields) {
        if (sent >= MAX_MESSAGES) return
        sent++
        var msg = { event: String(event), ms: now() }
        for (var key in fields || {}) msg[key] = fields[key]
        try {
          handler.postMessage(msg)
        } catch (e) {}
      }
      window.OHLoadTiming = { mark: mark }

      mark('documentStart', { path: location.pathname })
      document.addEventListener('DOMContentLoaded', function () {
        mark('domContentLoaded')
      })
      window.addEventListener('load', function () {
        mark('load')
      })

      var STATES = /\\/rest\\/events\\/states\\/?$/
      var REST = /\\/rest\\//

      function isEarlyRest(path) {
        return REST.test(path) && performance.now() < REST_WINDOW_MS
      }

      // Item states arrive on this stream: 'ready' carries the connection id Main UI then
      // subscribes its items with, and each message after that is an update.
      var NativeEventSource = window.EventSource
      if (NativeEventSource) {
        var TimedEventSource = function (url, init) {
          var source = new NativeEventSource(url, init)
          var path = pathOf(url)
          if (!STATES.test(path)) return source
          mark('statesStreamCreated', { path: path, detail: 'EventSource' })
          var gotUpdate = false
          source.addEventListener('open', function () {
            mark('statesStreamOpen')
          })
          source.addEventListener('ready', function () {
            mark('statesStreamReady')
          })
          source.addEventListener('message', function () {
            if (gotUpdate) return
            gotUpdate = true
            mark('statesFirstUpdate')
          })
          source.addEventListener('error', function () {
            mark('statesStreamError', { detail: source.readyState === NativeEventSource.CLOSED ? 'closed' : 'reconnecting' })
          })
          return source
        }
        TimedEventSource.prototype = NativeEventSource.prototype
        TimedEventSource.CONNECTING = NativeEventSource.CONNECTING
        TimedEventSource.OPEN = NativeEventSource.OPEN
        TimedEventSource.CLOSED = NativeEventSource.CLOSED
        window.EventSource = TimedEventSource
      }

      function markRest(method, path, status, started) {
        mark('rest', { method: String(method || 'GET').toUpperCase(), path: path, status: status, duration: now() - started })
      }

      var xhrOpen = XMLHttpRequest.prototype.open
      var xhrSend = XMLHttpRequest.prototype.send
      XMLHttpRequest.prototype.open = function (method, url) {
        this.__ohTiming = { method: method, path: pathOf(url) }
        return xhrOpen.apply(this, arguments)
      }
      XMLHttpRequest.prototype.send = function () {
        var timing = this.__ohTiming
        if (timing && isEarlyRest(timing.path)) {
          var started = now()
          var xhr = this
          xhr.addEventListener('loadend', function () {
            markRest(timing.method, timing.path, xhr.status, started)
          })
        }
        return xhrSend.apply(this, arguments)
      }

      // Some Main UI versions read the stream with fetch, so there are no EventSource events to
      // listen to. Read a copy of the body instead and stop at the first update; the page keeps
      // reading its own copy.
      function watchStatesFetch(path, result) {
        mark('statesStreamCreated', { path: path, detail: 'fetch' })
        result.then(
          function (response) {
            mark('statesStreamOpen', { status: response.status })
            readStatesBody(response)
          },
          function () {
            mark('statesStreamError', { detail: 'request failed' })
          }
        )
      }

      function readStatesBody(response) {
        var copy
        try {
          copy = response.clone()
        } catch (e) {
          return
        }
        if (!copy.body || typeof TextDecoder === 'undefined') return
        var reader = copy.body.getReader()
        var decoder = new TextDecoder()
        var buffer = ''
        var ready = false
        function next() {
          reader.read().then(
            function (chunk) {
              if (chunk.done) {
                mark('statesStreamError', { detail: 'closed' })
                return
              }
              buffer += decoder.decode(chunk.value, { stream: true })
              var blocks = buffer.split(/\\r?\\n\\r?\\n/)
              buffer = blocks.pop()
              for (var i = 0; i < blocks.length; i++) {
                if (/^event:\\s*ready\\s*$/m.test(blocks[i])) {
                  if (!ready) mark('statesStreamReady')
                  ready = true
                } else if (/^data:/m.test(blocks[i])) {
                  mark('statesFirstUpdate')
                  reader.cancel().catch(function () {})
                  return
                }
              }
              next()
            },
            function () {
              // The connection dropped before the first update: a failed stream, not a slow one.
              mark('statesStreamError', { detail: 'read failed' })
            }
          )
        }
        next()
      }

      var nativeFetch = window.fetch
      if (nativeFetch) {
        window.fetch = function (input, init) {
          var url = input && typeof input === 'object' && 'url' in input ? input.url : input
          var method = (init && init.method) || (input && typeof input === 'object' && input.method) || 'GET'
          var path = pathOf(url)
          var result = nativeFetch.apply(this, arguments)
          if (STATES.test(path)) {
            watchStatesFetch(path, result)
            return result
          }
          if (!isEarlyRest(path)) return result
          var started = now()
          result.then(
            function (response) {
              markRest(method, path, response.status, started)
            },
            function () {
              markRest(method, path, 0, started)
            }
          )
          return result
        }
      }
    })();
    """
}
