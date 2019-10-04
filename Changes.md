# What has changed

* The app is now ready for iOS 13:
    * It supports the beautiful Dark Mode
    
* Improvements relevant to users
    * Implemented haptic feedback when buttons are pressed. Note, this is only available from iPhone 7 onwards
    * Enhanced the colorpicker, so that it is easier to select the desired color
    * Optimized screen usage, so that more information can be displayed
    * Changed order of the rollershutter button
    * Fixed backwards compatibility with OpenHAB 1.x connections
    * Enhanced video component by adding mjpeg support
    * Improved the representation of the rollershutter component
    * Enhanced authentication process for remote and local connections. This should ensure Basic Auth works in cases where the URL is discovered via Bonjour.
    * Fixed data parsing issue
    * Changed logic regards showing SSL certificate warning
    * Improved handling of sitemaps
    * Improved video URL handling on cell reuse

* Behind the scenes
    * URLSession wrapped in Alamofire for network access, AFNetworking completely removed
       * Improved handling of SSL certificate warning
       * Display of icons when connected via https
       * Setting authorization header also for icons
       * Caching of icons with Kingfisher - SDWebImage purged from code base
       * Converted direct URLSession usage in OpenHABTracker to use NetworkConnection.shared.manager instead to ensure that auth handling is handled properly - in particular when a 401 is returned from the server. 
       *  Refactored HTTP Basic Auth to use the taskDidReceiveChallenge delegate so it only includes the Authorization header if requested by the server.
       * Completed migration from AFNetworking to Alamofire: purged AlamofireRememberingSecurityPolicy.swift: init(policies: [String: ServerTrustPolicy]) to override ancestor, uncommented evaluateClientTrust and handleAuthenticationChallenge Reworked NetworkManager to it compile successfully with AlamofireRememberingSecurityPolicy Removed main.m, openHAB-Prefix.pch files, openHAB-Bridging-Header.h, openHABTests-Bridging-Header.h
       * Fixed retain cycle in setWillSendRequestForAuthenticationChallenge closure
   * SFSymbols as source of icons for iOS 13 to eventually replace DynamicButton
   * Build improvements
       * Swift Package Manager to replace CocoaPod where possible
       * Improved fastlane
       * Improved test coverage for instance for large JSON files, XML trimming whitespace, improved logic
   * Many bug fixes: correct recognition of labelValue
   * Refactoring: 
       * Completed onReceiveSessionTaskChallenge and onReceiveSessionChallenge for image download
       * Recursive traversal of widgets data structure
       * Refinement of swiftlint, usage of swiftformat
       * Update to recent versions of SideMenu: clearing widgets to ensure cell invalidation on sitemap change
       * Access to UserDefaults via Preferences to avoid typing errors and improve consistency
       * Migrated from responseJSON to responseData
       * Reworked XML parsing: now completely based on Fuzi framework
       * Setting the FrameUITableViewCell font and color to match Apple's Guidelines
       * Retain cycle in loadPage fixed
       * Cache invalidation on sitemap change fixed
