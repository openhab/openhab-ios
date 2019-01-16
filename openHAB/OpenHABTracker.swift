//  Converted to Swift 4 by Swiftify v4.2.20229 - https://objectivec2swift.com/
//
//  OpenHABTracker.swift
//  openHAB
//
//  Created by Victor Belov on 13/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import arpa
import Foundation
import netinet
import sys
import SystemConfiguration

@objc protocol OpenHABTrackerDelegate: NSObjectProtocol {
    func openHABTracked(_ openHABUrl: String?)

    @objc optional func openHABTrackingProgress(_ message: String?)
    @objc optional func openHABTrackingError() throws
    @objc optional func openHABTrackingNetworkChange(_ networkStatus: NetworkStatus)
}

class OpenHABTracker: NSObject, NSNetServiceDelegate, NSNetServiceBrowserDelegate {
    var oldReachabilityStatus: NetworkStatus?

    weak var delegate: OpenHABTrackerDelegate?
    var openHABDemoMode = false
    var openHABLocalUrl = ""
    var openHABRemoteUrl = ""
    var netService: NetService?
    var reach: Reachability?

    func start() {
        // Check if any network is available
        if isNetworkConnected() {
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
            if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingError)) ?? false {
                var errorDetail: [AnyHashable : Any] = [:]
                errorDetail[NSLocalizedDescriptionKey] = "Network is not available."
                let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String : Any])
                try? delegate?.openHABTrackingError()
                reach = Reachability()
                oldReachabilityStatus = reach?.currentReachabilityStatus()
                NotificationCenter.default.addObserver(self, selector: #selector(OpenHABTracker.reachabilityChanged(_:)), name: kReachabilityChangedNotification, object: nil)
                reach?.startNotifier()
            }
        }
    }

    // NSNetService delegate methods for publication
    func netServiceDidResolveAddress(_ resolvedNetService: NetService) {
        print("OpenHABTracker discovered \(getStringIp(fromAddressData: resolvedNetService.addresses[0]) ?? ""):\(getStringPort(fromAddressData: resolvedNetService.addresses[0]) ?? "")")
        let openhabUrl = "https://\(getStringIp(fromAddressData: resolvedNetService.addresses[0]) ?? ""):\(getStringPort(fromAddressData: resolvedNetService.addresses[0]) ?? "")"
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
        if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingProgress(_:))) ?? false {
            delegate?.openHABTrackingProgress("Connecting to local URL")
        }
        let openHABUrl = normalizeUrl(openHABLocalUrl)
        trackedUrl(openHABUrl)
    }

    func trackedRemoteUrl() {
        let openHABUrl = normalizeUrl(openHABRemoteUrl)
        if (openHABUrl?.count ?? 0) > 0 {
            if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingProgress(_:))) ?? false {
                delegate?.openHABTrackingProgress("Connecting to remote URL")
            }
            trackedUrl(openHABUrl)
        } else {
            if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingError)) ?? false {
                var errorDetail: [AnyHashable : Any] = [:]
                errorDetail[NSLocalizedDescriptionKey] = "Remote URL is not configured."
                let trackingError = NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String : Any])
                try? delegate?.openHABTrackingError()
            }
        }
    }

    func trackedDiscoveryUrl(_ discoveryUrl: String?) {
        if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingProgress(_:))) ?? false {
            delegate?.openHABTrackingProgress("Connecting to discovered URL")
        }
        trackedUrl(discoveryUrl)
    }

    func trackedDemoMode() {
        if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingProgress(_:))) ?? false {
            delegate?.openHABTrackingProgress("Running in demo mode. Check settings to disable demo mode.")
        }
        trackedUrl("http://demo.openhab.org:8080")
    }

    func trackedUrl(_ trackedUrl: String?) {
        if delegate != nil {
            delegate?.openHABTracked(trackedUrl)
        }
    }

    @objc func reachabilityChanged(_ notification: Notification?) {
        let changedReach = notification?.object as? Reachability
        if changedReach is Reachability {
            let nStatus: NetworkStatus? = changedReach?.currentReachabilityStatus()
            if nStatus != oldReachabilityStatus {
                if let oldReachabilityStatus = oldReachabilityStatus, let nStatus = nStatus {
                    print("Network status changed from \(string(from: oldReachabilityStatus) ?? "") to \(string(from: nStatus) ?? "")")
                }
                oldReachabilityStatus = nStatus
                if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingNetworkChange(_:))) ?? false {
                    if let nStatus = nStatus {
                        delegate?.openHABTrackingNetworkChange(nStatus)
                    }
                }
            }
        }
    }

    func startDiscovery() {
        print("OpenHABTracking starting Bonjour discovery")
        if delegate != nil && delegate?.responds(to: #selector(OpenHABTrackerDelegate.openHABTrackingProgress(_:))) ?? false {
            delegate?.openHABTrackingProgress("Discovering openHAB")
        }
        netService = NetService(domain: "local.", type: "_openhab-server-ssl._tcp.", name: "openHAB-ssl")
        netService.delegate = self
        netService.resolve(withTimeout: 5.0)
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

    func isNetworkConnected() -> Bool {

        var zeroAddress: sockaddr_in
        bzero(&zeroAddress, MemoryLayout<zeroAddress>.size)
        zeroAddress.sin_len = MemoryLayout<zeroAddress>.size
        zeroAddress.sin_family = AF_INET
        let defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress as? sockaddr)
        var flags: SCNetworkReachabilityFlags?
        let didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags)
        if !didRetrieveFlags {
            return false
        }
        let isReachable = Bool(flags.rawValue & kSCNetworkFlagsReachable)
        let needsConnection = Bool(flags.rawValue & kSCNetworkFlagsConnectionRequired)
        return (isReachable && !needsConnection) ? true : false
    }

    func isNetworkConnected2() -> Bool {
        let networkReach = Reachability()
        let networkReachabilityStatus: NetworkStatus = networkReach.currentReachabilityStatus()
        print(String(format: "Network status = %ld", Int(networkReachabilityStatus)))
        if networkReachabilityStatus == ReachableViaWiFi || networkReachabilityStatus == ReachableViaWWAN {
            return true
        }
        return false
    }

    func isNetworkWiFi() -> Bool {
        let wifiReach = Reachability()
        let wifiReachabilityStatus: NetworkStatus = wifiReach.currentReachabilityStatus()
        if wifiReachabilityStatus == ReachableViaWiFi {
            return true
        }
        return false
    }

    func getStringIp(fromAddressData dataIn: Data?) -> String? {

        var socketAddress: sockaddr_in?
        var ipString: String?

        socketAddress = dataIn?.bytes as? sockaddr_in
        ipString = "\(inet_ntoa(socketAddress?.sin_addr))" ///problem here
        return ipString
    }

    func getStringPort(fromAddressData dataIn: Data?) -> String? {

        var socketAddress: sockaddr_in?
        var ipPort: String?

        socketAddress = dataIn?.bytes as? sockaddr_in
        ipPort = String(format: "%hu", ntohs(socketAddress?.sin_port)) ///problem here
        return ipPort
    }

    func isURLReachable(_ url: URL?) -> Bool {
        var response: URLResponse?
        var error: Error?
        var data: Data?
        var request: URLRequest?
        if let url = url {
            request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2.0)
        }

        if let request = request {
            data = try? NSURLConnection.sendSynchronousRequest(request, returning: &response)
        }

        return data != nil && response != nil
    }

    func string(from status: NetworkStatus) -> String? {

        var string: String
        switch status {
        case NotReachable:
            string = "unreachable"
        case ReachableViaWiFi:
            string = "WiFi"
        case ReachableViaWWAN:
            string = "WWAN"
        default:
            string = "Unknown"
        }
        return string
    }
}
