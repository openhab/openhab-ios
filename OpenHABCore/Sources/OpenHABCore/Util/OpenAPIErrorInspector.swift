// Copyright (c) 2010-2026 Contributors to the openHAB project
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
import OpenAPIRuntime

public enum OpenAPIErrorInspector {
    public static func underlyingURLError(from error: any Error) -> URLError? {
        if let urlError = error as? URLError {
            return urlError
        }
        if let clientError = error as? ClientError {
            return clientError.underlyingError as? URLError
        }
        return nil
    }

    public static func clientErrorDescription(from error: any Error) -> String? {
        guard let clientError = error as? ClientError else {
            return nil
        }
        return clientError.localizedDescription
    }

    public static func underlyingErrorDescription(from error: any Error) -> String? {
        guard let clientError = error as? ClientError else {
            return nil
        }
        guard let underlyingError = clientError.underlyingError else {
            return nil
        }
        return underlyingError.localizedDescription
    }
}
