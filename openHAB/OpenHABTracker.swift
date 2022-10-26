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

    @objc func restart() {
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
            self.restartTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                if nStatus != self.oldReachabilityStatus {
                    if let oldReachabilityStatus = self.oldReachabilityStatus {
                        os_log("OpenHABTracker Network status changed from %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, self.string(from: oldReachabilityStatus) ?? "", self.string(from: nStatus) ?? "")
                    }
                    self.oldReachabilityStatus = nStatus
                    // (self.delegate as? OpenHABTrackerExtendedDelegate)?.openHABTrackingNetworkChange(nStatus)
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
                // Check if network is WiFi. If not, go for remote URL
                if !isNetworkWiFi(), !isNetworkVPN() {
                    os_log("OpenHABTracker network is not WiFi", log: .default, type: .info)
                    tryRemoteUrl()
                    // If it is WiFi
                } else {
                    os_log("OpenHABTracker network is Wifi", log: .default, type: .info)
                    // Check if local URL is configured
                    if openHABLocalUrl.isEmpty {
                        startDiscovery()
                    } else {
                        tryLocalThenRemoteUrl()
                    }
                }
            }
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString("network_not_available", comment: "")
            let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String: Any])
            multicastDelegate.invoke { $0.openHABTrackingError(trackingError) }
        }
    }

    private func tryLocalThenRemoteUrl() {
        multicastDelegate.invoke { $0.openHABTrackingProgress(NSLocalizedString("connecting_local", comment: "")) }
        let openHABUrl = normalizeUrl(openHABLocalUrl)
        getServerInfo(URL(string: openHABUrl!)) { url, version, error in
            if let error {
                os_log("OpenHABTracker failed connecting to local, trying remote: %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
                self.tryRemoteUrl()
            } else {
                self.appData?.openHABVersion = version
                self.appData?.openHABRootUrl = url?.absoluteString ?? ""
                self.multicastDelegate.invoke { $0.openHABTracked(url, version: version) }
            }
        }
    }

    private func tryRemoteUrl() {
        let openHABUrl = normalizeUrl(openHABRemoteUrl)
        if !(openHABUrl ?? "").isEmpty {
            multicastDelegate.invoke { $0.openHABTrackingProgress(NSLocalizedString("connecting_remote", comment: "")) }
            tryUrl(URL(string: openHABUrl!))
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString("remote_url_not_configured", comment: "")
            let trackingError = NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String: Any])
            multicastDelegate.invoke { $0.openHABTrackingError(trackingError) }
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

    private func tryUrl(_ tryUrl: URL?) {
        getServerInfo(tryUrl) { url, version, error in
            if let error {
                self.multicastDelegate.invoke { $0.openHABTrackingError(error) }
            } else {
                self.appData?.openHABVersion = version
                self.appData?.openHABRootUrl = url?.absoluteString ?? ""
                self.multicastDelegate.invoke { $0.openHABTracked(url, version: version) }
            }
        }
    }

    private func getServerInfo(_ url: URL?, completion: @escaping (URL?, Int, Error?) -> Void) {
        let strUrl = url?.absoluteString ?? ""
        os_log("OpenHABTracker getServerInfo, trying: %{PUBLIC}@", log: .default, type: .info, strUrl)
        NetworkConnection.tracker(openHABRootUrl: strUrl) { response in
            os_log("OpenHABTracker getServerInfo, recieved data for URL: %{PUBLIC}@", log: .default, type: .info, strUrl)
            switch response.result {
            case let .success(data):
                do {
                    let serverProperties = try data.decoded(as: OpenHABServerProperties.self)
                    os_log("OpenHABTracker openHAB version %@", log: .remoteAccess, type: .info, serverProperties.version)
                    let version = Int(serverProperties.version) ?? 2
                    completion(url, version, nil)
                } catch {
                    // testing for OH 1.x
                    let str = String(decoding: data, as: UTF8.self)
                    if str.hasPrefix("<?xml") {
                        completion(url, 1, nil)
                    } else {
                        os_log("OpenHABTracker Could not decode response as JSON, %{PUBLIC}@ %d", log: .notifications, type: .error, error.localizedDescription, response.response?.statusCode ?? 0)
                        completion(url, 0, error)
                    }
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
        tryDiscoveryUrl(resolvedComponents.url)
    }

    func netService(_ netService: NetService, didNotResolve errorDict: [String: NSNumber]) {
        os_log("OpenHABTracker discovery didn't resolve openHAB", log: .default, type: .info)
        tryRemoteUrl()
    }
}

extension NSData {
    func castToCPointer<T>() -> T {
        let mem = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        getBytes(mem, length: MemoryLayout<T.Type>.size)
        return mem.move()
    }
}
