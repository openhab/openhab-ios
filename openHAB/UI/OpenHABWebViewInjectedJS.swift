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

// MARK: - Injected JavaScript (module-scope: no `self` dependency, kept out of the class body)

let webViewNavbarProxyJS = """
    (function() {
        // Framework7 keeps closed popups mounted, and a page can contain one (the code
        // editor's "Parse Errors" popup sits inside the Thing page), so only count an
        // overlay that is open. Side panels are never proxied.
        function isUsableNavbar(navbar) {
            if (navbar.closest('.panel')) return false;
            var overlay = navbar.closest('.popup, .sheet-modal, .dialog, .actions-modal, .login-screen');
            return !overlay || overlay.classList.contains('modal-in');
        }

        function firstUsableNavbar(selectors) {
            for (var i = 0; i < selectors.length; i++) {
                var found = document.querySelectorAll(selectors[i]);
                for (var j = 0; j < found.length; j++) {
                    if (isUsableNavbar(found[j])) return found[j];
                }
            }
            return null;
        }

        // A page's navbar is a direct child of .page, so '> .navbar' cannot match a popup
        // nested inside that page.
        // Page padding depends on this, not on whichever navbar is being mirrored.
        function pageNavbar() {
            return firstUsableNavbar([
                '.view-main .page-current > .navbar',
                '.view-main .navbar.navbar-current',
                '.page-current > .navbar'
            ]);
        }

        function activeNavbar() {
            return firstUsableNavbar([
                '.popup.modal-in .navbar',
                '.sheet-modal.modal-in .navbar',
                '.view-main .page-current > .navbar',
                '.view-main .navbar.navbar-current',
                '.page-current > .navbar',
                '.navbar:not(.navbar-hidden)',
                '.navbar'
            ]);
        }

        function activePage() {
            return document.querySelector('.view-main .page-current')
                || document.querySelector('.page-current');
        }

        // Leave the navbar in the layout — Framework7 sizes pages and absolutely positioned
        // content (the map page) from --f7-navbar-height — and hide only what the native
        // bar reproduces.
        //
        // opacity, because innerText reads nothing out of a visibility:hidden subtree and
        // the labels below come from these elements. A stylesheet rule, because Framework7
        // writes inline opacity on .navbar-bg and .title and would overwrite ours.
        var PROXIED_CLASS = 'oh-navbar-proxied';
        function installProxyStyle() {
            if (document.getElementById('oh-navbar-proxy-style')) return;
            var style = document.createElement('style');
            style.id = 'oh-navbar-proxy-style';
            style.textContent =
                '.' + PROXIED_CLASS + ' > .navbar-bg,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .left,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .title,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .nav-title,' +
                '.' + PROXIED_CLASS + ' > .navbar-inner > .right' +
                '{opacity:0 !important;pointer-events:none !important}' +
                // A panel opens under the native bar, hiding the sidebar's Administration
                // links. Framework7 positions panels from --f7-appbar-app-offset for exactly
                // this; scoped to the panel because the main views read it too and must stay
                // full screen. Navbar height alone — a panel already insets itself by the
                // safe area.
                '.panel,.panel-backdrop{--f7-appbar-app-offset:var(--f7-navbar-height)}';
            (document.head || document.documentElement).appendChild(style);
        }
        // Guard every write. classList.add/remove rewrite the attribute even when nothing
        // changes, emitting a mutation record — and this runs from the MutationObserver
        // below, so an unguarded write loops forever and pegs the main thread.
        function hideProxiedParts(navbar) {
            document.querySelectorAll('.' + PROXIED_CLASS).forEach(function(el) {
                if (el !== navbar) el.classList.remove(PROXIED_CLASS);
            });
            if (navbar && !navbar.classList.contains(PROXIED_CLASS)) {
                navbar.classList.add(PROXIED_CLASS);
            }
        }

        // A hideNavbar page reserves no room for the native bar, so pad it and push the
        // floating icons down. Reversible, in case the page gains a navbar later.
        function syncPagePadding(hasNavbar) {
            var page = activePage();
            if (!page) return;
            var needsPadding = !hasNavbar;
            if (needsPadding === !!page.__ohPadded) return;
            page.__ohPadded = needsPadding;
            var offset = needsPadding ? 'calc(var(--f7-navbar-height) + var(--f7-safe-area-top))' : '';
            var pc = page.querySelector('.page-content');
            if (pc) pc.style.paddingTop = offset;
            page.querySelectorAll('.sidebar-icon, .fullscreen-icon').forEach(function(el) {
                el.style.marginTop = offset;
            });
        }

        function isMainUIDocument() {
            return !!(document.querySelector('.framework7-root') || document.getElementById('app'));
        }

        // A document that is not the Main UI — an openHAB error page, Basic UI, the REST
        // docs — reserves no room for the native bar, so pad the body itself.
        function syncDocumentPadding() {
            var body = document.body;
            if (!body) return;
            var needsPadding = !isMainUIDocument();
            if (needsPadding === !!body.__ohPadded) return;
            body.__ohPadded = needsPadding;
            body.style.paddingTop = needsPadding
                ? 'calc(var(--f7-navbar-height, 44px) + env(safe-area-inset-top, 0px))'
                : '';
        }

        function navbarHeight() {
            var v = parseFloat(getComputedStyle(document.documentElement)
                .getPropertyValue('--f7-navbar-height'));
            return (isFinite(v) && v > 0) ? v : 44;
        }
        // getComputedStyle forces a style recalc, and the state below is reported every
        // animation frame while scrolling — so re-read only in the debounced pass.
        function cachedNavbarHeight() {
            if (window.__ohNavbarHeight == null) window.__ohNavbarHeight = navbarHeight();
            return window.__ohNavbarHeight;
        }

        // Posts only on change — this runs on every scroll frame.
        // On window because the observer is installed once and holds the first injection's
        // closure, while Swift re-injects this script and resets its own copy.
        function reportState(navbar) {
            if (!ownsBar(navbar)) navbar = null;
            var hidden = navbar ? !!navbar.closest('.navbar-hidden') : false;
            // An expanded large title already shows the page title, so don't show it twice.
            var titleHidden = !!navbar &&
                navbar.classList.contains('navbar-large') &&
                !navbar.classList.contains('navbar-large-collapsed');
            var height = cachedNavbarHeight();
            var state = hidden + '|' + titleHidden + '|' + height;
            if (state === window.__ohNavbarLastState) return;
            window.__ohNavbarLastState = state;
            window.webkit.messageHandlers.mainUi.postMessage({
                type: 'navbarState',
                hidden: hidden ? 'true' : 'false',
                titleHidden: titleHidden ? 'true' : 'false',
                height: String(height)
            });
        }

        // Collapses a burst of mutations into one pass per frame. Still runs before the
        // next paint, so a new page's navbar never flashes under the native bar.
        var framePending = false;
        function scheduleStateReport() {
            if (framePending) return;
            framePending = true;
            requestAnimationFrame(function() {
                framePending = false;
                var navbar = activeNavbar();
                hideProxiedParts(ownsBar(navbar) ? navbar : null);
                reportState(navbar);
            });
        }

        // Only mirror a navbar from what is on screen — activeNavbar()'s fallbacks can
        // reach a previous page that is still mounted. On the iOS theme Framework7 lifts
        // navbars out of the pages into .navbars, so containment alone rejects them all.
        function ownsBar(navbar) {
            if (!navbar) return false;
            if (navbar.closest('.popup.modal-in, .sheet-modal.modal-in')) return true;
            if (navbar.matches('.navbar-current')) return true;
            if (navbar.matches('.navbar-previous, .navbar-next, .stacked')) return false;
            var page = activePage();
            return !page || page.contains(navbar);
        }

        function serializeNavbar() {
            installProxyStyle();
            window.__ohNavbarHeight = navbarHeight();
            var navbar = activeNavbar();
            var owns = ownsBar(navbar);
            syncPagePadding(!!pageNavbar());
            syncDocumentPadding();
            // Nothing to mirror: clear the bar rather than leave the previous page's
            // buttons on it, whose proxy tokens are already gone.
            if (!owns) {
                hideProxiedParts(null);
                window.webkit.messageHandlers.mainUi.postMessage({
                    type: 'navbarElements', title: '', items: []
                });
                reportState(navbar);
                return;
            }
            // Wait for web fonts (Framework7 Icons) to be ready before canvas rendering.
            // document.fonts.ready resolves immediately on subsequent calls once fonts are loaded.
            (document.fonts ? document.fonts.ready : Promise.resolve()).then(function() {
                hideProxiedParts(navbar);

                var titleEl = navbar.querySelector('.title') || navbar.querySelector('[class*="title"]');
                var title = titleEl ? titleEl.innerText.trim() : '';

                // Collect interactive elements from left/right regions only —
                // avoids picking up the title text as a button label.
                var btns = Array.from(navbar.querySelectorAll(
                    '.navbar-inner .left a, .navbar-inner .left button,' +
                    '.navbar-inner .right a, .navbar-inner .right button'
                ));
                // Renders an element's icon glyph to a canvas and returns base64 PNG.
                // Drawn in black on transparent so Swift can apply template tinting.
                function iconBase64(el) {
                    try {
                        var iconEl = el.querySelector('i.icon, .icon') || el;
                        var style = window.getComputedStyle(iconEl);
                        var text = iconEl.innerText.trim() || el.innerText.trim();
                        if (!text) return null;
                        var px = 128;
                        var canvas = document.createElement('canvas');
                        canvas.width = px; canvas.height = px;
                        var ctx = canvas.getContext('2d');
                        ctx.font = 'normal ' + Math.round(px * 0.9) + 'px ' + style.fontFamily;
                        ctx.fillStyle = 'black';
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        ctx.fillText(text, px / 2, px / 2);
                        return canvas.toDataURL('image/png').split(',')[1];
                    } catch(e) { return null; }
                }

                // Unique across the document, not just within this navbar: a popup sits
                // after the main view, so a bare index would collide with the page's navbar
                // and the popup's close button would click the page behind it.
                window.__ohProxyRun = (window.__ohProxyRun || 0) + 1;
                var proxyRun = window.__ohProxyRun;
                document.querySelectorAll('[data-oh-proxy]').forEach(function(el) {
                    el.removeAttribute('data-oh-proxy');
                });

                var items = [];
                btns.forEach(function(el, idx) {
                    var inRight = !!el.closest('.navbar-inner .right');
                    // Skip right-side panel-open buttons (the web "Other Apps" drawer).
                    if (inRight && el.classList.contains('panel-open')) return;
                    // Skip the in-app exit-to-app button (F7 icon: square_arrow_right).
                    var iconChild = el.querySelector('i.icon, .icon');
                    if (inRight && iconChild && iconChild.innerText.trim() === 'square_arrow_right') return;
                    // Detect back buttons using two strategies:
                    // 1. Standard F7: element has class 'back'.
                    // 2. openHAB oh-nav-content style: a left-region button whose F7 icon
                    //    is chevron_left (iOS) or arrow_left_md (MD). These use a Vue click
                    //    handler (@click="back" → f7router.back()) instead of the F7 .back
                    //    class, so the class check alone is insufficient.
                    var f7Icon = el.querySelector('.f7-icons');
                    var iconText = f7Icon ? (f7Icon.textContent || '').trim() : '';
                    var isBack = el.classList.contains('back') ||
                        (!inRight && (iconText === 'chevron_left' || iconText === 'arrow_left_md'));
                    var label = (el.getAttribute('aria-label')
                        || el.getAttribute('title')
                        || el.innerText || '').trim();
                    // Include back buttons even without a text label; give them a
                    // fallback label so the native button has an accessibility string.
                    if (!label && !isBack) return;
                    if (!label) label = 'Back';
                    // Back links: use history.back() for standard F7 .back class.
                    // oh-nav-content style backs use a Vue click handler — proxy the click.
                    var action;
                    if (el.classList.contains('back')) {
                        action = 'window.history.back()';
                    } else {
                        var token = proxyRun + '-' + idx;
                        el.setAttribute('data-oh-proxy', token);
                        action = '(function(){var el=document.querySelector("[data-oh-proxy=\\'' + token + '\\']");if(el)el.click();})()';
                    }
                    var item = { label: label, action: action };
                    if (isBack) item.isBack = 'true';
                    var b64 = f7Icon ? iconBase64(el) : null;
                    if (b64) item.icon = b64;
                    items.push(item);
                });

                window.webkit.messageHandlers.mainUi.postMessage({
                    type: 'navbarElements',
                    title: title,
                    items: items
                });
                reportState(navbar);
            });
        }

        // Observe document.body for page transitions and popup open/close.
        // Watching .view-main alone misses popups (they are siblings of .view-main).
        // class changes on .popup.modal-in and page elements all bubble up to body.
        // Hiding runs immediately so a new page's navbar never flashes under the native
        // bar; only the expensive part (rendering icons to canvas) is debounced.
        function observeNavbar() {
            // Swift re-injects this script several times per page; without a guard each
            // injection leaves another observer and scroll listener behind.
            if (window.__ohNavbarObserverInstalled) return;
            window.__ohNavbarObserverInstalled = true;
            var root = document.body || document.documentElement;
            var timer = null;
            new MutationObserver(function() {
                scheduleStateReport();
                clearTimeout(timer);
                timer = setTimeout(serializeNavbar, 200);
            }).observe(root, {
                childList: true, subtree: true,
                attributes: true, attributeFilter: ['class']
            });
            // Framework7 hides the navbar and collapses large titles from a scroll
            // handler — neither touches a class the observer above sees.
            document.addEventListener('scroll', scheduleStateReport, { capture: true, passive: true });
        }

        // Wait for the *correct* navbar. Open popups first, then .view-main.
        function readyNavbar() {
            return firstUsableNavbar([
                '.popup.modal-in .navbar',
                '.sheet-modal.modal-in .navbar',
                '.view-main .page-current > .navbar',
                '.view-main .navbar.navbar-current',
                '.page-current > .navbar'
            ]);
        }
        // A hideNavbar page never produces a navbar to wait for, so treat a rendered page
        // without one as settled too — it still needs padding and scroll state.
        function readyPageWithoutNavbar() {
            var page = activePage();
            return !!page && !!page.querySelector('.page-content') && !pageNavbar();
        }
        function waitAndSerialize() {
            if (readyNavbar() || readyPageWithoutNavbar() || !isMainUIDocument()) {
                serializeNavbar();
                observeNavbar();
                return;
            }
            var root = document.body || document.documentElement;
            if (!root) return;
            var bodyObserver = new MutationObserver(function() {
                if (readyNavbar() || readyPageWithoutNavbar() || !isMainUIDocument()) {
                    bodyObserver.disconnect();
                    serializeNavbar();
                    observeNavbar();
                }
            });
            // Watch childList for new elements AND attributes for .page-current
            // being added to an existing element.
            bodyObserver.observe(root, { childList: true, subtree: true,
                                         attributes: true, attributeFilter: ['class'] });
        }

        // Guard against re-installation when Swift injects this script multiple
        // times (on ready, sseConnected, didFinish). Only set up history hooks once;
        // always re-run waitAndSerialize so a fresh page or SPA navigation is covered.
        if (window.__ohNavbarProxyInstalled) {
            waitAndSerialize();
            return;
        }
        window.__ohNavbarProxyInstalled = true;

        waitAndSerialize();

        // Re-run after SPA navigations. requestAnimationFrame fires after the
        // browser's next paint, by which time Framework7 has updated the navbar.
        var origPush = history.pushState;
        history.pushState = function() {
            origPush.apply(this, arguments);
            requestAnimationFrame(waitAndSerialize);
        };
        var origReplace = history.replaceState;
        history.replaceState = function() {
            origReplace.apply(this, arguments);
            requestAnimationFrame(waitAndSerialize);
        };
        window.addEventListener('popstate', function() {
            requestAnimationFrame(waitAndSerialize);
        });
    })();
"""

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

