//  Converted to Swift 4 by Swiftify v4.2.28153 - https://objectivec2swift.com/
//
//  OpenHABTracker.swift
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import Foundation
import SystemConfiguration

protocol OpenHABTrackerDelegate: AnyObject {
    func openHABTracked(_ openHABUrl: String?)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error) throws
}

protocol OpenHABTrackerExtendedDelegate: OpenHABTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: Reachability.Connection)
}

extension NSData {
    func castToCPointer<T>() -> T {
        let mem = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        self.getBytes(mem, length: MemoryLayout<T.Type>.size)
        return mem.move()
    }
}

class OpenHABTracker: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    var oldReachabilityStatus: Reachability.Connection?

    weak var delegate: OpenHABTrackerDelegate?
    var openHABDemoMode = false
    var openHABLocalUrl = ""
    var openHABRemoteUrl = ""
    var netService: NetService?
    var reach: Reachability?

    func start() {
        // Check if any network is available
        if isNetworkConnected2() {
            // Check if demo mode is switched on in preferences
            if openHABDemoMode {
                print("OpenHABTracker demo mode preference is on")
                trackedDemoMode()
            } else {
                // Check if network is WiFi. If not, go for remote URL
                if !isNetworkWiFi() {
                    print("OpenHABTracker network is not WiFi")
                    trackedRemoteUrl()
                    // If it is WiFi
                } else {
                    print("OpenHABTracker network is Wifi")
                    // Check if local URL is configured, if yes
                    if openHABLocalUrl.count > 0 {
                        //if Reachability(hostname: openHABLocalUrl) {
                        if isURLReachable(URL(string: openHABLocalUrl)) {
                            trackedLocalUrl()
                        } else {
                            trackedRemoteUrl()
                        }
                        // If not, go for Bonjour discovery
                    } else {
                        startDiscovery()
                    }
                }
            }
        } else {
            var errorDetail: [AnyHashable : Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = "Network is not available."
            let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String : Any])
            try? delegate?.openHABTrackingError(trackingError)
            reach = Reachability()
            oldReachabilityStatus = reach?.connection
            NotificationCenter.default.addObserver(self, selector: #selector(OpenHABTracker.reachabilityChanged(_:)), name: NSNotification.Name.reachabilityChanged, object: reach)
            try? reach?.startNotifier()
        }
    }

    // NSNetService delegate methods for publication
    func netServiceDidResolveAddress(_ resolvedNetService: NetService) {
        let openhabUrl = "https://\(getStringIp(fromAddressData: resolvedNetService.addresses![0]) ?? ""):\(resolvedNetService.port)"
        print("OpenHABTracker discovered:\(openhabUrl)")
        trackedDiscoveryUrl(openhabUrl)
    }

    func netService(_ netService: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("OpenHABTracker discovery didn't resolve openHAB")
        trackedRemoteUrl()
    }

    override init() {
        super.init()
        let prefs = UserDefaults.standard
        openHABDemoMode = prefs.bool(forKey: "demomode")
        openHABLocalUrl = prefs.value(forKey: "localUrl") as? String ?? ""
        openHABRemoteUrl = prefs.value(forKey: "remoteUrl") as? String ?? ""
    }

    func trackedLocalUrl() {
        delegate?.openHABTrackingProgress("Connecting to local URL")
        let openHABUrl = normalizeUrl(openHABLocalUrl)
        trackedUrl(openHABUrl)
    }

    func trackedRemoteUrl() {
        let openHABUrl = normalizeUrl(openHABRemoteUrl)
        if (openHABUrl?.count ?? 0) > 0 {
            delegate?.openHABTrackingProgress("Connecting to remote URL")
            trackedUrl(openHABUrl)
        } else {
            var errorDetail: [AnyHashable : Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = "Remote URL is not configured."
            let trackingError = NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String : Any])
            try? delegate?.openHABTrackingError(trackingError)
        }
    }

    func trackedDiscoveryUrl(_ discoveryUrl: String?) {
        delegate?.openHABTrackingProgress("Connecting to discovered URL")
        trackedUrl(discoveryUrl)
    }

    func trackedDemoMode() {
        delegate?.openHABTrackingProgress("Running in demo mode. Check settings to disable demo mode.")
        trackedUrl("http://demo.openhab.org:8080")
    }

    func trackedUrl(_ trackedUrl: String?) {
        delegate?.openHABTracked(trackedUrl)
    }

    @objc func reachabilityChanged(_ notification: Notification?) {
        if let changedReach = notification?.object as? Reachability {
            let nStatus = changedReach.connection
            if nStatus != oldReachabilityStatus {
                if let oldReachabilityStatus = oldReachabilityStatus { //}, let nStatus = nStatus {
                print("Network status changed from \(string(from: oldReachabilityStatus) ?? "") to \(string(from: nStatus) ?? "")")
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
        print("OpenHABTracking starting Bonjour discovery")
        delegate?.openHABTrackingProgress("Discovering openHAB")
        netService = NetService(domain: "local.", type: "_openhab-server-ssl._tcp.", name: "openHAB-ssl")
        netService!.delegate = self
        netService!.resolve(withTimeout: 5.0)
    }

    // NSNetService delegate methods for Bonjour resolving
    func normalizeUrl(_ url: String?) -> String? {
        var url = url
        if url?.hasSuffix("/") ?? false {
            url = (url as? NSString)?.substring(to: (url?.count ?? 0) - 1)
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
        return (networkReach?.connection == .wifi || networkReach?.connection == .cellular ) ? true : false
    }

    func isNetworkWiFi() -> Bool {
        let wifiReach = Reachability()
        return wifiReach?.connection == .wifi ? true : false
    }

    func getStringIp(fromAddressData dataIn: Data?) -> String? {
        var ipString: String?
        let data = dataIn! as NSData
        let socketAddress: sockaddr_in = data.castToCPointer()
        ipString = String(cString: inet_ntoa(socketAddress.sin_addr), encoding: .ascii)  ///problem here
        return ipString
    }

    func isURLReachable(_ url: URL?) -> Bool {
        var response: URLResponse?
        var data: Data?
        var request: URLRequest?
        if let url = url {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2.0)
            let session = URLSession.shared
            let task = session.dataTask(with: request,
                                        completionHandler: { data, response, error -> Void in
                                            if error == nil {
                                                result = true
                                            } else {
                                                result = false
                                            }})
            task.resume()
        }
        return result
    }

    func string(from status: Reachability.Connection) -> String? {
        switch status {
        case .none: return "unreachable"
        case .wifi: return "WiFi"
        case .cellular: return "WWAN"
        }
    }
}
