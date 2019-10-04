//
//  ContentView.swift
//  openHABWatchSwift2 Extension
//
//  Created by Tim Müller-Seydlitz on 03.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userData: UserData

    var body: some View {
        ForEach(userData.sitemap) { switchItem in
            SwitchRow(item: switchItem)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
