//
//  GenericRow.swift
//  openHABWatch Extension
//
//  Created by Tim Müller-Seydlitz on 25.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import SwiftUI

// swiftlint:disable file_types_order
struct GenericRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        HStack {
            IconView(widget: widget, settings: settings)
            VStack {
                TextLabelView(widget: widget)
                DetailTextLabelView(widget: widget)
            }
        }
    }
}

struct GenericRow_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[4]
        return GenericRow(widget: widget)
    }
}
