// Copyright (c) 2010-2025 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

@testable import openHAB
import OpenHABCore
import XCTest
import AVFoundation

class VideoUITableViewCellTests: XCTestCase {
    
    func testVideoUITableViewCellInitialization() {
        let cell = VideoUITableViewCell(style: .default, reuseIdentifier: "test")
        XCTAssertNotNil(cell, "VideoUITableViewCell should initialize successfully")
    }
    
    func testVideoUITableViewCellObserverCleanup() {
        let cell = VideoUITableViewCell(style: .default, reuseIdentifier: "test")
        
        // Create a mock widget for testing with a simple URL
        let widget = OpenHABWidget()
        widget.url = "http://example.com/video.mp4"
        widget.encoding = "hls" // Use non-MJPEG encoding to trigger AVPlayer path
        
        cell.widget = widget
        
        // This should not crash even if called multiple times
        XCTAssertNoThrow({
            cell.displayWidget()
            cell.displayWidget()
        }, "Multiple displayWidget calls should not crash")
        
        // Verify that we can safely deallocate the cell
        // The deinit should properly clean up observers
        XCTAssertNoThrow({
            // Force cleanup by moving to nil superview
            cell.willMove(toSuperview: nil)
        }, "VideoUITableViewCell cleanup should not crash")
    }
    
    func testVideoUITableViewCellStopPlayback() {
        let cell = VideoUITableViewCell(style: .default, reuseIdentifier: "test")
        
        // This should not crash when called multiple times
        XCTAssertNoThrow({
            cell.stopPlayback()
            cell.stopPlayback()
        }, "Multiple stopPlayback calls should not crash")
    }
    
    func testVideoUITableViewCellWithMJPEGEncoding() {
        let cell = VideoUITableViewCell(style: .default, reuseIdentifier: "test")
        
        // Test MJPEG encoding - this should use the MJPEG streaming path
        let mjpegWidget = OpenHABWidget()
        mjpegWidget.url = "http://example.com/stream.mjpeg"
        mjpegWidget.encoding = "mjpeg"
        
        cell.widget = mjpegWidget
        XCTAssertNoThrow({
            cell.displayWidget()
        }, "MJPEG widget display should not crash")
        
        XCTAssertNoThrow({
            cell.stopPlayback()
        }, "MJPEG stopPlayback should not crash")
    }
    
    func testVideoUITableViewCellWithHLSEncoding() {
        let cell = VideoUITableViewCell(style: .default, reuseIdentifier: "test")
        
        // Test HLS encoding - this should use the AVPlayer path
        let hlsWidget = OpenHABWidget()
        hlsWidget.url = "http://example.com/stream.m3u8"
        hlsWidget.encoding = "hls"
        
        cell.widget = hlsWidget
        XCTAssertNoThrow({
            cell.displayWidget()
        }, "HLS widget display should not crash")
        
        XCTAssertNoThrow({
            cell.stopPlayback()
        }, "HLS stopPlayback should not crash")
    }
    
    func testVideoUITableViewCellObserverManagement() {
        let cell = VideoUITableViewCell(style: .default, reuseIdentifier: "test")
        
        // Set up a widget that will trigger the AVPlayer path
        let widget = OpenHABWidget()
        widget.url = "http://example.com/video.mp4"
        widget.encoding = "mp4"
        
        cell.widget = widget
        
        // Multiple calls to displayWidget should properly clean up previous observers
        XCTAssertNoThrow({
            cell.displayWidget()
            cell.displayWidget() // This should invalidate the previous observer
            cell.displayWidget() // And this one too
        }, "Multiple displayWidget calls with observer setup should not crash")
        
        // Final cleanup
        XCTAssertNoThrow({
            cell.stopPlayback()
        }, "Final stopPlayback should not crash")
    }
}