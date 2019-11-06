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

import Alamofire
import Combine
import Foundation
import os.log
import SwiftUI

class Item: Identifiable, ObservableObject, CommItem {
    private static var idSequence = sequence(first: 1) { $0 + 1 }

    let objectWillChange = ObservableObjectPublisher()
    private var commandOperation: Alamofire.Request?

    var id: Int

    let name: String
    let label: String
    var link: String

    @Published var state: Bool

    private var statePublisher: AnyPublisher<Bool, Never> {
        $state
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init?(name: String, label: String, state: Bool, link: String) {
        self.name = name
        self.label = label
        self.state = state
        self.link = link
        guard let id = Item.idSequence.next() else { return nil }
        self.id = id

        _ = statePublisher
            .receive(on: RunLoop.main)
            .map { value -> String in
                value ? "ON" : "OFF"
            }
            .sink { receivedValue in
                // sink is the subscriber and terminates the pipeline
                self.sendCommand(self, commandToSend: receivedValue)
                print("Sending to: \(name) command: \(receivedValue)")
            }
    }

    func sendCommand(_ item: Item?, commandToSend command: String?) {
        if commandOperation != nil {
            commandOperation?.cancel()
            commandOperation = nil
        }
        if let item = item, let command = command {
            commandOperation = NetworkConnection.sendCommand(item: item, commandToSend: command)
            commandOperation?.resume()
        }
    }
}

extension Item {
    convenience init? (with codingData: OpenHABItem.CodingData?) {
        guard let codingData = codingData else { return nil }
        self.init(name: codingData.name, label: codingData.label ?? "", state: codingData.state == "true" ? true : false, link: codingData.link)
    }
}
