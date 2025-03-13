struct ApplicationSettingsView: View {
    @Binding var settingsIgnoreSSL: Bool
     @Binding var settingsIdleOff: Bool
     @Binding var settingsSendCrashReports: Bool
     @Binding var showCrashReportingAlert: Bool
     @Binding var hasBeenLoaded: Bool
    
    private let logger = Logger(subsystem: "org.openhab.app", category: "ApplicationSettingsView")

    var body: some View {
        Section(header: Text(LocalizedStringKey("application_settings"))) {
            Toggle(isOn: $settingsIgnoreSSL) {
                Text("Ignore SSL certificates")
            }
            
            Toggle(isOn: $settingsIdleOff) {
                Text("Disable Idle Timeout")
            }
            
            Toggle(isOn: $settingsSendCrashReports) {
                Text("Crash Reporting")
            }
            
            .onAppear {
                // Setting .onAppear of view required here because onAppear of entire view is run after onChange is active
                // when migrating to iOS17 this
                settingsSendCrashReports = Preferences.sendCrashReports
                //                    loadSitemaps()
                hasBeenLoaded = true
            }
            .onChange(of: settingsSendCrashReports) { newValue in
                logger.debug("Detected change on settingsSendCrashReports")
                if newValue, hasBeenLoaded {
                    showCrashReportingAlert = true
                }
            }
            .confirmationDialog(
                "crash_reporting",
                isPresented: $showCrashReportingAlert
            ) {
                Button(role: .destructive) {
                    settingsSendCrashReports = true
                } label: {
                    Text(LocalizedStringKey("activate"))
                }
                Button(LocalizedStringKey("privacy_policy")) {
                    presentPrivacyPolicy()
                    settingsSendCrashReports = false
                }
                Button(role: .cancel) {
                    settingsSendCrashReports = false
                } label: {
                    Text(LocalizedStringKey("cancel"))
                }
            } message: {
                Text(LocalizedStringKey("crash_reporting_info"))
            }
            
            NavigationLink {
                ClientCertificatesView()
            } label: {
                Text("Client Certificates")
            }
        }
    }
    
    func presentPrivacyPolicy() {
        let vc = SFSafariViewController(url: .privacyPolicy)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(vc, animated: true)
    }
}