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
import Network
import OpenHABCore
import os.log

protocol OpenHABWatchTrackerDelegate: AnyObject {
    func openHABTracked(_ openHABUrl: URL?)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error)
}

protocol OpenHABWatchTrackerExtendedDelegate: OpenHABWatchTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: NWPath)
}

class OpenHABWatchTracker: NSObject {
    var oldReachabilityStatus: NWPath?

    weak var delegate: OpenHABWatchTrackerDelegate?
    var netBrowser: NWBrowser?
    var pathMonitor = NWPathMonitor()
    var connectivityTask: DataRequest?

    let backgroundQueue = DispatchQueue.global(qos: .background)

    override init() {
        super.init()
    }

    func start() {
        #if !os(watchOS)
        oldReachabilityStatus = pathMonitor.currentPath
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let nStatus = path
            if nStatus != oldReachabilityStatus {
                if let oldReachabilityStatus {
                    os_log("Network status changed from %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, oldReachabilityStatus.debugDescription, nStatus.debugDescription)
                }
                oldReachabilityStatus = nStatus
                (delegate as? OpenHABWatchTrackerExtendedDelegate)?.openHABTrackingNetworkChange(nStatus)
                if isNetworkConnected() {
                    pathMonitor.cancel()
                    selectUrl()
                }
            }
        }
        pathMonitor.start(queue: backgroundQueue)
        #endif
        selectUrl()
    }

    func start(URL: URL?) {
        trackedUrl(URL)
    }

    func selectUrl() {
        #if os(watchOS)
        if ObservableOpenHABDataObject.shared.localUrl.isEmpty {
            os_log("Starting discovery", log: .default, type: .debug)
            startDiscovery()
        } else {
            if let connectivityTask {
                connectivityTask.cancel()
            }
            let request = URLRequest(url: URL(string: ObservableOpenHABDataObject.shared.localUrl)!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2.0)
            if NetworkConnection.shared == nil {
                NetworkConnection.initialize(ignoreSSL: Preferences.ignoreSSL, interceptor: nil)
            }
            connectivityTask = NetworkConnection.shared.manager.request(request)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success:
                        os_log("Tracking local URL", log: .default, type: .debug)
                        self.trackedLocalUrl()
                    case .failure:
                        os_log("Tracking remote URL", log: .default, type: .debug)
                        self.trackedRemoteUrl()
                    }
                }
            connectivityTask?.resume()
        }
        #else

        // Check if any network is available
        if isNetworkConnected() {
            // Check if network is WiFi. If not, go for remote URL
            if !isNetworkWiFi() {
                os_log("OpenHABWatchTracker network is not WiFi", log: .default, type: .info)
                trackedRemoteUrl()
                // If it is WiFi
            } else {
                os_log("OpenHABWatchTracker network is Wifi", log: .default, type: .info)
                // Check if local URL is configured
                if ObservableOpenHABDataObject.shared.localUrl.isEmpty {
                    startDiscovery()
                } else {
                    if let connectivityTask {
                        connectivityTask.cancel()
                    }
                    let request = URLRequest(url: URL(string: ObservableOpenHABDataObject.shared.localUrl)!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2.0)
                    connectivityTask = NetworkConnection.shared.manager.request(request)
                        .validate()
                        .responseData { response in
                            switch response.result {
                            case .success:
                                self.trackedLocalUrl()
                            case .failure:
                                self.trackedRemoteUrl()
                            }
                        }
                    connectivityTask?.resume()
                }
            }
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString("network_not_available", comment: "")
            let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
        }
        #endif
    }

    func trackedLocalUrl() {
        delegate?.openHABTrackingProgress(NSLocalizedString("connecting_local", comment: ""))
        let openHABUrl = normalizeUrl(ObservableOpenHABDataObject.shared.localUrl)
        trackedUrl(URL(string: openHABUrl!))
    }

    func trackedRemoteUrl() {
        let openHABUrl = normalizeUrl(ObservableOpenHABDataObject.shared.remoteUrl)
        if !(openHABUrl ?? "").isEmpty {
            // delegate?.openHABTrackingProgress("Connecting to remote URL")
            trackedUrl(URL(string: openHABUrl!))
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString("remote_url_not_configured", comment: "")
            let trackingError = NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
        }
    }

    func trackedDiscoveryUrl(_ discoveryUrl: URL?) {
        delegate?.openHABTrackingProgress(NSLocalizedString("connecting_discovered", comment: ""))
        trackedUrl(discoveryUrl)
    }

    func trackedDemoMode() {
        delegate?.openHABTrackingProgress(NSLocalizedString("running_demo_mode", comment: ""))
        trackedUrl(URL(staticString: "https://demo.openhab.org:8443"))
    }

    func trackedUrl(_ trackedUrl: URL?) {
        delegate?.openHABTracked(trackedUrl)
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
                self.trackedRemoteUrl()
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
                                self.trackedRemoteUrl()
                            } else {
                                os_log("OpenHABWatchTracker discovered: %{PUBLIC}@ ", log: OSLog.remoteAccess, type: .info, components.url?.description ?? "")
                                self.trackedDiscoveryUrl(components.url)
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
                        self.trackedRemoteUrl()
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
            self.trackedRemoteUrl()
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
                self.delegate?.openHABTracked(url)
            }
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
