//
//  TextLabelView.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 21.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import SwiftUI

struct TextLabelView: View {
    @ObservedObject var widget: ObservableOpenHABWidget

    var body: some View {
        Text(widget.labelText ?? "")
            .font(.caption)
            .lineLimit(2)
            .foregroundColor(widget.labelcolor != "" ? Color(fromString: widget.labelcolor) : .primary)
    }
}

struct TextLabelView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[2]
        return TextLabelView(widget: widget)
    }
}
