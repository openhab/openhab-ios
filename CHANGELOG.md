# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

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