let webViewMainUIBridgeJS = """
    (function() {
        // App-menu button probe.
        // window.MainUI is the global registered by the openHAB Main UI SPA.
        // Its presence means the Main UI is loaded and its own exit-to-app
        // button is available, so the iOS floating button is redundant.
        var _probeTimer = null;
        function probeMainUIButton() {
            var isOnMainUI = (typeof window.MainUI !== 'undefined');
            window.webkit.messageHandlers.mainUi.postMessage(
                isOnMainUI ? 'appMenu-hidden' : 'appMenu-visible'
            );
        }
        function scheduleProbe() {
            if (_probeTimer !== null) { clearTimeout(_probeTimer); }
            _probeTimer = setTimeout(function() { _probeTimer = null; probeMainUIButton(); }, 800);
        }

        // Main UI Callbacks
        window.OHApp = {
            exitToApp : function(){
                window.webkit.messageHandlers.mainUi.postMessage('exitToApp');
            },
            goFullscreen : function(){
                window.webkit.messageHandlers.mainUi.postMessage('goFullscreen');
            },
            sseConnected : function(connected) {
                window.webkit.messageHandlers.mainUi.postMessage('sseConnected-' + connected);
            },
            ready : function() {
                window.webkit.messageHandlers.mainUi.postMessage('ready');
            },
        }

        // Detect Path changes in SPA
        function notifyPathChange() {
            window.webkit.messageHandlers.pathChanged.postMessage(window.location.pathname);
            scheduleProbe();
        }

        const originalPushState = history.pushState;
        history.pushState = function() {
            originalPushState.apply(this, arguments);
            notifyPathChange();
        };

        const originalReplaceState = history.replaceState;
        history.replaceState = function() {
            originalReplaceState.apply(this, arguments);
            notifyPathChange();
        };

        window.addEventListener('popstate', notifyPathChange);

        // Notify initial path on load and run initial probe
        notifyPathChange();
    })();

"""

