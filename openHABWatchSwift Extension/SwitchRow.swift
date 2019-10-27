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
    @EnvironmentObject var userData: UserData
    var item: Item

    var itemIndex: Int {
        userData.sitemap.firstIndex { $0.id == item.id }!
    }

    var body: some View {
        Toggle(isOn: $userData.sitemap[itemIndex].state) {
            HStack {
                 setImage()
                Image(systemName: "photo")
                Text(item.name).font(.callout)
                Spacer()
                Text("llls").font(.caption)
            }
        }.padding()
            .cornerRadius(10)
    }

    func setImage() -> Image {
        $userData.sitempap[itemIndex]. lazyLoadImage(url: URL(string: item.link)!)
        return Image(uiImage: viewModel.image ?? UIImage())
    }
}

struct SwitchRow_Previews: PreviewProvider {
    static var previews: some View {
        SwitchRow(item: sitemapData[0])
            .environmentObject(UserData())
            .previewLayout(.fixed(width: 300, height: 70))
    }
}
