//
//  OpenHABHTTPRequestOperation.swift
//  openHAB
//
//  Created by David O'Neill on 03/09/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

//import Alamofire
import AFNetworking
import os.log

// https://medium.com/@AladinWay/write-a-networking-layer-in-swift-4-using-alamofire-5-and-codable-part-2-perform-request-and-b5c7ee2e012d
// Transition from AFNetworking to Alamofire
// SessionManager --> Session
// serverTrustPolicyManager --> serverTrustManager
// ServerTrustPolicyManager --> ServerTrustManager

// SessionStateProvider

//class OpenHABHTTPRequestOperationBasedOnAlamofire {
//
//    static var clientCertificateManager: ClientCertificateManager = ClientCertificateManager()
//
//    // Pass type
//    init(request: URLRequest) {
//
//        let prefs = UserDefaults.standard
//        let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")
//
//        let manager: Session
//
//        if ignoreSSLCertificate {
//            os_log("Warning - ignoring invalid certificates", log: OSLog.remoteAccess, type: .info)
//            let evaluators = [
//                expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates,
//                                             acceptSelfSignedCertificates: true,
//                                             performDefaultValidation: false,
//                                             validateHost: false)
//            ]
//            manager = Session(
//                configuration: configuration,
//                serverTrustManager: ServerTrustManager(evaluators: evaluators)
//            )
//        } else {
//            let evaluators = [
//                expiredHost: PinnedCertificatesTrustEvaluator(certificates: certificates,
//                                             acceptSelfSignedCertificates: false,
//                                             performDefaultValidation: true,
//                                             validateHost: true)
//                ]
//            manager = Session(
//                configuration: configuration,
//                serverTrustManager: ServerTrustManager(evaluators: evaluators)
//            )
//        }
//
//        let jsonDecoder = JSONDecoder()
//        jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
//
//        manager.request(request)
//            .validate(statusCode: 200..<300)
//            .responseDecodable(decoder: jsonDecoder) { (response: DataResponse<[OpenHABSitemap.CodingData]>) in
//                switch response.result {
//                case .failure(let error):
//                    os_log("HTTP Response Body: %{PUBLIC}@", log: .default, type: .info, response.data.debugDescription)
//                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
//                    os_log("%{PUBLIC}@ %{PUBLIC}@", log: .default, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
//                case .success(let sitemapsCodingData):
//                    break
//                }
//        }
//    }
//    let expiredHost = "expired.badssl.com"
//
//    let certificates = [TestCertificates.leaf]
//
//
//    var configuration: URLSessionConfiguration!
//
//    func setUp() {
//        configuration = URLSessionConfiguration.ephemeral
//        configuration.urlCache = nil
//        configuration.urlCredentialStorage = nil
//    }
//
//}

    //            let serverTrustPolicies: [String: ServerTrustPolicy] = [
    //                "test.example.com": .pinCertificates(
    //                    certificates: ServerTrustPolicy.certificates(),
    //                    validateCertificateChain: true,
    //                    validateHost: true
    //                ),
    //                "insecure.expired-apis.com": .disableEvaluation
    //            ]
    //
    //            let sessionManager = SessionManager(
    //                serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies)
    //            )

    class OpenHABHTTPRequestOperation: AFHTTPRequestOperation {
        static var clientCertificateManager: ClientCertificateManager = ClientCertificateManager()

        init(request: URLRequest, delegate: AFRememberingSecurityPolicyDelegate?) {
            super.init(request: request)
            super.setWillSendRequestForAuthenticationChallenge { (connection: NSURLConnection, challenge: URLAuthenticationChallenge) in

                if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                    if self.securityPolicy.evaluateServerTrust(challenge.protectionSpace.serverTrust!, forDomain: challenge.protectionSpace.host) {
                        let credential = URLCredential.init(trust: challenge.protectionSpace.serverTrust!)
                        challenge.sender!.use(credential, for: challenge)
                    } else {
                        challenge.sender!.cancel(challenge)
                    }
                } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
                    self.evaluateClientTrust(challenge: challenge)
                } else {
                    if challenge.previousFailureCount == 0 {
                        if self.credential != nil {
                            challenge.sender!.use(self.credential!, for: challenge)
                        } else {
                            challenge.sender!.continueWithoutCredential(for: challenge)
                        }
                    } else {
                        challenge.sender!.continueWithoutCredential(for: challenge)
                    }
                }
            }

            let policy = AFRememberingSecurityPolicy(pinningMode: AFSSLPinningMode.none)
            policy.delegate = delegate

            let prefs = UserDefaults.standard
            let ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")

            if ignoreSSLCertificate {
                os_log("Warning - ignoring invalid certificates", log: OSLog.remoteAccess, type: .info)
                policy.allowInvalidCertificates = true
                policy.validatesDomainName = false
            }
            self.securityPolicy = policy
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func evaluateClientTrust(challenge: URLAuthenticationChallenge) {
            let dns = challenge.protectionSpace.distinguishedNames
            if dns != nil {
                let identity = OpenHABHTTPRequestOperation.clientCertificateManager.evaluateTrust(distinguishedNames: dns!)
                if identity != nil {
                    let credential = URLCredential.init(identity: identity!, certificates: nil, persistence: URLCredential.Persistence.forSession)
                    challenge.sender!.use(credential, for: challenge)
                    return
                }
            }
            // No client certificate available
            challenge.sender!.cancel(challenge)
        }
}
