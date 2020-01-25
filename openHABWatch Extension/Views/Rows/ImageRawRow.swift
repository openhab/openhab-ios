//
//  GenericRow.swift
//  openHABWatch Extension
//
//  Created by Tim Müller-Seydlitz on 25.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import Kingfisher
import OpenHABCoreWatch
import os.log
import SwiftUI

// swiftlint:disable file_types_order
struct ImageRawRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {

        var imageView: some View {
            if let data = widget.item?.state.components(separatedBy: ",")[safe: 1],
                let decodedData = Data(base64Encoded: data, options: .ignoreUnknownCharacters),
                let image = UIImage(data: decodedData) {
                return AnyView( Image(uiImage: image)
                                .resizable()
                                .scaledToFit() )
            } else {
                return AnyView(EmptyView())
            }
        }
        return imageView
    }
}

struct ImageRawRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[4]
        return ImageRawRow(widget: widget)
    }
}
