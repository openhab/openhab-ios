//
//  Rollershutter.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 24.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import SwiftUI

// swiftlint:disable file_types_order
struct RollershutterRow: View {
    @ObservedObject var widget: ObservableOpenHABWidget
    @ObservedObject var settings = ObservableOpenHABDataObject.shared

    var body: some View {
        VStack {
            HStack {
                IconView(widget: widget, settings: settings)
                TextLabelView(widget: widget)
                Spacer()
            }
            HStack {
                Spacer()

                Image(systemName: "chevron.up")
                .onTapGesture {
                    self.widget.sendCommand("UP")
                }
                .font(.headline)

                Spacer()

                Image(systemName: "square")
                .onTapGesture {
                    self.widget.sendCommand("STOP")
                }
                .font(.headline)

                Spacer()

                Image(systemName: "chevron.down")
                .onTapGesture {
                    self.widget.sendCommand("DOWN")
                }
                .font(.headline)

                Spacer()
            }
            .frame(height: 50)

        }
    }
}

struct Rollershutter_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[5]
        return RollershutterRow(widget: widget)
    }
}
