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
@testable import OpenHABCore
import Testing

private struct TimestampModel: Decodable {
    let timestamp: Date
}

struct DateFormattingTests {
    // MARK: - ISO8601 Date Parsing Tests

    @Test func iSO8601DateParsingWithFractionalSeconds() throws {
        let dateString = "2025-12-21T10:30:45.123+00:00"
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date != nil)
    }

    @Test func iSO8601DateParsingWithoutFractionalSeconds() throws {
        let decoder = JSONDecoder.makeISO8601TolerantDecoder()

        // Verify tolerant decoder handles dates without fractional seconds
        let json1 = #"{"timestamp": "2025-12-21T10:30:45Z"}"#
        let model1 = try decoder.decode(TimestampModel.self, from: Data(json1.utf8))
        #expect(model1.timestamp.timeIntervalSince1970 > 0)

        let json2 = #"{"timestamp": "2025-12-21T10:30:45+00:00"}"#
        let model2 = try decoder.decode(TimestampModel.self, from: Data(json2.utf8))
        #expect(model2.timestamp.timeIntervalSince1970 > 0)
    }

    @Test func iSO8601DateParsingWithZuluTimeZone() throws {
        let dateString = "2025-12-21T10:30:45.123Z"
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date != nil)
    }

    @Test func iSO8601DateParsingWithPositiveTimeZone() throws {
        let dateString = "2025-12-21T10:30:45.123+05:30"
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date != nil)
    }

    @Test func iSO8601DateParsingWithNegativeTimeZone() throws {
        let dateString = "2025-12-21T10:30:45.123-08:00"
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date != nil)
    }

    @Test func iSO8601DateParsingWithMilliseconds() throws {
        let dateString = "2025-12-21T10:30:45.999+00:00"
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date != nil)
    }

    @Test func iSO8601DateParsingWithInvalidFormat() throws {
        let dateString = "not a date"
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date == nil)
    }

    @Test func iSO8601DateParsingWithEmptyString() throws {
        let dateString = ""
        let date = try? Date(dateString, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(date == nil)
    }

    // MARK: - ISO8601 Date Formatting Tests

    @Test func iSO8601DateFormattingWithFractionalSeconds() throws {
        // Create a date with a known value
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 21
        components.hour = 10
        components.minute = 30
        components.second = 45
        components.nanosecond = 123_000_000 // 123 milliseconds
        components.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))

        // Verify the format includes fractional seconds
        #expect(formatted.contains("."))
        #expect(formatted.contains("2025-12-21"))
        #expect(formatted.contains("10:30:45"))
    }

    @Test func iSO8601DateRoundTrip() throws {
        // Test that formatting and parsing a date produces the same value (within millisecond precision)
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 21
        components.hour = 10
        components.minute = 30
        components.second = 45
        components.nanosecond = 123_000_000 // 123 milliseconds
        components.timeZone = TimeZone(secondsFromGMT: 0)

        guard let originalDate = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = originalDate.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        let parsedDate = try? Date(formatted, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))

        #expect(parsedDate != nil)
        // Compare dates within 1 millisecond tolerance due to potential rounding
        if let parsedDate {
            let difference = abs(originalDate.timeIntervalSince(parsedDate))
            #expect(difference < 0.001) // Less than 1 millisecond
        }
    }

    // MARK: - JSON Decoder Date Strategy Tests

    @Test func jSONDecoderWithISO8601Dates() throws {
        let json = #"{"timestamp": "2025-12-21T10:30:45.123+00:00"}"#

        let decoder = JSONDecoder.makeISO8601TolerantDecoder()
        let model = try decoder.decode(TimestampModel.self, from: Data(json.utf8))

        #expect(model.timestamp.timeIntervalSince1970 > 0)
    }

    @Test func jSONDecoderWithISO8601DatesWithoutFractionalSeconds() throws {
        let decoder = JSONDecoder.makeISO8601TolerantDecoder()

        // Test with Z timezone format
        let json1 = #"{"timestamp": "2025-12-21T10:30:45Z"}"#
        let model1 = try decoder.decode(TimestampModel.self, from: Data(json1.utf8))
        #expect(model1.timestamp.timeIntervalSince1970 > 0)

        // Test with +00:00 timezone format
        let json2 = #"{"timestamp": "2025-12-21T10:30:45+00:00"}"#
        let model2 = try decoder.decode(TimestampModel.self, from: Data(json2.utf8))
        #expect(model2.timestamp.timeIntervalSince1970 > 0)
    }

    @Test func jSONDecoderWithInvalidDate() throws {
        let json = #"{"timestamp": "not a valid date"}"#

        let decoder = JSONDecoder.makeISO8601TolerantDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode(TimestampModel.self, from: Data(json.utf8))
        }
    }

    // MARK: - Date/Time Formatting Tests

    @Test func dateTimeFormattingWithHourMinuteSecond() throws {
        var calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)! // deterministic on CI
        calendar.timeZone = tz

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = tz
        components.year = 2025
        components.month = 12
        components.day = 21
        components.hour = 14
        components.minute = 30
        components.second = 45

        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        // Use ISO8601 formatting to avoid locale-dependent output on CI.
        let isoStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: tz)

        let formatted = date.formatted(isoStyle)

        #expect(formatted.contains("T14:30:45"))
    }

    @Test func dateFormattingAbbreviated() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 21
        components.timeZone = TimeZone.current

        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(date: .abbreviated, time: .shortened)

        // Should contain date components (exact format depends on locale)
        #expect(!formatted.isEmpty)
    }

    @Test func dateFormattingTimeOmitted() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 21
        components.timeZone = TimeZone.current

        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(date: .abbreviated, time: .omitted)

        // Should contain only date, no time
        #expect(!formatted.isEmpty)
        // Should contain year or month indicator (format varies by locale)
    }

    // MARK: - Log Date Format Tests (en_US_POSIX)

    @Test func logDateFormattingWithPOSIXLocale() throws {
        // Test date formatting with en_US_POSIX locale for consistent log output
        let date = Date()

        let formatted = date.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        )

        // Verify format structure (should have separators and proper length)
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("/")) // Date separator
        #expect(formatted.contains(":")) // Time separator
        // Should be properly formatted with padding (minimum expected length)
        #expect(formatted.count > 15)
    }

    @Test func logDateFormattingWithSingleDigitsPOSIXLocale() throws {
        // Test with single digit month/day to verify two-digit padding
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 1 // Single digit month
        dateComponents.day = 5 // Single digit day
        dateComponents.hour = 12
        dateComponents.minute = 0
        dateComponents.second = 0

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        )

        // Should contain padded month and day (01, 05)
        #expect(formatted.contains("01"))
        #expect(formatted.contains("05"))
        #expect(formatted.contains("2025"))
    }

    @Test func logDateFormattingConsistencyWithPOSIXLocale() throws {
        // Verify that en_US_POSIX locale produces consistent, non-localized output
        let date1 = Date()
        let date2 = Date()

        let formatted1 = date1.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        )

        let formatted2 = date2.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .locale(Locale(identifier: "en_US_POSIX"))
        )

        // Both should use consistent format with en_US_POSIX locale
        #expect(!formatted1.isEmpty)
        #expect(!formatted2.isEmpty)
        #expect(formatted1.contains("/")) // US date separator
        #expect(formatted2.contains("/"))
    }

    // MARK: - Screen Saver Time Format Tests

    @Test func screenSaverTime24HourFormatWithLeadingZeros() throws {
        // Test 24-hour format with leading zeros for screen saver
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 5
        dateComponents.second = 3

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
        )

        // Should have leading zeros: 09:05:03
        #expect(formatted.contains("09"))
        #expect(formatted.contains("05"))
        #expect(formatted.contains("03"))
    }

    @Test func screenSaverTime12HourFormatNaturalStyle() throws {
        // Test 12-hour format with natural style (no leading zero for hours)
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 5

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(
            .dateTime
                .hour(.defaultDigits(amPM: .narrow))
                .minute(.twoDigits)
        )

        // Should have natural hour display (9, not 09) with padded minutes
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("05")) // Minutes should be padded
    }

    @Test func screenSaverTimeMidnightFormat() throws {
        // Test midnight (00:00:00) with 24-hour format
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
        )

        // Should display 00:00:00
        #expect(formatted.contains("00"))
    }

    @Test func screenSaverTimeWithoutSeconds() throws {
        // Test time format without seconds (HH:mm) - verify format structure
        let date = Date()

        let formatted = date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )

        // Verify format structure (should contain time separator and proper length)
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":"))
        // Should have format like "HH:mm" (minimum 5 characters with colon)
        #expect(formatted.count >= 5)
    }

    @Test func screenSaverTime24HourVs12HourFormatting() throws {
        // Test the difference between 24-hour and 12-hour formatting
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 5
        dateComponents.second = 3

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        // 24-hour format: should have leading zero (09:05:03)
        let format24Hour = date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
        )

        // 12-hour format: natural style without leading zero for hour (9:05:03 AM)
        let format12Hour = date.formatted(
            .dateTime
                .hour(.defaultDigits(amPM: .narrow))
                .minute(.twoDigits)
                .second(.twoDigits)
        )

        // Both should be non-empty but formatted differently
        #expect(!format24Hour.isEmpty)
        #expect(!format12Hour.isEmpty)
        // 24-hour should contain "09" while 12-hour may contain "9" without leading zero
        #expect(format24Hour.contains("09"))
    }

    // MARK: - Notification Timestamp Format Tests

    @Test func notificationTimestampWithLongDateStandardTime() throws {
        // Test notification format with long date and standard time (closest to original DateFormatter medium)
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 12
        dateComponents.day = 21
        dateComponents.hour = 14
        dateComponents.minute = 30
        dateComponents.second = 45
        dateComponents.timeZone = TimeZone.current

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(date: .long, time: .standard)

        // Should contain date and time with seconds
        #expect(!formatted.isEmpty)
        // Exact format depends on locale, but should contain all components
    }

    @Test func notificationTimestampIncludesSeconds() throws {
        // Verify that standard time format includes seconds (unlike shortened)
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.hour = 14
        dateComponents.minute = 30
        dateComponents.second = 45
        dateComponents.timeZone = TimeZone.current

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let standardFormat = date.formatted(date: .omitted, time: .standard)
        let shortenedFormat = date.formatted(date: .omitted, time: .shortened)

        // Standard should be longer than shortened (includes seconds)
        #expect(standardFormat.count >= shortenedFormat.count)
    }

    @Test func notificationTimestampConsistentFormat() throws {
        // Test that notification timestamps are formatted consistently
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 1
        dateComponents.day = 5
        dateComponents.hour = 9
        dateComponents.minute = 7
        dateComponents.second = 3
        dateComponents.timeZone = TimeZone.current

        guard let date = calendar.date(from: dateComponents) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = date.formatted(date: .long, time: .standard)

        // Should produce a non-empty, readable timestamp
        #expect(!formatted.isEmpty)
        #expect(formatted.count > 10) // Should have reasonable length
    }
}
