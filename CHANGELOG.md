# Change Log

## [Unreleased]

## [Version 3.1.38, Build 95] - 2025-12-04Z

- watchOS Scrolling behavior (#1012)

## [Version 3.1.37, Build 94] - 2025-12-04Z

- Fix for spontaneous sitemap switching (#1011)

## [Version 3.1.36, Build 93] - 2025-12-04Z

- Watch connectivity (#1009)
- Fix watch crown scrolling (#1010)
- Bump actions/checkout from 5 to 6 (#1007)



## [Version 3.1.34, Build 91] - 2025-11-16Z

- Revert "committed version bump: 3.2.0 (90)"
- committed version bump: 3.2.0 (90)
- Make mjpeg handling work again (#1004)

## [Version 3.1.33, Build 89] - 2025-11-06Z

- Saving Preferences for Search (#1001)
- Improve challenge handling - step 2 (#1000)

## [Version 3.1.32, Build 88] - 2025-11-05Z

- Challenge handling (#994)
- Fixes regression where UI actions are not working (#998)

## [Version 3.1.31, Build 87] - 2025-11-04Z

- Suggestion to make Items Search Field optional in Settings (#995)
- Upgrade to Kingfisher 8.6.1 for improvement on multiple requests on same URL (#996)



## [Version 3.1.29, Build 85] - 2025-10-29Z

- Use Logger also for RELEASE (#993)
- Proposal - App Icon supporting Dark mode and iOS 26 Monochrome/Tinted modes (#989)
- Clearer logging for debugging
- Complete merge
- Centralization for all static loggers (#992)

## [Version 3.1.28, Build 84] - 2025-10-25Z

- Handling of dark mode for external icons
- Handling of authentication challenges (#988)
- Address some warnings

## [Version 3.1.27, Build 83] - 2025-10-21Z

- Networktracker improvements (#981)
- Bump crowdin/github-action from 2.11.0 to 2.12.0 (#986)

## [Version 3.1.26, Build 82] - 2025-10-20Z

- remove reported source of unexplicable crashes (#985)

## [Version 3.1.25, Build 81] - 2025-10-19Z

- Improve watch icons (#983)
- improve notifications (#977)

## [Version 3.1.24, Build 80] - 2025-10-12Z

- Improve the handling for f7-icons on Apple Watch and implement static icon (#980)

## [Version 3.1.23, Build 79] - 2025-10-10Z

- Fixes a number of issues where background processing would crash (#976)

## [Version 3.1.22, Build 78] - 2025-10-10Z

- Improvement for icon rendering (#979)
- Enable navigation until full webview load (#972)

## [Version 3.1.21, Build 77] - 2025-10-02Z

- don't run Swiftlint and swiftformat an github actions
- Fix Fastfile for scheduled deploy to TestFligh.  When bump_type: '' hits the action, fastlane throws
- Renaming AGENT.md to AGENTS.md to have it considered by GitHub Copilot as well
- cachedWidgetId - Tracks which widget's content is currently cached (#974)
- Speedup network tracker by early-exiting connection attempts (#967)

## [Version 3.1.20, Build 73] - 2025-09-23Z

- isolate ServerCertificateManager to main actor (#970)
- Remove the deprecated use of WKProcessPool/processPool in OpenHABWebViewController (#965)
- Bump rexml from 3.4.1 to 3.4.2 (#969)

## [Version 3.1.19, Build 72] - 2025-09-22Z

- Workaround for compiling in Archive/Release configuration (#968)
- Migrate openHABCore to Swift 6 (#961)
- Improve watch app (#962)
- Prepare for Xcode 26 (#964)
- Upgrade Xcode (#963)
- Bump crowdin/github-action from 2.10.0 to 2.11.0 (#959)

## [Version 3.1.18, Build 71] - 2025-09-05Z

- Fixes waiting for a connection when one already exists (#958)
- Async version of notificationcenter delegate (#952)
- Fix for crash on number entry in input field (#957)
- Bump crowdin/github-action from 2.9.1 to 2.10.0 (#946)
- Transition to SVG (#955)

## [Version 3.1.17, Build 70] - 2025-08-27Z

- Fix #947 (#949)

## [Version 3.1.16, Build 69] - 2025-08-25Z

- Migration of ScreenSaver to SwiftUI (#935)
- Completion handler notification delegate instead of async version (#945)

## [Version 3.1.15, Build 68] - 2025-08-22Z

- Project settings update (#942)

## [Version 3.1.14, Build 67] - 2025-08-22Z

- Resolve off‑main SVG rendering via UIGraphicsImageRenderer. Detect SVGs and run the decoding/drawing step on the MainActor. Keep everything else background (#943)

## [Version 3.1.13, Build 66] - 2025-08-21Z

- Add missing git configuration for workflow (#941)
- Revert "Add missing git configuration for workflow"
- Revert "Add missing git configuration for workflow - edit"
- Add missing git configuration for workflow - edit
- Add missing git configuration for workflow
- Simple concurrency fix attempt at NotificationService warnings (#938)

## [Version 3.1.10, Build 62] - 2025-08-19Z

- More warning and concurrency issue fixes (#940)

## [Version 3.1.9, Build 61] - 2025-08-19Z

- Network tracker rework and Preferences improvement for strict concurrency (#937)

## [Version 3.1.8, Build 60] - 2025-08-18Z

- Stream Token Guarding: (#939)
- Restrict         update_code_signing_settings to configuration Release
- Bump actions/cache from 2 to 4 (#933)
- Bump webfactory/ssh-agent from 0.9.0 to 0.9.1 (#934)
- Bump maierj/fastlane-action from 2.2.1 to 3.1.0 (#931)
- Bump actions/checkout from 2 to 5 (#932)
- Bump crowdin/github-action from 1.4.9 to 2.9.1 (#930)
- Enable Dependabot (#929)
- Typo
- Cleanup of project
- Straighten Changelog
- Addressing swift 6 errors

## [Version 3.1.7, Build 59] - 2025-08-15Z

- Fix for #927 (#928)
- Improve Changelog

## [Version 3.1.6, Build 58] - 2025-08-14Z

- Fix for #924 (#925)
- Fixes #921 (#922)
- Moved handleMJPEGStream to be a proper instance method (#920)
- Commit changelog to CHANGELOG.md (#919)
- Fix for video sizing (#918)
- More logging for Video cells

## [Version 3.0.7, Build 29] - 2024-10-31Z
- Integration of new watch app
- Handling of SVG files on watch app

## [Version 3.0.6, Build 24] - 2024-10-30Z

- Update SVGKit to fix crash on new iPhone models (#838)
- Correct the bundle identifiers for test targets

## [Version 3.0.1, Build 5] - 2024-07-07Z

- Prefer commandDescription options over stateDescription options if an item has them

## [Version 2.4.59, Build 1580410537] - 2023-08-19Z

- Implement iconify icons
- Update Kingfisher to fix build issue

## [Version 2.4.58, Build 1580410536] - 2023-05-31Z

- Implement forceAsItem support for Charts in Sitemaps 
- Fixes #689

## [Version 2.4.53, Build 1580410519] - 2022-08-27Z

- Fixes an incompatibility with openHAB 1.x systems

## [Version 2.4.49, Build 1580410513] - 2022-06-22Z

- Fix OH3 UI integration for iOS app (#605)

## [Version 2.4.47, Build 1580410507] - 2022-04-11Z

- Fix watch app (#665)

## [Version 2.4.46, Build 1580410506] - 2022-04-09Z

- Fix intents (#657)

## [Version 2.4.45, Build 1580410503] - 2022-03-12Z

- Fixed some crashes during image processing

## [Version 2.4.44, Build 1580410502] - 2022-03-07Z

- Fix basic auth (#656)
- Show error image if SVG parsing fails (#652)
- More robust SVG rendering - Should not crash anymore / unit tests included
- Delete unsent crashlytics reports if permission dialog is canceled
- Re-enable icon type setting
- Fix certificate issues
- Fixed connection to myopenhab.org
- OpenHABCore swift package
- Migrate to Alamofire 5
- Move external dependencies to SPM
- Remove cocoapods

## [Version 2.4.15, Build 1580410464] - 2020-12-04

### Added
- Support for Shortcuts 

## [Version 2.4.13, Build 1580410462] - 2020-12-04

### Added
- Support for Shortcuts 

## [Version 2.4.5, Build 1580410454] - 2020-10-04

### Fixed
- SVGKit updated to correctly render SVG - Fix for issue #351 
- Update to Xcode 12, Swift 5.3
- Update external dependencies, migrate to FirebaseCrashlytics, remove FirebaseAnalytics
- Update to Kingfisher 5.15.5 - to resolve clash with Alamofire
- Respond to authentication challenge in WebView


## [Version 2.3.24, Build 1580410444] - 2020-05-13

### Changed
- Make crash reporting opt-in in order to comply with GDPR, refs #546

## [Version 2.3.15, Build 1580410435] - 2020-02-20

### Fixed
-  enable inline and automatic media playback, refs #540

## [Version 2.3.13, Build 1580410433] - 2020-02-15

### Fixed
- SliderUITableViewCell: if there is a formatted value in widget label, take it. Otherwise display local value. Addresses #534
- Fix segmented control, closes #538
- Use same icon cacheKey for local and remote connection, refs #536

### Changed
- add lane to upload dSYMs to Crashlytics

## [Version 2.3.12, Build 1580410432] - 2020-02-15

### Fixed


## [Version 2.3.11, Build 1580410431] - 2020-02-12

### Fixed
- fix image cache purging, refs #455
- Backed out capability in Xcode that was not used

## [Version 2.3.8, Build 1580410428] - 2020-02-12

### Fixed
- fix image cache purging, refs #455

## [Version 2.2.56, Build 1578225438] - 2020-01-05

### Fixed 
- Change of site to update list of sitemaps, fix for #514
- "Ignore SSL Certificates" toggle not only considered at startup, fix for #504

## [Version 2.2.55, Build 1577866798] - 2020-01-01

### Fixed
- Make real-time sliders optional, refs #506
- Fix for #516 - legend for charts with multiple time-series
- Fix for #517 - very long items

## [Version 2.2.54, Build 1577538804] - 2019-12-28

### Fixed
- Replace `ReachabilitySwift` with `Alamofire.NetworkReachabilityManager` and handle connection type changes
- closes #431
- closes #512
- fix infinite loop, closes #513

## [Version 2.2.50, Build 1573822048] - 2019-11-15

### Fixed
- Fixed side menu presentation
- Adjusted UTI settings to get client certificate import working properly on iOS 13.
- Reverted SPM to CocoaPods
- Handling of blank sitemap label

### Added
- Slider update in real-time
- Add connection setting called "Always send credentials" which controlls whether HTTP Basic Auth credentials should be sent for requests regardless of whether a challenge was issued by the server.  Under standard server setups, this option should be turned off.  This option can be turned on for servers which don't respond with a 401 challenge when credentials are required (#497)
- Support for more HTML colors

## [Version 2.2.47, Build 1571606105] - 2019-10-20

### Fixed
- Fixed chart legend #481: The legend parameter wasn't work anymore, legend was still displayed if set to false

### Changed
- Addressing dynamic mapping for z wave devices: aligning behavior to agreed one of for basic ui and android : https://github.com/openhab/openhab-core/issues/952, https://github.com/openhab/openhab-core/issues/1040
- New icons aligned
- Revert swiftformat to cocoapods

## [Version 2.2.41, Build 1571438550] - 2019-10-19

### Fixed
- Addressing crashes on "Selection" with Dynamic Mapping for Spotify

## [Version 2.2.40, Build 1571429231] - 2019-10-18

### Fixed 
- Addressing crashes on OpenHABSelectionTableViewController and on SegmentedUITableViewCell

## [Version 2.2.38, Build 1571347885] - 2019-10-17

### Changed
- SwiftFormat migrated with SPM
- Making use of Swift 5.1 property wrappers to reduce boilerplate code

## [Version 2.2.37, Build 1571345353] - 2019-10-17

### Fixed:
- Fixed fastlane to avoid littering changelog with irrelevant information
- Initial commit to address #182 i.e handling of dynamic mapping

### Changed
- FlexColorPicker upgraded to 1.3.1, integrated with SPM
- Parsing the information from the Item/stateDescription/options - Extending the JSON Parser
- Recognizing the relevant case in OpenHABViewController
- Convenience mapper in OpenHABWidget to map to [OpenHABWidgetMapping]
- Displaying the results in SegmentedUITableViewCell and in SelectionUITableViewCell 
- Adjusting the tests - tested with avmfritz

## [2.2.32] - 2019-10-08 

### Added:
- No new feature

### Changed:
- Colors of Frames in Dark Mode

### Fixed:
- Fixed fastlane to avoid littering changelog with irrelevant information 

### Removed:
- User tracking 

### Work In Progress:

### Security:

