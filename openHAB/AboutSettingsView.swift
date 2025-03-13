Section(header: Text(LocalizedStringKey("about_settings"))) {
                LabeledContent("App Version", value: appVersion)

                NavigationLink {
                    RTFTextView(rtfFileName: "legal")
                        .navigationTitle("Legal")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Text("Legal")
                }

                Button {
                    presentPrivacyPolicy()
                } label: {
                    Text("privacy_policy")
                }
            }