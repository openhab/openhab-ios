// openHAB Main UI bridge — protocol v1 (draft)
//
// The messages Main UI and the iOS and Android apps send each other. See README.md.
// Meant to live in openhab-webui as src/types/oh-bridge.d.ts, with matching Swift and Kotlin
// types in the apps. "Host" in the type names means the app.

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

/**
 * Put on the page by the app before any page script runs. It has the same shape as the object
 * Android's WebViewCompat.addWebMessageListener creates; iOS builds the same thing itself and
 * forwards postMessage to its OHBridge message handler.
 *
 * Every message is a JSON string, because Android can only pass strings.
 */
interface OHBridgePort {
  postMessage(json: string): void
  /**
   * How messages from the app arrive. Main UI sets this before anything else, and answers
   * not_ready until it can navigate. The app holds its messages until the page's ui.hello, so
   * nothing is sent while this is still null.
   */
  onmessage: ((event: { data: string }) => void) | null
  /**
   * What Main UI needs before it draws anything. On Android, added with
   * WebViewCompat.addDocumentStartJavaScript. Not yet tried on Android: if the listener's object
   * can't take an extra property, this moves to its own global, window.OHBridgeInfo.
   */
  readonly info: HostInfo
}

interface Window {
  OHBridge?: OHBridgePort
}

interface HostInfo {
  protocol: 1
  platform: 'ios' | 'android'
  appVersion: string
  /** What the app offers to take over. See HostFeature. */
  features: HostFeature[]
  /** Read once at startup. Replaces OHApp.preferTheme / preferDarkMode. */
  theme?: 'ios' | 'md' | 'aurora'
  darkMode?: 'light' | 'dark'
  /** Pages to put back at startup, oldest first, as paths from Main UI's root. */
  initialHistory?: string[]
  /**
   * What each page in initialHistory was opened with, as JSON, one per page: `deep` for the
   * page's back link, `defineVars` for its variables. They aren't part of the address, so a
   * page opened from its address alone would come up without them.
   */
  initialProps?: string[]
  layout?: LayoutInfo
}

type HostFeature =
  | 'navbar' // the app draws the top bar; Main UI hides its own and sends navbar.state
  | 'menu' // the app shows the sidebar in its own menu; Main UI hides its sidebar and sends menu.state
  | 'routeRestore' // the app keeps nav.changed history and passes it back as initialHistory

type UIFeature =
  | 'navbar'
  | 'menu'
  | 'routeRestore'
  | 'layout'

// ---------------------------------------------------------------------------
// Envelope
// ---------------------------------------------------------------------------

interface Envelope<T extends string, P> {
  v: 1
  type: T
  /**
   * Set when the sender wants an answer. Every message from the app has one. From the page,
   * only requests (auth.getCredentials) have one; updates don't.
   */
  id?: string
  /** Set on replies; matches the request id. */
  replyTo?: string
  payload: P
}

type Reply<P = unknown> = Envelope<'reply', { ok: true; result?: P } | { ok: false; error: ReplyError }>

interface ReplyError {
  code: ReplyErrorCode
  /** For logs only. */
  message?: string
}

type ReplyErrorCode =
  | 'not_ready' // Main UI is up but can't act yet. The app tries again.
  | 'unknown_type' // the page doesn't know this message. The app doesn't try again.
  | 'not_allowed' // not possible right now, e.g. menu.activate while a dialog is open
  | 'not_found' // the button, entry or page it names isn't there any more
  | 'failed' // it went wrong

// ---------------------------------------------------------------------------
// Web → host
// ---------------------------------------------------------------------------

type WebToHost =
  | Envelope<'ui.hello', UIHello>
  | Envelope<'connection.state', { sseConnected: boolean }>
  | Envelope<'nav.changed', NavState>
  | Envelope<'navbar.state', NavbarState>
  | Envelope<'menu.state', MenuState>
  | Envelope<'auth.getCredentials', {}> // request → Reply<Credentials | null>
  | Reply

/**
 * User name and password for a proxy in front of openHAB (Basic auth). Replaces
 * OHApp.getBasicCredentials*. Main UI only asks when its first call to the server is refused
 * (401). null when the app has none. Main UI keeps them in memory only.
 */
interface Credentials {
  username: string
  password: string
}

/**
 * Sent once per page load, when the first page is on screen, followed by nav.changed,
 * navbar.state and menu.state. The app keeps its loading screen up until then, and holds its
 * own messages until then too.
 */
interface UIHello {
  protocol: 1
  /** 'mainui' = Main UI itself, 'shim' = the app's script speaking for an older Main UI, 'other' = not Main UI (Basic UI, an error page, the REST docs). */
  impl: 'mainui' | 'shim' | 'other'
  /** Main UI version when known. */
  version?: string
  /** Which of the app's offers Main UI took. The app only takes over these. */
  accepted: HostFeature[]
  /** What the page supports, so the app knows what it can ask for. */
  features: UIFeature[]
}

