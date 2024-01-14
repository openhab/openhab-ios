// Copyright (c) 2010-2024 Contributors to the openHAB project
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
import Network
import OpenHABCore
import os.log

protocol OpenHABWatchTrackerDelegate: AnyObject {
    func openHABTracked(_ openHABUrl: URL?, version: Int)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error)
}

protocol OpenHABWatchTrackerExtendedDelegate: OpenHABWatchTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: NWPath)
}

class OpenHABWatchTracker: NSObject {
    weak var delegate: OpenHABWatchTrackerDelegate?

    private var openHABLocalUrl = ""
    private var openHABRemoteUrl = ""
    private var restartTimer: Timer?

    var netBrowser: NWBrowser?
    var pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "NWPathMonitor")
    @Published private(set) var pathStatus: NWPath.Status = .unsatisfied

    @objc
    func restart() {
        pathMonitor.cancel()
        start()
    }

    func start() {
        openHABLocalUrl = ObservableOpenHABDataObject.shared.localUrl
        openHABRemoteUrl = ObservableOpenHABDataObject.shared.remoteUrl
        selectUrl()
        enablePathMonitor()
    }

    private func enablePathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let newStatus = path.status
            // use a timer to prevent bouncing/flapping around when switching between wifi, vpn, and wwan
            restartTimer?.invalidate()
            restartTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                if newStatus != self.pathStatus {
                    os_log(
                        "OpenHABTracker Network status changed from %{PUBLIC}@ to %{PUBLIC}@",
                        log: OSLog.remoteAccess,
                        type: .info,
                        String(reflecting: self.pathStatus),
                        path.debugDescription
                    )

                    self.pathStatus = newStatus
                    if self.isNetworkConnected() {
                        self.restart()
                    }
                }
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    func selectUrl() {
        // Check if any network is available
        if isNetworkConnected() {
            if isNetworkWiFi(), openHABLocalUrl.isEmpty {
                startDiscovery()
            } else {
                os_log("OpenHABTracker network trying all", log: .default, type: .info)
                tryAll()
            }
        } else {
            os_log("OpenHABTracker network not available", log: .default, type: .info)
            delegate?.openHABTrackingError(errorMessage("network_not_available"))
        }
    }

    func startDiscovery() {
        os_log("OpenHABTracking starting Bonjour discovery", log: .default, type: .info)

        delegate?.openHABTrackingProgress(NSLocalizedString("discovering_oh", comment: ""))
        let parameters = NWParameters()
        netBrowser = NWBrowser(for: .bonjour(type: "_openhab-server-ssl._tcp.", domain: "local."), using: parameters)
        netBrowser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                os_log("OpenHABWatchTracker discovery ready", log: .default, type: .info)
            case let .failed(error):
                os_log("OpenHABWatchTracker discovery failed: %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
//                TODO:
//                self.trackedRemoteUrl()
            default:
                break
            }
        }
        netBrowser?.browseResultsChangedHandler = { results, _ in
            guard !results.isEmpty else { return }
            guard let result = results.first else { return }

            switch result.endpoint {
            case let .service(name, type, domain, interface):
                os_log("OpenHABWatchTracker discovered service: name=%{PUBLIC}@ type=%{PUBLIC}@ domain=%{PUBLIC}@", log: OSLog.remoteAccess, type: .info, name, type, domain)
                let params = NWParameters.tcp
                let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: interface)
                let connection = NWConnection(to: endpoint, using: params)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let path = connection.currentPath!
                        switch path.remoteEndpoint {
                        case let .hostPort(host, port):
                            var components = URLComponents()
                            components.scheme = "https"
                            components.port = Int(port.rawValue)
                            switch host {
                            case let .name(name, _):
                                components.host = name
                            case let .ipv4(ipv4):
                                components.host = self.getStringIp(addressFamily: AF_INET, fromAddressData: ipv4.rawValue)
                            case let .ipv6(ipv6):
                                components.host = self.getStringIp(addressFamily: AF_INET6, fromAddressData: ipv6.rawValue)
                            default:
                                components.host = nil
                            }
                            if components.host == nil {
                                os_log("OpenHABWatchTracker unable to build URL from discovered endpoint, using remote URL instead", log: OSLog.remoteAccess, type: .info)
//                                TODO:
//                                self.trackedRemoteUrl()
                            } else {
                                os_log("OpenHABWatchTracker discovered: %{PUBLIC}@ ", log: OSLog.remoteAccess, type: .info, components.url?.description ?? "")
//                                TODO:
//                                self.trackedDiscoveryUrl(components.url)
                            }
                            return
                        default:
                            os_log("OpenHABWatchTracker unhandled endpoint type", log: OSLog.remoteAccess, type: .info)
                            connection.cancel()
                        }
                    case .preparing, .setup, .waiting:
                        break
                    default:
                        // Error establishing the connection or other unknown condition
                        connection.cancel()
                        os_log("OpenHABWatchTracker unable establish connection to discovered endpoint, using remote URL instead", log: OSLog.remoteAccess, type: .info)
//                        TODO:
//                        self.trackedRemoteUrl()
                    }
                }
                self.netBrowser!.cancel()
                connection.start(queue: .main)
                return
            default:
                os_log("OpenHABWatchTracker discovered unhandled endpoint type", log: OSLog.remoteAccess, type: .info)
            }

            self.netBrowser!.cancel()

            // Unable to discover local endpoint
            os_log("OpenHABWatchTracker unable to discover local server, using remote URL", log: OSLog.remoteAccess, type: .info)
