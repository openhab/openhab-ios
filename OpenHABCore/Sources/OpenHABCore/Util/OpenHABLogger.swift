// Copyright (c) 2010-2022 Contributors to the openHAB project
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
import Foundation
import os.log

final class OpenHABLogger: EventMonitor {
    // let queue = DispatchQueue(label: .roo)

    // Event called when any type of Request is resumed.
    func requestDidResume(_ request: Request) {
        os_log("Resuming: %{PUBLIC}@", log: .alamofire, type: .info, request.description)
    }

    // Event called whenever a DataRequest has parsed a response.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        os_log("Finished %{PUBLIC}@", log: .alamofire, type: .debug, response.error.debugDescription)
    }
}