/** Sent after every page change. */
interface NavState {
  /** The page on screen, as a path from Main UI's root, e.g. "/page/overview". */
  path: string
  /** Pages that can be put back, oldest first. Popups and pages that can't be opened from an address are left out. */
  history: string[]
  /** One JSON string per entry in history: the props it was opened with. See HostInfo.initialProps. */
  props?: string[]
  /** A popup, sheet or popover is open on top of the page. */
  modal: boolean
}

/**
 * The top bar, for the app to draw. Sent only when Main UI took 'navbar', and again whenever it
 * changes. Describes the bar in front: an open popup's bar wins over the page's. Leaves out
 * buttons for things the app does itself, like the "Other Apps" button.
 */
interface NavbarState {
  title: string
  /** The page is showing its own large title, so the app shouldn't show it again. */
  titleInContent: boolean
  /** The page has scrolled the bar out of sight. */
  hidden: boolean
  /** null when there is nothing to go back to. */
  back: { label?: string } | null
  leading: NavbarAction[]
  trailing: NavbarAction[]
}

interface NavbarAction {
  /** Stays the same while the button is on the page. Sent back in navbar.activate. */
  id: string
  label: string
  icon?: Icon
  disabled?: boolean
}

/**
 * What Main UI's sidebar shows this user, for the app's menu. Sent after ui.hello and whenever
 * it changes: pages, sign-in, admin access, current page.
 */
interface MenuState {
  sections: MenuSection[]
}

interface MenuSection {
  id: string // 'pages' | 'settings' | 'account' | …
  /** In the user's language, e.g. "Administration". */
  title?: string
  items: MenuItem[]
}

interface MenuItem {
  id: string
  label: string
  /** Secondary line, e.g. the server URL under the user's name. */
  footer?: string
  icon?: Icon
  /**
   * Tapping sends nav.navigate with this path. Entries without one do something in Main UI
   * instead ("Unlock Administration" signs in), and tapping sends menu.activate with the id.
   */
  path?: string
  /** The entry for the current page. */
  active?: boolean
  /** The entries under this one that the sidebar shows, e.g. the user's picks under Settings. */
  children?: MenuItem[]
  /** The rest, which the sidebar shows under "Show all". */
  more?: MenuItem[]
}

/**
 * Icons in the format Main UI uses everywhere (page settings, widgets):
 *   "f7:gear_alt_fill"         Framework7 icon
 *   "material:settings"        Material icon
 *   "oh:classic:light"         openHAB icon, served by the server at /icon/<name>?iconset=<set>
 *   "iconify:mdi:lightbulb"    Iconify icon
 * A bare name ("light") is an openHAB classic icon, as in Main UI.
 */
interface Icon {
  /** The icon Main UI shows on the ios and aurora themes, e.g. "f7:gear_alt_fill". */
  name: string
  /** What Main UI shows on the md theme when it differs, e.g. "material:settings". */
  md?: string
  /** SVG markup, only when there's no name to send (the shim reading an Iconify icon). */
  svg?: string
}

// ---------------------------------------------------------------------------
// Host → web
// ---------------------------------------------------------------------------

/**
 * Every message has an id and gets an answer: ok, or one of ReplyErrorCode. The app holds them
 * until the page's ui.hello (up to 30 s), then sends. On not_ready, or no answer within 750 ms,
 * it sends again: up to 6 times, 300 ms apart. A newer message of the same type replaces an
 * older one still waiting.
 */
type HostToWeb =
  | Envelope<'nav.navigate', { path: string; history?: string[] }>
  | Envelope<'nav.back', {}>
  | Envelope<'nav.openModal', { kind: 'popup' | 'popover' | 'sheet'; target: string }> // target: page:uid, widget:uid, or oh-*
  | Envelope<'nav.closeModals', {}>
  | Envelope<'navbar.activate', { id: string }>
  | Envelope<'menu.activate', { id: string }> // a menu item without a path was tapped
  | Envelope<'settings.changed', { theme?: 'ios' | 'md' | 'aurora'; darkMode?: 'light' | 'dark' }>
  | Envelope<'layout.changed', LayoutInfo>
  | Envelope<'nav.getState', {}> // request → Reply<NavState>
  | Envelope<'ui.reload', {}>
  | Reply

interface LayoutInfo {
  /** How much of the page the app's bars cover, in CSS pixels. Main UI leaves this much room. */
  insets: { top: number; bottom: number }
  /** Height of the app's top bar, when the app draws one. */
  navbarHeight?: number
}
