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

import Foundation
import Kingfisher
import SwiftUI
import WatchKit

class HostingController: WKHostingController<ContentView> {
    override var body: ContentView {
        ContentView(viewModel: UserData())
    }
}

// MARK: Kingfisher authentication with NSURLCredential

extension HostingController: AuthenticationChallengeResponsable {
    // sessionDelegate.onReceiveSessionTaskChallenge
    func downloader(_ downloader: ImageDownloader,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionTaskChallenge(URLSession(configuration: .default), task, challenge)
        completionHandler(disposition, credential)
    }

    // sessionDelegate.onReceiveSessionChallenge
    func downloader(_ downloader: ImageDownloader,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = onReceiveSessionChallenge(URLSession(configuration: .default), challenge)
        completionHandler(disposition, credential)
    }
}
