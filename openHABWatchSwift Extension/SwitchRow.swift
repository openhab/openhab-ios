// Copyright (c) 2010-2019 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import SwiftUI

struct SwitchRow: View {
    @ObservedObject var item: Item

    var body: some View {
        Toggle(isOn: $item.state) {
            HStack {
                setImage()
                Text(item.name).font(.callout)
                Spacer()
                Text("llls").font(.caption)
            }
        }.padding()
            .cornerRadius(10)
    }

    func setImage() -> Image {
        item.lazyLoadImage(url: URL(string: item.link)!)
        return Image(uiImage: item.image ?? UIImage())
    }
}

struct SwitchRow_Previews: PreviewProvider {
    @ObservedObject static var testItem = Item(name: "Light0",
                                               label: "Light Ground Floor",
                                               state: true,
                                               link: "https://192.168.2.15:8444/icon/switch?state=OFF")!
    static var previews: some View {
        SwitchRow(item: testItem)
            .previewLayout(.fixed(width: 300, height: 70))
    }
}
