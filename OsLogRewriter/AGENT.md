# OsLogRewriter - openHAB iOS Build Tool

## Commands
- **Build**: `swift build`
- **Run**: `swift run OsLogRewriter <file_path>` 
- **Clean**: `swift package clean`
- **Test**: `swift test` (runs comprehensive test suite)
- **Test Verbose**: `swift test --verbose` (shows detailed test output)

## Architecture
- **Purpose**: Swift syntax rewriter tool that transforms `os_log()` calls to `logger.debug/info/error()` calls
- **Single executable target**: OsLogRewriter in Sources/OsLogRewriter.swift
- **Library target**: OsLogRewriterLib in Sources/OsLogRewriterLib/ (for testing and reuse)
- **Dependencies**: SwiftSyntax (509.0.0+) for AST parsing/rewriting
- **Platform**: macOS 13+, Swift 6.1+
- **Context**: Part of openHAB iOS app build pipeline for log statement migration

## Code Style
- Uses SwiftSyntax AST manipulation patterns with SyntaxRewriter subclass
- Functional programming approach with syntax tree transformations
- String interpolation format: "\(variable)" in logger calls
- Error handling with stderr output and exit codes
- XCTest framework for comprehensive unit testing
- Swift 6 strict concurrency (@preconcurrency, @MainActor, Sendable)
- Property wrappers for UserDefaults (@UserDefault, @UserDefaultObject)
- Eclipse Public License 2.0 headers required on source files
