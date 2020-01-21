//
//  TextLabelView.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 21.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import SwiftUI

struct DetailTextLabelView: View {
    @ObservedObject var widget: ObservableOpenHABWidget

    var body: some View {
        widget.labelValue.map {
            Text($0)
                .font(.footnote)
                .lineLimit(1)
                .foregroundColor(widget.valuecolor != "" ? Color(fromString: widget.valuecolor) : .secondary)
        }
    }
}

struct DetailTextLabelView_Previews: PreviewProvider {
    static var previews: some View {
        let widget = UserData().widgets[2]
        return DetailTextLabelView(widget: widget)
    }
}