//            TODO:
//            self.trackedRemoteUrl()
        }
        netBrowser?.start(queue: .main)
    }

    func getStringIp(addressFamily: Int32, fromAddressData dataIn: Data?) -> String? {
        let data = dataIn! as NSData
        var sockAddr: in_addr = data.castToCPointer()
        var ipAddressString: [CChar] = Array(repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(
            addressFamily,
            &sockAddr,
            &ipAddressString,
            socklen_t(INET_ADDRSTRLEN)
        )

        return String(cString: ipAddressString)
    }

    func normalizeUrl(_ url: String?) -> String? {
        if let url, url.hasSuffix("/") {
            return String(url.dropLast())
        }
        return url
    }

    func isNetworkConnected() -> Bool {
        pathMonitor.currentPath.status == .satisfied
    }

    func isNetworkWiFi() -> Bool {
        (pathMonitor.currentPath.status == .satisfied && !pathMonitor.currentPath.isExpensive)
    }

    /// Attemps to connect to the URL and get the openHAB version
    /// - Parameter tryUrl: Completes with the url and version of openHAB that succeeded, or an Error object if failed
    private func tryUrl(_ tryUrl: URL?) {
        getServerInfoForUrl(tryUrl) { url, version, error in
            if let error {
                self.delegate?.openHABTrackingError(error)
            } else {
                ObservableOpenHABDataObject.shared.openHABVersion = version
                ObservableOpenHABDataObject.shared.openHABRootUrl = url?.absoluteString ?? ""
                self.delegate?.openHABTracked(url, version: version)
            }
        }
    }

    /// Attemps to connect in parallel to the remote and local URLs if configured, the first URL to succeed wins
    private func tryAll() {
        var urls = [String: Double]()
        if !openHABLocalUrl.isEmpty {
            urls[openHABLocalUrl] = 0.0
        }
        if !openHABRemoteUrl.isEmpty {
            urls[openHABRemoteUrl] = openHABLocalUrl.isEmpty ? 0 : 1.5
        }
        if urls.isEmpty {
            delegate?.openHABTrackingProgress("error")
            return
        }
        delegate?.openHABTrackingProgress(NSLocalizedString("connecting", comment: ""))
        tryUrls(urls) { url, version, error in
            if let error {
                os_log("OpenHABTracker failed %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
                self.delegate?.openHABTrackingError(error)
            } else {
                self.delegate?.openHABTracked(url, version: version)
            }
        }
    }

    /// Tries to connect in parallel to all URL's passed in and completes when either the first requests succeedes, or all fail.
    /// - Parameters:
    ///   - urls: Tuple of String URLS and a request Delay value
    ///   - completion: Completes with the url and version of openHAB that succeeded, or an Error object if all failed
    private func tryUrls(_ urls: [String: Double], completion: @escaping (URL?, Int, Error?) -> Void) {
        var isRequestCompletedSuccessfully = false
        // request in flight
        var requests = [URL: DataRequest]()
        // timers that have yet to be executed
        var timers = [URL: Timer]()
        for (urlString, delay) in urls {
            let url = URL(string: urlString)!
            let restUrl = URL(string: "rest/", relativeTo: url)!
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                if NetworkConnection.shared == nil {
                    NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, interceptor: nil)
                }
                let request = NetworkConnection.shared.manager.request(restUrl, method: .get)
                    .validate()
                requests[url] = request
                // remove us from the outstanding timer list
                timers.removeValue(forKey: url)
                request.responseData { response in
                    // remove us from the outstanding request list
                    requests.removeValue(forKey: url)
                    os_log("OpenHABTracker response for URL %{PUBLIC}@", log: .notifications, type: .error, url.absoluteString)
                    switch response.result {
                    case let .success(data):
                        let version = self.getServerInfoFromData(data: data)
                        if version > 0, !isRequestCompletedSuccessfully {
                            isRequestCompletedSuccessfully = true
                            // cancel any timers not yet fired
                            timers.values.forEach { $0.invalidate() }
                            // cancel any requests still in flight
                            requests.values.forEach { $0.cancel() }
                            completion(url, version, nil)
                        }
                    case let .failure(error):
                        os_log("OpenHABTracker request failure %{PUBLIC}@", log: .notifications, type: .error, error.localizedDescription)
                    }
                    // check if we are the last attempt
                    if !isRequestCompletedSuccessfully, requests.isEmpty, timers.isEmpty {
                        os_log("OpenHABTracker last response", log: .notifications, type: .error)
                        completion(nil, 0, self.errorMessage("network_not_available"))
                    }
                }
                request.resume()
            }
            timers[url] = timer
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
            // OH versions 2.0 through 2.4 return "1" as their version, so set the floor to 2 so we do not think this is a OH 1.x serevr
            return max(2, Int(serverProperties.version) ?? 2)
        } catch {
            // testing for OH 1.x
            let str = String(decoding: data, as: UTF8.self)
            if str.hasPrefix("<?xml") {
                return 1
            } else {
                os_log("OpenHABTracker could not decode response", log: .notifications, type: .error)
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
            os_log("OpenHABTracker getServerInfo, received data for URL: %{PUBLIC}@", log: .default, type: .info, strUrl)
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

    func errorMessage(_ message: String) -> NSError {
        var errorDetail: [AnyHashable: Any] = [:]
        errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString(message, comment: "")
        return NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String: Any])
    }
}

extension NWPath: CustomStringConvertible {
    public var description: String {
        switch status {
        case .unsatisfied, .requiresConnection:
            return "unreachable"
        case .satisfied:
            var str = "reachable:"
            for interface in availableInterfaces {
                switch interface.type {
                case .wifi:
                    str += " wifi"
                case .cellular:
                    str += " cellular"
                case .wiredEthernet:
                    str += " wiredEthernet"
                case .loopback:
                    str += " loopback"
                case .other:
                    str += " other"
                default:
                    str += " (unknown)"
                }
            }
            return str
        default:
            return "(unknown)"
        }
    }
}

extension NSData {
    func castToCPointer<T>() -> T {
        let mem = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        getBytes(mem, length: MemoryLayout<T.Type>.size)
        return mem.move()
    }
}
