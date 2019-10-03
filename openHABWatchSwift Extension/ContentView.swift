//
//  ContentView.swift
//  openHABWatchSwift2 Extension
//
//  Created by Tim Müller-Seydlitz on 03.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    // var sitemap: Sitemap

    @State private var quantity = 1
    @State private var status = false
    let switchArray: [Item] = [Item(name: "Light1", label: "Light Cellar", state: "ON", link: "llsl://101.10.101.11")!]

    var body: some View {
        ZStack {
            List(switchArray) { switchItem in
                SwitchRow(item: switchItem)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