#if DEBUG
let webViewUITestProbeJS = """
(function(){
  if(window.ohUITest)return;
  window.ohUITest={report:function(k,v){
    if(window.webkit&&window.webkit.messageHandlers.mainUi)
      window.webkit.messageHandlers.mainUi.postMessage(
        {type:'uiTestReport',key:String(k),value:String(v)});
  }};
})();
"""
#endif

let webViewAppMenuProbeJS = """
(function() {
    var isOnMainUI = (typeof window.MainUI !== 'undefined');
    window.webkit.messageHandlers.mainUi.postMessage(
        isOnMainUI ? 'appMenu-hidden' : 'appMenu-visible'
    );
})();
"""

/// Records the pages the user opens in the Main UI, and puts them back after a connection
/// switch. Deciding what to put back happens in `WebRouteRestore`.
///
/// - Parameters:
///   - restore: the pages to put back, oldest first. Pass nil to leave the Main UI's own
///     memory alone, which is what we want when the app has just started.
///   - props: what each page in `restore` was opened with, as JSON, one per page.
///   - basePath: what the app's address hangs off, with no trailing slash, so a cloud
///     connection's extra path is kept. Empty when the app sits at the top.
func webViewRouteRestoreJS(restore: [String]?, props: [String]? = nil, basePath: String = "") -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let restoreLiteral = restore
        .flatMap { try? encoder.encode($0) }
        .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    // Kept as strings and parsed in the page, so stored text never runs as script.
    let propsLiteral = props
        .flatMap { try? encoder.encode($0) }
        .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    let baseLiteral = (try? encoder.encode(basePath))
        .flatMap { String(data: $0, encoding: .utf8) } ?? #""""#

    return #"""
    (function () {
        var RESTORE = \#(restoreLiteral)
        var RESTORE_PROPS = \#(propsLiteral)
        var BASE = \#(baseLiteral)
        var VIEW_ID = 'view_main' // the name the Main UI gives its main view
        var STORAGE_KEY = 'f7router-' + VIEW_ID + '-history'
        // True until the restored pages have their props back. Reporting before then would
        // save the pages without them.
        var restoring = false

        // Write this before the Main UI starts up. It reads the list as it starts.
        //
        // Only on the app's front page, which is what we asked for. These same scripts run
        // for every page the app opens, so a tile or a retry could otherwise pick this up
        // and get dragged off to the wrong page.
        if (RESTORE && RESTORE.length && isAppRoot()) {
            try { localStorage.setItem(STORAGE_KEY, JSON.stringify(RESTORE)) } catch (e) {}
            seedBrowserHistory(RESTORE)
            restoring = true
        }

        function isAppRoot() {
            var path = location.pathname
            return path === BASE || path === BASE + '/'
        }

        // Two jobs. Going back in the Main UI is really the browser going back, and a page
        // that just opened has nothing behind it, so give it something. And we asked for
        // the app's front page rather than the page we want, so this is also what moves us
        // to that page. Changing the address is safe. Everything the page needs is fetched
        // from the top, not relative to wherever we are.
        function seedBrowserHistory(stack) {
            try {
                history.replaceState(stateFor(stack[0]), '', BASE + stack[0])
                for (var i = 1; i < stack.length; i++) {
                    history.pushState(stateFor(stack[i]), '', BASE + stack[i])
                }
            } catch (e) {}
        }

        // The Main UI looks here to work out where "back" goes, so match what it writes.
        function stateFor(url) {
            var state = {}
            state[VIEW_ID] = { url: url }
            return state
        }

        var MODAL_KEYS = ['popup', 'popover', 'sheet', 'actions', 'panel', 'loginScreen', 'customModal']
        var PROPS_ONLY = /\/(duplicate|stub)$/ // only work when opened from inside the app

        function router() {
            var el = document.querySelector('.view-main')
            return el && el.f7View ? el.f7View.router : null
        }

        function matchRoute(r, url) {
            if (!url || url.charAt(0) !== '/') return null
            var m
            try { m = r.findMatchingRoute(url.split('#')[0]) } catch (e) { return null }
            return m && m.route ? m : null
        }

        function isPopup(m) {
            for (var i = 0; i < MODAL_KEYS.length; i++) {
                if (m.route[MODAL_KEYS[i]]) return true // e.g. /analyzer/
            }
            return false
        }

        // Popups and the like show up in the address but cannot be opened again directly.
        function navigable(r, url) {
            var m = matchRoute(r, url)
            if (!m || isPopup(m)) return false
            if (PROPS_ONLY.test(url.split('#')[0].split('?')[0])) return false
            return m.route.path !== '(.*)' // nothing real behind this address
        }

        // What a page is opened with lives beside the history, not in the address. `deep`
        // gives a page its back link, `defineVars` sets its variables. Nothing else is kept,
        // other pages get passed live objects that mean nothing once saved.
        var KEPT_PROPS = ['deep', 'defineVars']

        // Opening a popup adds it to Framework7's history but adds no props for it, and closing
        // it removes the last of both, which throws away the props of the page underneath.
        // Stand in for each open popup so both lists keep step.
        var POPUP_PROPS = { popup: true }
        function padPopupProps(r) {
            if (!r.propsHistory) return
            var open = 0
            for (var i = r.history.length - 1; i >= 0; i--) {
                var m = matchRoute(r, String(r.history[i]))
                if (!m || !isPopup(m)) break
                open++
            }
            var padded = 0
            for (var j = r.propsHistory.length - 1; j >= 0 && r.propsHistory[j] === POPUP_PROPS; j--) padded++
            for (; padded < open; padded++) r.propsHistory.push(POPUP_PROPS)
        }

        // Framework7 only adds to and removes from the end of both lists, but does not keep
        // them the same length (a restored page starts with none), so line them up from the end.
        function propsAt(r, i) {
            var list = r.propsHistory || []
            var p = list[i - (r.history.length - list.length)]
            var kept = {}
            if (!p) return kept
            for (var k = 0; k < KEPT_PROPS.length; k++) {
                if (p[KEPT_PROPS[k]] !== undefined) kept[KEPT_PROPS[k]] = p[KEPT_PROPS[k]]
            }
            return kept
        }

        function capture() {
            var r = router()
            if (!r || !r.history || restoring) return null
            padPopupProps(r)
            var stack = []
            var props = []
            for (var i = 0; i < r.history.length; i++) {
                var url = String(r.history[i]).split('#')[0]
                if (!navigable(r, url)) continue
                var p
                try { p = JSON.stringify(propsAt(r, i)) } catch (e) { p = '{}' }
                if (stack.length && stack[stack.length - 1] === url) {
                    props[props.length - 1] = p // same page twice, keep how it was last opened
                    continue
                }
                stack.push(url)
                props.push(p)
            }
            if (!stack.length) return null
            return { history: stack, props: props, url: stack[stack.length - 1] }
        }

        // The Main UI opens the restored page from its address alone, so it comes up without
        // its props: no back link, no variables. Hand them back to Framework7 for every page,
        // so going back opens each one properly, and open the current page again with its own.
        function restoreProps(r) {
            var n = r.history.length
            var k = RESTORE.length
            if (r.history[n - 1] !== RESTORE[k - 1]) return // not the pages we put back
            var list = []
            for (var i = 0; i < n; i++) {
                var p = {}
                var j = i - (n - k)
                if (RESTORE_PROPS && j >= 0) {
                    try { p = JSON.parse(RESTORE_PROPS[j]) || {} } catch (e) {}
                }
                list.push(p)
            }
            r.propsHistory = list
            var top = list[n - 1]
            if (Object.keys(top).length) {
                r.navigate(r.history[n - 1], {
                    reloadCurrent: true, animate: false, browserHistory: false, props: top
                })
            }
        }

        // Wait for the Main UI to finish opening the restored page. Framework7 ignores a
        // navigation while another is still under way.
        function whenRestoredPageOpen() {
            var tries = 0
            var poll = setInterval(function () {
                var r = router()
                var page = r && r.currentPageEl && r.currentPageEl.f7Page
                var ready = !!page && r.allowPageChange && page.route.url === RESTORE[RESTORE.length - 1]
                if (!ready && ++tries <= 100) return
                clearInterval(poll)
                if (ready) {
                    try { restoreProps(r) } catch (e) {}
                }
                restoring = false
                report()
            }, 100)
        }
        if (restoring) whenRestoredPageOpen()

        var lastSent = null
        var pending = null

        function report() {
            if (pending) clearTimeout(pending)
            // Let the Main UI finish updating before we read anything.
            pending = setTimeout(function () {
                pending = null
                var state = capture()
                if (!state) return
                var json = JSON.stringify(state)
                if (json === lastSent) return // nothing moved, e.g. a popup opened
                lastSent = json
                try {
                    window.webkit.messageHandlers.mainUi.postMessage({
                        type: '\#(WebRouteRestore.messageType)', state: json
                    })
                } catch (e) {}
            }, 0)
        }

        var origPush = history.pushState
        var origReplace = history.replaceState

        history.pushState = function () {
            var out = origPush.apply(history, arguments)
            report()
            return out
        }
        history.replaceState = function () {
            var out = origReplace.apply(history, arguments)
            report()
            return out
        }
        window.addEventListener('popstate', report)

        // The Main UI normally announces its first page itself, which we catch above.
        // This is a fallback in case it doesn't.
        var tries = 0
        var poll = setInterval(function () {
            if (router() || ++tries > 100) {
                clearInterval(poll)
                report()
            }
        }, 100)
    })()
    """#
}

func editorHeightFixJS(safeAreaBottom: CGFloat) -> String {
    """
    (function() {
        if (window.__ohEditorFixInstalled) return;
        window.__ohEditorFixInstalled = true;

        var safeAreaBottom = \(safeAreaBottom);

        function fixScriptEditorHeight() {
            var editor = document.querySelector('.rule-script-editor.v-codemirror');
            if (!editor) return;

            var page = editor.closest('.page');
            if (!page) return;

            var toolbar = page.querySelector('.toolbar');
            if (!toolbar) return;

            var fab = page.querySelector('.fab') || document.querySelector('.fab');
            var fabHeight = 0;
            if (fab) {
                var fabRect = fab.getBoundingClientRect();
                fabHeight = fabRect.height || 56;
            }

            var totalBottomPadding = safeAreaBottom;
            if (fab && fabHeight > 0) {
                totalBottomPadding += fabHeight + 16;
            } else if (fab) {
                totalBottomPadding += 56 + 16;
            }

            var pageContent = page.querySelector('.page-content');
            if (pageContent) {
                pageContent.style.paddingBottom = totalBottomPadding + 'px';
            }

            var scrollContainer = editor.querySelector('.cm-scroller') ||
                                 editor.querySelector('.CodeMirror-scroll') ||
                                 editor.querySelector('.cm-content');

            if (scrollContainer && scrollContainer !== editor) {
                scrollContainer.style.paddingBottom = totalBottomPadding + 'px';
                scrollContainer.style.overflowY = 'auto';
                editor.style.marginBottom = totalBottomPadding + 'px';
            } else {
                editor.style.paddingBottom = totalBottomPadding + 'px';
                editor.style.marginBottom = totalBottomPadding + 'px';
            }
        }

        new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                for (var j = 0; j < mutations[i].addedNodes.length; j++) {
                    var n = mutations[i].addedNodes[j];
                    if (n.nodeType === 1 &&
                        ((n.classList && n.classList.contains('rule-script-editor')) ||
                         (n.querySelector && n.querySelector('.rule-script-editor')))) {
                        setTimeout(function() {
                            requestAnimationFrame(fixScriptEditorHeight);
                        }, 100);
                        return;
                    }
                }
            }
        }).observe(document.body || document.documentElement, { subtree: true, childList: true });

        window.addEventListener('resize', function() {
            setTimeout(function() {
                requestAnimationFrame(fixScriptEditorHeight);
            }, 100);
        });

        setTimeout(function() {
            fixScriptEditorHeight();
        }, 500);
    })();
    """
}
