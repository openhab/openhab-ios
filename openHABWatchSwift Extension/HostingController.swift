//
//  HostingController.swift
//  openHABWatchSwift2 Extension
//
//  Created by Tim Müller-Seydlitz on 03.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation
import SwiftUI
import WatchKit

class HostingController: WKHostingController<AnyView> {
    override var body: AnyView {
        return AnyView(ContentView().environmentObject(UserData()))
    }
}
