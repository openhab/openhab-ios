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

//
//  ItemSelectionView.swift
//  openHAB
//

import OpenHABCore
import os
import SFSafeSymbols
import SwiftUI

struct ItemSelectionView: View {
    @Binding var selectedItemName: String?
    @State private var items: [OpenHABItem] = []

    @State private var searchText = ""
    @State private var isLoading = true

    private var filteredItems: [OpenHABItem] {
        if searchText.isEmpty { return items }
        return items.filter { item in
            (item.label.localizedCaseInsensitiveContains(searchText)) ||
                item.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack {
            if isLoading {
                loadingView
            } else {
                loadedView
            }
        }
        .navigationTitle("Items")
        .onAppear {
            Task {
                do {
                    items = try await NetworkTracker.shared.getStaticItems().filter { $0.type == .stringItem }
                } catch {
                    Logger.selectionView.error("Failed to load items: \(error.localizedDescription)")
                }
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        Spacer()
        ProgressView("Loading Items…")
        Spacer()
    }

    @ViewBuilder
    private var loadedView: some View {
        TextField("Search", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)

        List {
            ForEach(filteredItems, id: \.name) { item in
                itemRow(item)
            }
        }
    }

    private func itemRow(_ item: OpenHABItem) -> some View {
        Button {
            selectedItemName = (selectedItemName == item.name) ? nil : item.name
        } label: {
            HStack {
                Text(item.name)
                Spacer()
                if selectedItemName == item.name {
                    Image(systemSymbol: .checkmark)
                }
            }
        }
    }
}
