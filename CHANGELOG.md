# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

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

