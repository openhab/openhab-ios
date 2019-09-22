//
//  SitemapView.swift
//  openHABWatch Extension
//
//  Created by Tim Müller-Seydlitz on 22.09.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import SwiftUI

struct SwitchItem: Identifiable {
    var id = UUID()
    var name = "Licht"
    var detail = "Detail"
}

struct SitemapView: View {

    @State private var quantity = 1
    @State private var status = false
    let switchArray : [SwitchItem] = [SwitchItem(), SwitchItem(), SwitchItem()]

    var body: some View {

        List (switchArray) { switchItem in
            SwitchRow(switchItem: switchItem)
        }
        .listStyle(.carousel) //GroupedListStyle())

    }
}

struct SwitchRow: View {

    var switchItem: SwitchItem

    var body: some View {

        Toggle(isOn: self.$status) {
            HStack {
                Image(systemName: "photo")
                Text(switchItem.name).font(.callout)
                Spacer()
                Text(switchItem.detail).font(.caption)
            }
        }
        .padding()
        // .background(Color.gray)
        .cornerRadius(10)
    }

}

struct SitemapView_Previews: PreviewProvider {
    static var previews: some View {
        SitemapView()
    }
}
