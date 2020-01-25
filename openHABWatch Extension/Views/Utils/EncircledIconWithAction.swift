//
//  EncircledIconWithAction.swift
//  openHABWatch Extension
//
//  Created by Tim Müller-Seydlitz on 25.01.20.
//  Copyright © 2020 openHAB e.V. All rights reserved.
//

import SwiftUI

// swiftlint:disable file_types_order
struct EncircledIconWithAction: View {
    var systemName: String
    var action: () -> Void
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 35, height: 35)
            .overlay(
                Image(systemName: systemName)
                    .font(.headline)
            )
            .onTapGesture {
                self.action()
            }
    }
}

struct EncircledIconWithAction_Previews: PreviewProvider {
    static var previews: some View {
        EncircledIconWithAction(systemName: "chevron.up") {}
    }
}
