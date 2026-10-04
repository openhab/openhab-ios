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

// MARK: - Injected JavaScript outside the bridge

// Everything that talks to Main UI goes through OHBridge (UI/Bridge). These stay outside it.

/// Catches taps on links that open other apps.
/// `e.isTrusted` skips clicks made by scripts, so only real taps get through.
let webViewExternalURLInterceptorJS = """
    (function() {
        const nativeSchemes = ['http', 'https', 'about', 'blob', 'data', 'javascript', ''];
        function isCustomScheme(url) {
            const m = /^([a-z][a-z0-9+\\-.]*):/.exec((url || '').toLowerCase());
            return m != null && !nativeSchemes.includes(m[1]);
        }
        document.addEventListener('click', function(e) {
            if (!e.isTrusted) return;
            let el = e.target;
            while (el && el.tagName !== 'A') el = el.parentElement;
            if (el && el.href && isCustomScheme(el.href)) {
                e.preventDefault();
                window.webkit.messageHandlers.externalURL.postMessage(el.href);
            }
        }, true);
    })();
"""

#if DEBUG
let webViewUITestProbeJS = """
(function(){
  if(window.ohUITest)return;
  window.ohUITest={report:function(k,v){
    if(window.webkit&&window.webkit.messageHandlers.ohUITest)
      window.webkit.messageHandlers.ohUITest.postMessage({key:String(k),value:String(v)});
  }};
})();
"""
#endif
