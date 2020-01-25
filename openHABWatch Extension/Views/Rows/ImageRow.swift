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
struct ImageRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    var url: URL?
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {

        KFImage(url)
        .onSuccess { retrieveImageResult in
            os_log("Success loading icon: %{PUBLIC}s", log: .notifications, type: .debug, "\(retrieveImageResult)")
        }
        .onFailure { kingfisherError in
            os_log("Failure loading icon: %{PUBLIC}s", log: .notifications, type: .debug, kingfisherError.localizedDescription)
        }
        .placeholder {
            Image(systemName: "arrow.2.circlepath.circle")
                .font(.callout)
                .opacity(0.3)
        }
        .cancelOnDisappear(true)
        .resizable()
        .scaledToFit()
    }
}

struct ImageRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[4]
        return ImageRow(widget: widget)
    }
}
