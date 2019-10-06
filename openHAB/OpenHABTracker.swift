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
import os.log
import SystemConfiguration

protocol OpenHABTrackerDelegate: AnyObject {
    func openHABTracked(_ openHABUrl: URL?)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error)
}

protocol OpenHABTrackerExtendedDelegate: OpenHABTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: Reachability.Connection)
}

class OpenHABTracker: NSObject {
    var oldReachabilityStatus: Reachability.Connection?

    weak var delegate: OpenHABTrackerDelegate?
    var openHABDemoMode = false
    var openHABLocalUrl = ""
    var openHABRemoteUrl = ""
    var netService: NetService?
    var reach: Reachability?

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
        // Check if any network is available
        if isNetworkConnected2() {
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
            errorDetail[NSLocalizedDescriptionKey] = "Network is not available."
            let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
            reach = Reachability()
            oldReachabilityStatus = reach?.connection
            NotificationCenter.default.addObserver(self, selector: #selector(OpenHABTracker.reachabilityChanged(_:)), name: NSNotification.Name.reachabilityChanged, object: reach)
            do {
                try reach?.startNotifier()
            } catch {
                os_log("Start notifier throws ", log: .remoteAccess, type: .info)
            }
        }
    }

    func trackedLocalUrl() {
        delegate?.openHABTrackingProgress("Connecting to local URL")
        let openHABUrl = normalizeUrl(openHABLocalUrl)
        trackedUrl(URL(string: openHABUrl!))
    }

    func trackedRemoteUrl() {
        let openHABUrl = normalizeUrl(openHABRemoteUrl)
        if (openHABUrl?.count ?? 0) > 0 {
            // delegate?.openHABTrackingProgress("Connecting to remote URL")
            trackedUrl(URL(string: openHABUrl!))
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = "Remote URL is not configured."
            let trackingError = NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
        }
    }

    func trackedDiscoveryUrl(_ discoveryUrl: URL?) {
        delegate?.openHABTrackingProgress("Connecting to discovered URL")
        trackedUrl(discoveryUrl)
    }

    func trackedDemoMode() {
        delegate?.openHABTrackingProgress("Running in demo mode. Check settings to disable demo mode.")
        trackedUrl(URL(staticString: "http://demo.openhab.org:8080"))
    }

    func trackedUrl(_ trackedUrl: URL?) {
        delegate?.openHABTracked(trackedUrl)
    }

    @objc
    func reachabilityChanged(_ notification: Notification?) {
        if let changedReach = notification?.object as? Reachability {
            let nStatus = changedReach.connection
            if nStatus != oldReachabilityStatus {
                if let oldReachabilityStatus = oldReachabilityStatus { // }, let nStatus = nStatus {
                    os_log("Network status changed from %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, string(from: oldReachabilityStatus) ?? "", string(from: nStatus) ?? "")
                }
                oldReachabilityStatus = nStatus
                if let delegate = delegate as? OpenHABTrackerExtendedDelegate {
//                    if let nStatus = nStatus {
                    delegate.openHABTrackingNetworkChange(nStatus)
//                    }
                }
            }
        }
    }

    func startDiscovery() {
        os_log("OpenHABTracking starting Bonjour discovery", log: .default, type: .info)

        delegate?.openHABTrackingProgress("Discovering openHAB")
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

    func isNetworkConnected2() -> Bool {
        let networkReach = Reachability()
        return (networkReach?.connection == .wifi || networkReach?.connection == .cellular) ? true : false
    }

    func isNetworkWiFi() -> Bool {
        let wifiReach = Reachability()
        return wifiReach?.connection == .wifi ? true : false
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

    func string(from status: Reachability.Connection) -> String? {
        switch status {
        case .none: return "unreachable"
        case .wifi: return "WiFi"
        case .cellular: return "WWAN"
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
