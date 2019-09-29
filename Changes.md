# What has changed

* The app is now ready for iOS 13:
    * It supports the beautiful Dark Mode
    
* Improvements relevant to users
    * Haptic feedback when buttons. This is available as of iPhone 7
    * Throttling the flow of events from colorpicker to max once every 0.3 s
    * Better screen space usage with fixed layout constraints and doubled slider width depending on size class
    * Rollershutter button order changed
    * Handling of many variants on server side for instance http/https connections to servers still on 1.x 
    * Video element: Added mjpeg support
    * Label for state value for rollershutter
    * Changed the Basic Auth challenge handler to check against the tracked URL rather than the remote/local URL from the settings.  This should ensure Basic Auth works in cases where the URL is discovered via Bonjour. 
    * Fix for parsing of string to number without the locale setup 
    * Fix for app always showing SSL certificate warning
    * Handling the case where only one default sitemap is returned in a sitemappage
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

## Trademark Disclaimer

Product names, logos, brands and other trademarks referred to within the openHAB website are the
property of their respective trademark holders. These trademark holders are not affiliated with
openHAB or our website. They do not sponsor or endorse our materials.

