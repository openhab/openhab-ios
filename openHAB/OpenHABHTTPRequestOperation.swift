//
//  OpenHABHTTPRequestOperation.swift
//  openHAB
//
//  Created by David O'Neill on 03/09/19.
//  Copyright (c) 2019 David O'Neill. All rights reserved.

import AFNetworking
import os.log

class OpenHABHTTPRequestOperation: AFHTTPRequestOperation {
    static var clientCertificateManager = ClientCertificateManager()

    init(request: URLRequest, delegate: AFRememberingSecurityPolicyDelegate?) {
        super.init(request: request)
        super.setWillSendRequestForAuthenticationChallenge { [weak self] (_, challenge: URLAuthenticationChallenge) in
            guard let self = self else { return }

            let policy = self.securityPolicy as! AFRememberingSecurityPolicy
            let result = policy.handleAuthenticationChallenge(challenge: challenge)
            switch result.0 {
            case .useCredential:
                challenge.sender!.use(result.1!, for: challenge)
            case .cancelAuthenticationChallenge:
                challenge.sender!.cancel(challenge)
            case .rejectProtectionSpace:
                break
            default:
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

        let policy = AFRememberingSecurityPolicy()
        policy.delegate = delegate
        self.securityPolicy = policy
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
