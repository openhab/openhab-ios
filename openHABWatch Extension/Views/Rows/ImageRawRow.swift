// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Kingfisher
import OpenHABCoreWatch
import os.log
import SwiftUI

struct ImageRawRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        if let data = widget.item?.state?.components(separatedBy: ",")[safe: 1],
           let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters),
           let image = UIImage(data: decodedData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            EmptyView()
        }
    }
}

struct ImageRawRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[4]
        return ImageRawRow(widget: widget)
    }
}
