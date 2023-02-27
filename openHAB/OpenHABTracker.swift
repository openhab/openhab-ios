// Copyright (c) 2010-2023 Contributors to the openHAB project
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
import OpenHABCore
import os.log
import SystemConfiguration

protocol OpenHABTrackerDelegate: AnyObject {
    func openHABTracked(_ openHABUrl: URL?, version: Int)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error)
}

protocol OpenHABTrackerExtendedDelegate: OpenHABTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: NetworkReachabilityManager.NetworkReachabilityStatus)
}

class OpenHABTracker: NSObject {
    static var shared = OpenHABTracker()

    public var multicastDelegate = MulticastDelegate<OpenHABTrackerDelegate>()
    private var oldReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus?
    private let reach = NetworkReachabilityManager()
    private var openHABDemoMode = false
    private var openHABLocalUrl = ""
    private var openHABRemoteUrl = ""
    private var netService: NetService?
    private var restartTimer: Timer?

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(restart), name: NSNotification.Name("org.openhab.preferences.saved"), object: nil)
        start()
    }

    @objc
    func restart() {
        reach?.stopListening()
        start()
    }

    private func start() {
        openHABDemoMode = Preferences.demomode
        openHABLocalUrl = Preferences.localUrl
        openHABRemoteUrl = Preferences.remoteUrl

        #if DEBUG
        // always activate demo mode for UITest
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            openHABDemoMode = true
        }
        #endif

        // Start NetworkReachabilityManager.Listener
        oldReachabilityStatus = reach?.status
        reach?.startListening { [weak self] status in
            guard let self else { return }
            let nStatus = status
            // use a timer to prevent bouncing/flapping around when switching between wifi, vpn, and wwan
            self.restartTimer?.invalidate()
            self.restartTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                if nStatus != self.oldReachabilityStatus {
                    if let oldReachabilityStatus = self.oldReachabilityStatus {
                        os_log("OpenHABTracker Network status changed from %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, self.string(from: oldReachabilityStatus) ?? "", self.string(from: nStatus) ?? "")
                    }
                    self.oldReachabilityStatus = nStatus
                    if self.isNetworkConnected() {
                        self.restart()
                    }
                }
            }
        }

        // Check if any network is available
        if isNetworkConnected() {
            // Check if demo mode is switched on in preferences
            if openHABDemoMode {
                os_log("OpenHABTracker demo mode preference is on", log: .default, type: .info)
                tryDemoMode()
            } else {
                if isNetworkWiFi(), openHABLocalUrl.isEmpty {
                    startDiscovery()
                } else {
                    os_log("OpenHABTracker network trying all", log: .default, type: .info)
                    tryAll()
                }
            }
        } else {
            os_log("OpenHABTracker network not available", log: .default, type: .info)
            multicastDelegate.invoke { $0.openHABTrackingError(errorMessage("network_not_available")) }
        }
    }

    private func tryDiscoveryUrl(_ discoveryUrl: URL?) {
        multicastDelegate.invoke { $0.openHABTrackingProgress(NSLocalizedString("connecting_discovered", comment: "")) }
        tryUrl(discoveryUrl)
    }

    private func tryDemoMode() {
        multicastDelegate.invoke { $0.openHABTrackingProgress(NSLocalizedString("running_demo_mode", comment: "")) }
        tryUrl(URL(staticString: "https://demo.openhab.org"))
    }

    /// Attemps to connect to the URL and get the openHAB version
    /// - Parameter tryUrl: Completes with the url and version of openHAB that succeeded, or an Error object if failed
    private func tryUrl(_ tryUrl: URL?) {
        getServerInfoForUrl(tryUrl) { url, version, error in
            if let error {
                self.multicastDelegate.invoke { $0.openHABTrackingError(error) }
            } else {
                self.appData?.openHABVersion = version
                self.appData?.openHABRootUrl = url?.absoluteString ?? ""
                self.multicastDelegate.invoke { $0.openHABTracked(url, version: version) }
            }
        }
    }

    /// Attemps to connect in parallel to the remote and local URLs if configured, the first URL to succeed wins
    private func tryAll() {
        var urls = [(url: String, delay: Double)]()
        if !openHABLocalUrl.isEmpty {
            urls.append((url: openHABLocalUrl, delay: 0.0))
        }
        if !openHABRemoteUrl.isEmpty {
            urls.append((url: openHABRemoteUrl, delay: openHABLocalUrl.isEmpty ? 0 : 1.5))
        }
        if urls.isEmpty {
            multicastDelegate.invoke { $0.openHABTrackingError(errorMessage("error")) }
            return
        }
        multicastDelegate.invoke { $0.openHABTrackingProgress(NSLocalizedString("connecting", comment: "")) }
        tryUrls(urls) { url, version, error in
            if let error {
                os_log("OpenHABTracker failed %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
                self.multicastDelegate.invoke { $0.openHABTrackingError(error) }
            } else {
                self.appData?.openHABVersion = version
                self.appData?.openHABRootUrl = url?.absoluteString ?? ""
                self.multicastDelegate.invoke { $0.openHABTracked(url, version: version) }
            }
        }
    }

    /// Tries to connect in parallel to all URL's passed in and completes when either the first requests succeedes, or all fail.
    /// - Parameters:
    ///   - urls: Tuple of String URLS and a request Delay value
    ///   - completion: Completes with the url and version of openHAB that succeeded, or an Error object if all failed
    private func tryUrls(_ urls: [(url: String, delay: Double)], completion: @escaping (URL?, Int, Error?) -> Void) {
        var isRequestCompletedSuccessfully = false
        // request in flight
        var requests = [DataRequest]()
        // timers that have yet to be executed
        var timers = [(url: URL, timer: Timer)]()
        for item in urls {
            let url = URL(string: item.url)!
            let restUrl = URL(string: "rest/", relativeTo: url)!
            let timer = Timer.scheduledTimer(withTimeInterval: item.delay, repeats: false) { _ in
                let request = NetworkConnection.shared.manager.request(restUrl, method: .get)
                    .validate()
                requests.append(request)
                // remove us from the outstanding timer list
                timers.removeAll(where: { $0.url == url })
                request.responseData { response in
                    // remove us from the outstanding request list
                    requests.removeAll(where: { $0 == request })
                    switch response.result {
                    case let .success(data):
                        let version = self.getServerInfoFromData(data: data)
                        if version > 0, !isRequestCompletedSuccessfully {
                            isRequestCompletedSuccessfully = true
                            completion(url, version, nil)
                            // cancel any timers not yet fired
                            timers.forEach { $0.timer.invalidate() }
                            // cancel any requests still in flight
                            requests.forEach { $0.cancel() }
                        }
                    case let .failure(error):
                        os_log("OpenHABTracker request failure %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
                    }
                    // check if we are the last attempt
                    if !isRequestCompletedSuccessfully, requests.isEmpty, timers.isEmpty {
                        os_log("OpenHABTracker last response", log: .notifications, type: .error)
                        if !isRequestCompletedSuccessfully {
                            completion(nil, 0, self.errorMessage("network_not_available"))
                        }
                    }
                }
                request.resume()
            }
            timers.append((url, timer))
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Attempts to parse the data response from a request and determine if its an openHAB server and its server version
    /// - Parameter data: request data
    /// - Returns: Version of openHAB or -1 if not an openHAB server
    private func getServerInfoFromData(data: Data) -> Int {
        do {
            let serverProperties = try data.decoded(as: OpenHABServerProperties.self)
            os_log("OpenHABTracker openHAB version %@", log: .remoteAccess, type: .info, serverProperties.version)
            // OH versions 2.0 through 2.4 return "1" as thier version, so set the floor to 2 so we do not think this is a OH 1.x serevr
            return max(2, Int(serverProperties.version) ?? 2)
        } catch {
            // testing for OH 1.x
            let str = String(decoding: data, as: UTF8.self)
            if str.hasPrefix("<?xml") {
                return 1
            } else {
                os_log("OpenHABTracker Could not decode response", log: .notifications, type: .error)
                return -1
            }
        }
    }

    /// Attempts to connect to a URL and determine its server version
    /// - Parameters:
    ///   - url: URL of the openHAB server
    ///   - completion: Completes with the url and version of openHAB that succeeded, or an Error object if failed
    private func getServerInfoForUrl(_ url: URL?, completion: @escaping (URL?, Int, Error?) -> Void) {
        let strUrl = url?.absoluteString ?? ""
        os_log("OpenHABTracker getServerInfo, trying: %{PUBLIC}@", log: .default, type: .info, strUrl)
        NetworkConnection.tracker(openHABRootUrl: strUrl) { response in
            os_log("OpenHABTracker getServerInfo, recieved data for URL: %{PUBLIC}@", log: .default, type: .info, strUrl)
            switch response.result {
            case let .success(data):
                let version = self.getServerInfoFromData(data: data)
                if version > 0 {
                    completion(url, version, nil)
                } else {
                    completion(url, 0, self.errorMessage("error"))
                }
            case let .failure(error):
                os_log("OpenHABTracker getServerInfo ERROR for %{PUBLIC}@ : %{PUBLIC}@ %d", log: .remoteAccess, type: .error, strUrl, error.localizedDescription, response.response?.statusCode ?? 0)
                completion(url, 0, error)
            }
        }
    }

    private func startDiscovery() {
        os_log("OpenHABTracking starting Bonjour discovery", log: .default, type: .info)
        multicastDelegate.invoke { $0.openHABTrackingProgress(NSLocalizedString("discovering_oh", comment: "")) }
        netService = NetService(domain: "local.", type: "_openhab-server-ssl._tcp.", name: "openHAB-ssl")
        netService!.delegate = self
        netService!.resolve(withTimeout: 5.0)
    }

    func normalizeUrl(_ url: String?) -> String? {
        if let url, url.hasSuffix("/") {
            return String(url.dropLast())
        }
        return url
    }

    func isNetworkConnected() -> Bool {
        reach?.isReachable ?? false
    }

    func isNetworkWiFi() -> Bool {
        reach?.isReachableOnEthernetOrWiFi ?? false
    }

    func string(from status: NetworkReachabilityManager.NetworkReachabilityStatus) -> String? {
        switch status {
        case .unknown, .notReachable:
            return "unreachable"
        case let .reachable(connectionType):
            return connectionType == .ethernetOrWiFi ? "WiFi" : "WWAN"
        }
    }

    func errorMessage(_ message: String) -> NSError {
        var errorDetail: [AnyHashable: Any] = [:]
        errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString(message, comment: "")
        return NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String: Any])
    }
}

extension OpenHABTracker: NetServiceDelegate, NetServiceBrowserDelegate {
    // NSNetService delegate methods for publication
    func netServiceDidResolveAddress(_ resolvedNetService: NetService) {
        func getStringIp(fromAddressData dataIn: Data?) -> String? {
            var ipString: String?
            let data = dataIn! as NSData
            let socketAddress: sockaddr_in = data.castToCPointer()
            ipString = String(cString: inet_ntoa(socketAddress.sin_addr), encoding: .ascii)
            return ipString
        }

        guard let data = resolvedNetService.addresses?.first else { return }
        let resolvedComponents: URLComponents = {
            var components = URLComponents()
            components.host = getStringIp(fromAddressData: data)
            components.scheme = "https"
            components.port = resolvedNetService.port
            return components
        }()

        let openhabUrl = "\(resolvedComponents.url!)"
        os_log("OpenHABTracker discovered:%{PUBLIC}@ ", log: OSLog.remoteAccess, type: .info, openhabUrl)
        tryDiscoveryUrl(resolvedComponents.url)
    }

    func netService(_ netService: NetService, didNotResolve errorDict: [String: NSNumber]) {
        os_log("OpenHABTracker discovery didn't resolve openHAB", log: .default, type: .info)
        tryAll()
    }
}

extension NSData {
    func castToCPointer<T>() -> T {
        let mem = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        getBytes(mem, length: MemoryLayout<T.Type>.size)
        return mem.move()
    }
}
