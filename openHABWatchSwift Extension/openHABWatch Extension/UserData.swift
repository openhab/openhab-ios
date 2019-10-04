//
//  UserData.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 04.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

import Combine
import SwiftUI

let sitemapData: [Item] = [Item(name: "Light1",
                                label: "Light Cellar",
                                state: true,
                                link: "llsl://101.10.101.11")!]

final class UserData: ObservableObject {
    @Published var sitemap = sitemapData
}
