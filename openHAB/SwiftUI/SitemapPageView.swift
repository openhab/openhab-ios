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

import OpenHABCore
import SwiftUI

struct SitemapPageView: View {
    @StateObject public var viewModel = SitemapPageViewModel()
    @State private var showSelectionSheet = false
    @State private var showInputAlert = false
    @State private var selectedWidget: OpenHABWidget?
    @State private var inputText = ""

    private var isLinkedPage: Bool {
        viewModel.isLinked
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading, viewModel.relevantWidgets.isEmpty {
                    // Show skeleton/placeholder rows while loading
                    ForEach(placeholderWidgets, id: \.id) { widget in
                        RowViewFactory.view(for: widget)
                            .redacted(reason: .placeholder)
                            .disabled(true)
                    }
                } else {
                    ForEach(viewModel.relevantWidgets, id: \.id) { widget in
                        Group {
                            if let linkedPage = widget.linkedPage {
                                NavigationLink(destination: SitemapPageView(viewModel: SitemapPageViewModel(pageUrl: linkedPage.link, title: linkedPage.title))) {
                                    RowViewFactory.view(for: widget)
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, -6)
                            } else if widget.type == .selection {
                                Button {
                                    selectedWidget = widget
                                    showSelectionSheet = true
                                } label: {
                                    RowViewFactory.view(for: widget)
                                }
                                .buttonStyle(.plain)
                            } else if widget.type == .input {
                                Button {
                                    selectedWidget = widget
                                    showInputAlert = true
                                } label: {
                                    RowViewFactory.view(for: widget)
                                }
                                .buttonStyle(.plain)
                            } else {
                                RowViewFactory.view(for: widget)
                                    .onTapGesture {
                                        viewModel.widgetTapped(widget)
                                    }
                            }
                        }
                    }
                }
            }
            .environmentObject(viewModel)
            .listStyle(.plain)
            .navigationBarHidden(!isLinkedPage)
            .navigationTitle(isLinkedPage ? viewModel.pageTitle : "")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.reload()
            }
            .task {
                viewModel.startPageHandling()
            }
            .onChange(of: viewModel.networkTracker.activeConnection) { activeConnection in
                viewModel.handleActiveConnectionChange(activeConnection)
            }
        }
        .sheet(isPresented: $showSelectionSheet) {
            if let widget = selectedWidget {
                SelectionView(
                    labelText: widget.labelText,
                    mappings: widget.mappingsOrItemOptions,
                    selectionItemState: widget.item?.state
                ) { selectedMappingIndex in
                    let selectedMapping = widget.mappingsOrItemOptions[selectedMappingIndex]
                    viewModel.sendCommand(widget.item, commandToSend: selectedMapping.command)
                    showSelectionSheet = false
                }
            }
        }
        .alert("Input", isPresented: $showInputAlert) {
            if let widget = selectedWidget {
                TextField("Enter value", text: $inputText)
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    // Handle input submission
                    showInputAlert = false
                    if let item = widget.item {
                        viewModel.sendCommand(item, commandToSend: inputText)
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil), actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        })
    }

    init(viewModel: SitemapPageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}

extension SitemapPageView {
    /// Creates placeholder widgets for skeleton loading state
    public var placeholderWidgets: [OpenHABWidget] {
        [
            PreviewConstants.openHABSitemapPage!.widgets[3],
            PreviewConstants.openHABSitemapPage!.widgets[5],
            PreviewConstants.openHABSitemapPage!.widgets[2],
            PreviewConstants.openHABSitemapPage!.widgets[6],
            PreviewConstants.openHABSitemapPage!.widgets[17],
            PreviewConstants.openHABSitemapPage!.widgets[4]
        ]
    }
}

#Preview {
    let previewViewModel = SitemapPageViewModel(
        pageUrl: PreviewConstants.openHABSitemapPage?.link ?? "",
        title: PreviewConstants.openHABSitemapPage?.title ?? "Preview Page",
        widgets: SitemapPageView(viewModel: SitemapPageViewModel()).placeholderWidgets
    )
    SitemapPageView(viewModel: previewViewModel)
}
