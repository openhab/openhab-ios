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

import CommonUI
import OpenHABCore
import SwiftUI

struct SegmentRow: View {
    let widget: OpenHABWidget
    let stateToken: String
    @EnvironmentObject var settings: AppSettings
    @State private var pressedIndex: Int?
    @State private var singlePressed = false
    @State private var triggerPressFeedback = false
    @State private var viewModel: WidgetRowViewModel
    @State private var commandSender = WidgetCommandDispatcher()

    private var currentIndex: Int? {
        viewModel.selectedIndex
    }

    var body: some View {
        Group {
            if viewModel.hasPressReleaseMappings {
                pressReleaseContent
            } else if viewModel.mappings.count == 1 {
                singleMappingContent
            } else {
                multiSegmentContent
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: triggerPressFeedback)
        .onChange(of: stateToken, initial: false) { _, _ in
            viewModel.update(from: widget)
        }
    }

    // MARK: - Press-Release

    @ViewBuilder
    private var pressReleaseContent: some View {
        if viewModel.mappings.count <= 2 {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                WatchLabelText(text: viewModel.labelText, labelColor: widget.labelcolor)
                Spacer()
                pressReleaseButtons
                    .layoutPriority(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                iconTitleRow
                HStack {
                    Spacer()
                    pressReleaseButtons
                }
            }
        }
    }

    private var pressReleaseButtons: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.mappings.indices, id: \.self) { index in
                let mapping = viewModel.mappings[index]
                inlineButton(label: mapping.label, isPressed: pressedIndex == index)
                    .overlay {
                        GeometryReader { geometry in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let bounds = CGRect(origin: .zero, size: geometry.size)
                                            guard bounds.contains(value.startLocation) else { return }
                                            if pressedIndex != index {
                                                pressedIndex = index
                                                triggerPressFeedback.toggle()
                                                commandSender.sendPress(mapping.command, for: widget)
                                            }
                                        }
                                        .onEnded { _ in
                                            guard pressedIndex == index else { return }
                                            pressedIndex = nil
                                            commandSender.sendRelease(mapping.releaseCommand, for: widget)
                                        }
                                )
                        }
                    }
            }
        }
    }

    // MARK: - Shared Components

    private var iconTitleRow: some View {
        HStack {
            WatchIconView(model: widget.iconRenderModel(), settings: settings)
            WatchLabelText(text: viewModel.labelText, labelColor: widget.labelcolor)
            Spacer()
        }
    }

    private var selectedIndexBinding: Binding<Int?> {
        Binding(
            get: { viewModel.selectedIndex },
            set: { viewModel.selectedIndex = $0 }
        )
    }

    // MARK: - Multi-Segment (existing NavigationLink)

    private var multiSegmentContent: some View {
        HStack {
            HStack {
                WatchIconView(model: widget.iconRenderModel(), settings: settings)
                WatchLabelText(text: viewModel.labelText, labelColor: widget.labelcolor)
                Spacer()
            }
            NavigationLink(destination: LazyView(SegmentSelectionView(
                widget: widget,
                stateToken: stateToken,
                selectedIndex: selectedIndexBinding
            ))) {
                HStack {
                    if let currentIndex, currentIndex >= 0, currentIndex < viewModel.mappings.count {
                        Text(viewModel.mappings[currentIndex].label)
                            .foregroundStyle(.secondary)
                            .watchTextStyle(.secondary)
                    }
                    Image(systemSymbol: .chevronRight)
                        .foregroundStyle(.secondary)
                        .watchTextStyle(.control)
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Capsule().fill(Color.gray.opacity(0.5)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Single Mapping var

    @ViewBuilder
    private var singleMappingContent: some View {
        let mapping = viewModel.mappings[0]
        HStack {
            WatchIconView(model: widget.iconRenderModel(), settings: settings)
            WatchLabelText(text: viewModel.labelText, labelColor: widget.labelcolor)
            Spacer()
            singleButton(for: mapping)
                .layoutPriority(1)
        }
    }

    init(widget: OpenHABWidget) {
        self.widget = widget
        stateToken = widget.item?.state ?? widget.state
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    init(widget: OpenHABWidget, stateToken: String) {
        self.widget = widget
        self.stateToken = stateToken
        _viewModel = State(wrappedValue: WidgetRowViewModel(widget: widget))
    }

    // MARK: - Single Mapping func

    private func singleButton(for mapping: OpenHABWidgetMapping) -> some View {
        inlineButton(label: mapping.label, isPressed: singlePressed)
            .overlay {
                GeometryReader { geometry in
                    let bounds = CGRect(origin: .zero, size: geometry.size)
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    singlePressed = bounds.contains(value.location)
                                }
                                .onEnded { value in
                                    if singlePressed, bounds.contains(value.location) {
                                        triggerPressFeedback.toggle()
                                        commandSender.send(mapping.command, for: widget, policy: .immediate)
                                    }
                                    singlePressed = false
                                }
                        )
                }
            }
    }

    // MARK: - Shared Components

    private func inlineButton(label: String, isPressed: Bool) -> some View {
        Text(label)
            .watchTextStyle(.control)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(isPressed ? 0.6 : 0.3))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
}

#Preview("Short Labels") {
    PreviewNavigationContainer {
        VStack(spacing: 8) {
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Light Switch",
                    mappings: [
                        OpenHABWidgetMapping(command: "ON", label: "ON"),
                        OpenHABWidgetMapping(command: "OFF", label: "OFF")
                    ],
                    selectedState: "ON",
                    icon: "switch"
                )
            )
        }
    }
}

