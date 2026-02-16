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
import OpenHABCore
import SwiftUI

/// Service for managing certificate-related alerts and user interactions in SwiftUI
@MainActor
@Observable
class CertificateManagementService {
    static let shared = CertificateManagementService()
    
    // MARK: - Alert Types
    
    struct ServerCertificateAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let completion: (ServerCertificateManager.EvaluateResult) -> Void
    }
    
    struct ClientCertificateImportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let completion: (Bool) -> Void
    }
    
    struct ClientCertificatePasswordAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var password: String = ""
        let completion: (String?) -> Void
    }
    
    struct ClientCertificateErrorAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    
    // MARK: - Published Alert States
    
    var serverCertificateAlert: ServerCertificateAlert?
    var clientCertificateImportAlert: ClientCertificateImportAlert?
    var clientCertificatePasswordAlert: ClientCertificatePasswordAlert?
    var clientCertificateErrorAlert: ClientCertificateErrorAlert?
    
    private init() {
        setupCertificateManagers()
    }
    
    private func setupCertificateManagers() {
        CertificateManagers.clientCertificateManager.delegate = self
        CertificateManagers.serverCertificateManager.delegate = self
    }
}

// MARK: - ServerCertificateManagerDelegate

extension CertificateManagementService: ServerCertificateManagerDelegate {
    func evaluateServerTrust(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_invalid", comment: ""), 
                               certificateSummary ?? "", domain ?? "")
            
            serverCertificateAlert = ServerCertificateAlert(
                title: title,
                message: message
            ) { result in
                continuation.resume(returning: result)
                self.serverCertificateAlert = nil
            }
        }
    }
    
    func evaluateCertificateMismatch(summary certificateSummary: String?, forDomain domain: String?) async -> ServerCertificateManager.EvaluateResult {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("ssl_certificate_warning", comment: "")
            let message = String(format: NSLocalizedString("ssl_certificate_no_match", comment: ""), 
                               certificateSummary ?? "", domain ?? "")
            
            serverCertificateAlert = ServerCertificateAlert(
                title: title,
                message: message
            ) { result in
                continuation.resume(returning: result)
                self.serverCertificateAlert = nil
            }
        }
    }
    
    func acceptedServerCertificatesChanged() {
        // User's decision about trusting server certificates has changed
        // Send updates to the paired watch
        Task {
            await WatchMessageService.singleton.syncPreferencesToWatch()
        }
    }
}

// MARK: - ClientCertificateManagerDelegate

extension CertificateManagementService: ClientCertificateManagerDelegate {
    func askForClientCertificateImport(_ clientCertificateManager: ClientCertificateManager?) async -> Bool {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("certificate_import_title", comment: "")
            let message = NSLocalizedString("certificate_import_text", comment: "")
            
            clientCertificateImportAlert = ClientCertificateImportAlert(
                title: title,
                message: message
            ) { shouldImport in
                if shouldImport {
                    Task {
                        await clientCertificateManager?.clientCertificateAccepted(password: nil)
                    }
                } else {
                    clientCertificateManager?.clientCertificateRejected()
                }
                continuation.resume(returning: shouldImport)
                self.clientCertificateImportAlert = nil
            }
        }
    }
    
    func askForCertificatePassword(_ clientCertificateManager: ClientCertificateManager?) async -> String? {
        await withCheckedContinuation { continuation in
            let title = NSLocalizedString("certificate_import_title", comment: "")
            let message = NSLocalizedString("certificate_import_password", comment: "")
            
            clientCertificatePasswordAlert = ClientCertificatePasswordAlert(
                title: title,
                message: message
            ) { password in
                continuation.resume(returning: password)
                self.clientCertificatePasswordAlert = nil
            }
        }
    }
    
    func alertClientCertificateError(_ clientCertificateManager: ClientCertificateManager?, errMsg: String) async {
        let title = NSLocalizedString("certificate_import_title", comment: "")
        clientCertificateErrorAlert = ClientCertificateErrorAlert(
            title: title,
            message: errMsg
        )
    }
}

// MARK: - SwiftUI Alert View Modifiers

extension View {
    /// Adds certificate management alerts to a view
    func certificateManagementAlerts() -> some View {
        modifier(CertificateManagementAlertsModifier())
    }
}

struct CertificateManagementAlertsModifier: ViewModifier {
    @State private var certificateService = CertificateManagementService.shared
    
    func body(content: Content) -> some View {
        content
            // Server Certificate Alert
            .alert(item: $certificateService.serverCertificateAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(NSLocalizedString("always", comment: ""))) {
                        alert.completion(.permitAlways)
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("abort", comment: ""))) {
                        alert.completion(.deny)
                    }
                )
            }
            // Client Certificate Import Alert
            .alert(item: $certificateService.clientCertificateImportAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(NSLocalizedString("okay", comment: ""))) {
                        alert.completion(true)
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: ""))) {
                        alert.completion(false)
                    }
                )
            }
            // Client Certificate Password Alert
            .alert(
                certificateService.clientCertificatePasswordAlert?.title ?? "",
                isPresented: Binding(
                    get: { certificateService.clientCertificatePasswordAlert != nil },
                    set: { if !$0 { 
                        certificateService.clientCertificatePasswordAlert?.completion(nil)
                        certificateService.clientCertificatePasswordAlert = nil
                    }}
                )
            ) {
                if let alert = certificateService.clientCertificatePasswordAlert {
                    SecureField(NSLocalizedString("password", comment: ""), text: Binding(
                        get: { alert.password },
                        set: { certificateService.clientCertificatePasswordAlert?.password = $0 }
                    ))
                    
                    Button(NSLocalizedString("okay", comment: "")) {
                        alert.completion(alert.password.isEmpty ? nil : alert.password)
                    }
                    
                    Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                        alert.completion(nil)
                    }
                }
            } message: {
                if let alert = certificateService.clientCertificatePasswordAlert {
                    Text(alert.message)
                }
            }
            // Client Certificate Error Alert
            .alert(item: $certificateService.clientCertificateErrorAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(NSLocalizedString("okay", comment: "")))
                )
            }
    }
}
