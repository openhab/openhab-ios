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
                Image(uiImage: (item.dataIsValid ? item.imageFromData() : UIImage(systemName: "photo"))!)
                    .resizable()
                    .frame(width: 25.0, height: 25.0)
                Text(item.name)
                    .font(.callout)
                Spacer()
                Text("llls")
                    .font(.caption)
            }
        }.padding()
            .cornerRadius(10)
    }
}

struct SwitchRow_Previews: PreviewProvider {
    static var previews: some View {
        return SwitchRow(item: sitemapData[0])
            .previewLayout(.fixed(width: 300, height: 70))
    }
}