#Preview("Long Labels") {
    PreviewNavigationContainer {
        VStack(spacing: 8) {
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Temperature Control",
                    mappings: [
                        OpenHABWidgetMapping(command: "manual", label: "Manual"),
                        OpenHABWidgetMapping(command: "calendar", label: "Calendar"),
                        OpenHABWidgetMapping(command: "automatic", label: "Automatic")
                    ],
                    selectedState: "automatic",
                    icon: "temperature"
                )
            )
        }
    }
}

#Preview("Multiple Segments (4)") {
    PreviewNavigationContainer {
        VStack(spacing: 8) {
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Fan Speed",
                    mappings: [
                        OpenHABWidgetMapping(command: "0", label: "Off"),
                        OpenHABWidgetMapping(command: "1", label: "Low"),
                        OpenHABWidgetMapping(command: "2", label: "Med"),
                        OpenHABWidgetMapping(command: "3", label: "High")
                    ],
                    selectedState: "3",
                    icon: "fan"
                )
            )
        }
    }
}

#Preview("PressRelease") {
    PreviewNavigationContainer {
        VStack(spacing: 8) {
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "All Shutters",
                    mappings: [
                        OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF"),
                        OpenHABWidgetMapping(command: "UP", label: "UP", releaseCommand: "OFF")
                    ],
                    selectedState: "DOWN",
                    icon: "rollershutter"
                )
            )
        }
    }
}

#Preview("Single Mapping") {
    PreviewNavigationContainer {
        VStack(spacing: 8) {
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Scene",
                    mappings: [
                        OpenHABWidgetMapping(command: "RUN", label: "Run")
                    ],
                    selectedState: "RUN",
                    icon: "scene"
                )
            )
        }
    }
}

#Preview("All Scenarios") {
    PreviewNavigationContainer {
        VStack(spacing: 8) {
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Light",
                    mappings: [
                        OpenHABWidgetMapping(command: "ON", label: "ON"),
                        OpenHABWidgetMapping(command: "OFF", label: "OFF")
                    ],
                    selectedState: "ON",
                    icon: "light"
                )
            )
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Climate Mode",
                    mappings: [
                        OpenHABWidgetMapping(command: "m", label: "Manual"),
                        OpenHABWidgetMapping(command: "a", label: "Auto"),
                        OpenHABWidgetMapping(command: "s", label: "Schedule")
                    ],
                    selectedState: "a",
                    icon: "temperature"
                )
            )
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Fan Speed",
                    mappings: [
                        OpenHABWidgetMapping(command: "0", label: "Off"),
                        OpenHABWidgetMapping(command: "1", label: "Low"),
                        OpenHABWidgetMapping(command: "2", label: "Med"),
                        OpenHABWidgetMapping(command: "3", label: "High")
                    ],
                    selectedState: "2",
                    icon: "fan"
                )
            )
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Charts Period",
                    mappings: [
                        OpenHABWidgetMapping(command: "D", label: "Day"),
                        OpenHABWidgetMapping(command: "W", label: "Week"),
                        OpenHABWidgetMapping(command: "M", label: "M"),
                        OpenHABWidgetMapping(command: "4h", label: "4h")
                    ],
                    selectedState: "D",
                    icon: "chart"
                )
            )
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "All Shutters",
                    mappings: [
                        OpenHABWidgetMapping(command: "DOWN", label: "DOWN", releaseCommand: "OFF"),
                        OpenHABWidgetMapping(command: "UP", label: "UP", releaseCommand: "OFF")
                    ],
                    selectedState: "DOWN",
                    icon: "rollershutter"
                )
            )
            SegmentRow(
                widget: PreviewWidgetFactory.segmented(
                    label: "Scene",
                    mappings: [
                        OpenHABWidgetMapping(command: "RUN", label: "RUN")
                    ],
                    selectedState: "RUN",
                    icon: "scene"
                )
            )
        }
    }
}

#Preview("Interactive State Token") {
    let widget = PreviewWidgetFactory.segmented(
        label: "Climate Mode",
        mappings: [
            OpenHABWidgetMapping(command: "manual", label: "Manual"),
            OpenHABWidgetMapping(command: "auto", label: "Auto"),
            OpenHABWidgetMapping(command: "schedule", label: "Schedule")
        ],
        selectedState: "auto",
        icon: "temperature"
    )
    PreviewNavigationContainer {
        InteractiveStateTokenPreview(
            widget: widget,
            states: ["manual", "auto", "schedule"]
        ) { targetWidget, stateToken in
            SegmentRow(widget: targetWidget, stateToken: stateToken)
        }
    }
}
