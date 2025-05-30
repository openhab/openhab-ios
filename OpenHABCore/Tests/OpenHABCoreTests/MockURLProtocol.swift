// Copyright (c) 2010-2025 Contributors to the openHAB project
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

@preconcurrency
final class MockURLProtocol: URLProtocol {
    enum ResponseType {
        case error(Error)
        case success(HTTPURLResponse)
    }

    actor MockURLProtocolState {
        var responseType: MockURLProtocol.ResponseType?

        func setResponseType(_ type: MockURLProtocol.ResponseType) {
            responseType = type
        }
    }

    private static let state = MockURLProtocolState()

    private(set) var activeTask: URLSessionTask?

    private lazy var session: URLSession = {
        let configuration: URLSessionConfiguration = .ephemeral
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override static func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        false
    }

    override func startLoading() {
        activeTask = session.dataTask(with: request)
        activeTask?.cancel()
    }

    override func stopLoading() {
        activeTask?.cancel()
    }
}

// MARK: - URLSessionDataDelegate

extension MockURLProtocol: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task {
            let responseType = await MockURLProtocol.state.responseType
            switch responseType {
            case let .error(error)?:
                client?.urlProtocol(self, didFailWithError: error)
            case let .success(response)?:
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            default:
                break
            }

            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

extension MockURLProtocol {
    enum MockError: Error {
        case none
    }

    static func responseWithFailure() {
        Task {
            await state.setResponseType(.error(MockError.none))
        }
    }

    static func responseWithStatusCode(code: Int) {
        let url = URL(string: "http://192.168.2.15")!
        let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
        Task {
            await state.setResponseType(.success(response))
        }
    }
}
