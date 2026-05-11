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

extension URL {
    /// Returns `absolutePath` with this URL's path prefix stripped.
    /// Use when `self` is a proxy or root URL so that stored paths are
    /// always relative to the MainUI root rather than carrying a proxy-specific prefix.
    func relativeWebViewPath(for absolutePath: String) -> String {
        let basePath = path
        guard !basePath.isEmpty, basePath != "/", absolutePath.hasPrefix(basePath) else {
            return absolutePath
        }
        let relative = String(absolutePath.dropFirst(basePath.count))
        return relative.isEmpty ? "/" : (relative.hasPrefix("/") ? relative : "/" + relative)
    }
}

/// Returns `absolutePath` relative to the active base URL.
/// Prefers the proxy URL path when present; falls back to `rootURLString`.
func relativeWebViewPath(_ absolutePath: String, proxyURL: URL?, rootURLString: String) -> String {
    if let proxyURL, !proxyURL.path.isEmpty, proxyURL.path != "/" {
        return proxyURL.relativeWebViewPath(for: absolutePath)
    }
    return URL(string: rootURLString)?.relativeWebViewPath(for: absolutePath) ?? absolutePath
}
