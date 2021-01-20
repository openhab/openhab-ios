// Copyright (c) 2010-2021 Contributors to the openHAB project
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
    func openHABTracked(_ openHABUrl: URL?)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error)
}

protocol OpenHABTrackerExtendedDelegate: OpenHABTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: NetworkReachabilityManager.NetworkReachabilityStatus)
}

class OpenHABTracker: NSObject {
    var oldReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus?

    weak var delegate: OpenHABTrackerDelegate?
    var openHABDemoMode = false
    var openHABLocalUrl = ""
    var openHABRemoteUrl = ""
    var netService: NetService?
    var reach = NetworkReachabilityManager()

    override init() {
        super.init()
        openHABDemoMode = Preferences.demomode
        openHABLocalUrl = Preferences.localUrl
        openHABRemoteUrl = Preferences.remoteUrl

        #if DEBUG
        // always activate demo mode for UITest
        if ProcessInfo.processInfo.environment["UITest"] != nil {
            openHABDemoMode = true
        }
        #endif
    }

    func start() {
        // Start NetworkReachabilityManager.Listener
        oldReachabilityStatus = reach?.networkReachabilityStatus
        reach?.listener = { [weak self] status in
            guard let self = self else { return }

            let nStatus = status
            if nStatus != self.oldReachabilityStatus {
                if let oldReachabilityStatus = self.oldReachabilityStatus {
                    os_log("Network status changed from %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, self.string(from: oldReachabilityStatus) ?? "", self.string(from: nStatus) ?? "")
                }
                self.oldReachabilityStatus = nStatus
                (self.delegate as? OpenHABTrackerExtendedDelegate)?.openHABTrackingNetworkChange(nStatus)
                if self.isNetworkConnected() {
                    self.reach?.stopListening()
                    self.start()
                }
            }
        }
        if !(reach?.startListening() ?? false) {
            os_log("Starting NetworkReachabilityManager.Listener failed.", log: .remoteAccess, type: .info)
        }

        // Check if any network is available
        if isNetworkConnected() {
            // Check if demo mode is switched on in preferences
            if openHABDemoMode {
                os_log("OpenHABTracker demo mode preference is on", log: .default, type: .info)
                trackedDemoMode()
            } else {
                // Check if network is WiFi. If not, go for remote URL
                if !isNetworkWiFi(), !isNetworkVPN() {
                    os_log("OpenHABTracker network is not WiFi", log: .default, type: .info)
                    trackedRemoteUrl()
                    // If it is WiFi
                } else {
                    os_log("OpenHABTracker network is Wifi", log: .default, type: .info)
                    // Check if local URL is configured
                    if openHABLocalUrl.isEmpty {
                        startDiscovery()
                    } else {
                        let request = URLRequest(url: URL(string: openHABLocalUrl)!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2.0)
                        NetworkConnection.shared.manager.request(request)
                            .validate(statusCode: 200 ..< 300)
                            .responseData { response in
                                switch response.result {
                                case .success:
                                    self.trackedLocalUrl()
                                case .failure:
                                    self.trackedRemoteUrl()
                                }
                            }
                            .resume()
                    }
                }
            }
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString("network_not_available", comment: "")
            let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
        }
    }

    func trackedLocalUrl() {
        delegate?.openHABTrackingProgress(NSLocalizedString("connecting_local", comment: ""))
        let openHABUrl = normalizeUrl(openHABLocalUrl)
        trackedUrl(URL(string: openHABUrl!))
    }

    func trackedRemoteUrl() {
        let openHABUrl = normalizeUrl(openHABRemoteUrl)
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
        trackedUrl(URL(staticString: "http://demo.openhab.org:8080"))
    }

    func trackedUrl(_ trackedUrl: URL?) {
        delegate?.openHABTracked(trackedUrl)
    }

    func startDiscovery() {
        os_log("OpenHABTracking starting Bonjour discovery", log: .default, type: .info)

        delegate?.openHABTrackingProgress(NSLocalizedString("discovering_oh", comment: ""))
        netService = NetService(domain: "local.", type: "_openhab-server-ssl._tcp.", name: "openHAB-ssl")
        netService!.delegate = self
        netService!.resolve(withTimeout: 5.0)
    }

    func normalizeUrl(_ url: String?) -> String? {
        if let url = url, url.hasSuffix("/") {
            return String(url.dropLast())
        }
        return url
    }

    func validateUrl(_ url: String?) -> Bool {
        let theURL = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        let urlTest = NSPredicate(format: "SELF MATCHES %@", theURL)
        return urlTest.evaluate(with: url)
    }

    func isNetworkConnected() -> Bool {
        reach?.isReachable ?? false
    }

    func isNetworkWiFi() -> Bool {
        reach?.isReachableOnEthernetOrWiFi ?? false
    }

    func isNetworkVPN() -> Bool {
        if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
           let scopes = settings["__SCOPED__"] as? [String: Any] {
            for key in scopes.keys where key.contains("tap") || key.contains("tun") || key.contains("ppp") || key.contains("ipsec") || key.contains("ipsec0") {
                return true
            }
        }
        return false
    }

    func string(from status: NetworkReachabilityManager.NetworkReachabilityStatus) -> String? {
        switch status {
        case .unknown, .notReachable:
            return "unreachable"
        case let .reachable(connectionType):
            return connectionType == .ethernetOrWiFi ? "WiFi" : "WWAN"
        }
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
        trackedDiscoveryUrl(resolvedComponents.url)
    }

    func netService(_ netService: NetService, didNotResolve errorDict: [String: NSNumber]) {
        os_log("OpenHABTracker discovery didn't resolve openHAB", log: .default, type: .info)
        trackedRemoteUrl()
    }
}

extension NSData {
    func castToCPointer<T>() -> T {
        let mem = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        getBytes(mem, length: MemoryLayout<T.Type>.size)
        return mem.move()
    }
}
