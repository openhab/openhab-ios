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

import SwiftUI

// swiftlint:disable file_types_order
struct ColorSelection: View {
    var body: some View {
        let spectrum = Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red])
        let conic = AngularGradient(gradient: spectrum, center: .center, angle: .degrees(-90))
        return Circle()
            .fill(conic)
            .gesture(
                DragGesture(minimumDistance: 0,
                            coordinateSpace: .local)
                    .onChanged { value in
                        value.translation. location

                        // self.position = value.location
                    }
                    .onEnded { _ in
                        // self.position = .zero
                    }
            )
    }
}

struct ColorSelection_Previews: PreviewProvider {
    static var previews: some View {
        ColorSelection()
    }
}
