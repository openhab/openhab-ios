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

import CoreGraphics
@testable import openHAB
import Testing

struct VideoAspectRatioTests {
    @Test(arguments: [CGSize(width: 1920, height: 1080), CGSize(width: 640, height: 480), CGSize(width: 1080, height: 1920)])
    func knownSizeYieldsWidthOverHeight(size: CGSize) throws {
        let aspectRatio = try #require(size.videoAspectRatio)
        #expect(aspectRatio == size.width / size.height)
    }

    @Test(arguments: [CGSize.zero, CGSize(width: 1920, height: 0), CGSize(width: 0, height: 1080), CGSize(width: -1, height: 1)])
    func unknownSizeYieldsNil(size: CGSize) {
        #expect(size.videoAspectRatio == nil)
    }
}
