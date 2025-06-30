# openHAB iOS Development Guide

## Build/Test Commands
- Build: `xcodebuild -workspace openHAB.xcworkspace -scheme openHAB`
- Test all: `fastlane unittests` or `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- Single test: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABTestsSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:openHABTestsSwift/TestClassName/testMethodName`
- Beta build: `fastlane beta`
- UI tests: `xcodebuild test -workspace openHAB.xcworkspace -scheme openHABUITests`

## Architecture
- **Main app**: openHAB/ - UIKit + SwiftUI hybrid iOS app targeting iOS 16+
- **Core library**: OpenHABCore/ - Swift Package with shared business logic, models, API clients
- **Watch app**: openHABWatch/ - watchOS companion app (watchOS 10+)
- **Extensions**: openHABIntents/ (Siri shortcuts), NotificationService/ (rich notifications)
- **Tests**: openHABTestsSwift/ (XCTest), openHABUITests/ (UI automation)
- **Dependencies**: Kingfisher (image loading), SwiftUI, Firebase, OpenAPI runtime, SFSafeSymbols

## Code Style
- Swift 5.10, strict concurrency enabled
- SwiftUI for new views, UIKit legacy TableViewCells for sitemap rendering
- Naming: PascalCase classes, camelCase properties/methods, OpenHAB prefix for core types
- Use SFSafeSymbols for SF Symbols, avoid force unwrapping, prefer optionals
- TableViewCell pattern: GenericUITableViewCell subclasses for sitemap widgets
- Error handling: Result types in OpenHABCore, UIKit error alerts in main app
