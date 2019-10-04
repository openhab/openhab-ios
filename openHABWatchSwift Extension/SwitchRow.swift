//
//  SwitchRow.swift
//  openHABWatchSwift2 Extension
//
//  Created by Tim Müller-Seydlitz on 03.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import SwiftUI

struct SwitchRow: View {
    @State var item: Item

    var body: some View {
        Toggle(isOn: $item.state) {
            HStack {
                Image(systemName: "photo")
                Text(item.name).font(.callout)
                Spacer()
                Text("llls").font(.caption)
            }
        }.padding()
            .cornerRadius(10)
    }
}

struct SwitchRow_Previews: PreviewProvider {
    static var previews: some View {
        let item1 = Item(name: "Light1",
                         label: "Light Cellar",
                         state: true,
                         link: "llsl://101.10.101.11")
        return SwitchRow(item: item1!)
            .previewLayout(.fixed(width: 300, height: 70))
    }
}
