// Copyright (c) 2010-2022 Contributors to the openHAB project
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
import Fuzi

public class OpenHABLinkedPage: NSObject, Decodable {
    private enum CodingKeys: String, CodingKey {
        case pageId = "id"
        case title
        case icon
        case link
    }

    public var pageId = ""
    public var title = ""
    public var icon = ""
    public var link = ""

    public init(xml xmlElement: XMLElement) {
        super.init()
        for child in xmlElement.children {
            switch child.tag {
            case "title": title = child.stringValue
            case "icon": icon = child.stringValue
            case "link": link = child.stringValue
            case "id": pageId = child.stringValue
            default:
                break
            }
        }
    }
}
