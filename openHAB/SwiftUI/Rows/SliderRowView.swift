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
import SFSafeSymbols
import SwiftUI

struct SliderRowView: View {
    @ObservedObject var widget: OpenHABWidget
    var fallbackSymbol: SFSymbol?

    @EnvironmentObject var viewModel: SitemapPageViewModel

    /// Pending value while user is dragging; nil when not actively changing
    @State private var pendingValue: Double?
    @State private var lastSendTime: Date = .distantPast

    private var sliderRange: ClosedRange<Double> {
        widget.minValue ... widget.maxValue
    }

    private var valueBinding: Binding<Double> {
        Binding(
            get: { pendingValue ?? widget.adjustedValue },
            set: { newValue in
                pendingValue = newValue
                if widget.shouldUseSliderUpdatesDuringMove() {
                    let now = Date()
                    if now.timeIntervalSince(lastSendTime) > 0.2 {
                        sendSliderUpdate(newValue)
                        lastSendTime = now
                    }
                }
                // Debounce: clear pending value after delay if no new updates
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    if pendingValue == newValue {
                        if !widget.shouldUseSliderUpdatesDuringMove() {
                            sendSliderUpdate(newValue)
                        }
                        pendingValue = nil
                    }
                }
            }
        )
    }

    var body: some View {
        HStack {
            if widget.switchSupport {
                Button {
                    viewModel.sendCommand(widget.item, commandToSend: (pendingValue ?? widget.adjustedValue) <= widget.minValue ? "ON" : "OFF")
                } label: {
                    labelContent
                }
                .buttonStyle(.plain)
                .disabled(widget.readOnly ?? false)
            } else {
                labelContent
            }

            Slider(value: valueBinding, in: sliderRange)
                .disabled(widget.readOnly ?? false)
        }
    }

    @ViewBuilder
    private var labelContent: some View {
        HStack {
            IconView(widget: widget, fallbackSymbol: fallbackSymbol)
                .frame(width: 32, height: 32)

            if let labelText = widget.labelText, !labelText.isEmpty {
                Text(labelText)
                    .foregroundStyle(widget.labelcolor.isEmpty ? .primary : Color(fromString: widget.labelcolor))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if let detailTextLabel = widget.labelValue, !detailTextLabel.isEmpty {
                Text(detailTextLabel)
                    .font(.callout)
                    .foregroundStyle(widget.valuecolor.isEmpty ? Color(uiColor: UIColor.ohSecondaryLabel) : Color(fromString: widget.valuecolor))
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    private func sendSliderUpdate(_ newValue: Double) {
        var numberState = widget.stateValueAsNumberState
        numberState = numberState ?? NumberState(value: newValue)
        numberState?.value = newValue
        viewModel.sendToUpdate(item: widget.item, state: numberState)
    }
}

// MARK: - Preview Helpers

#if DEBUG
private struct PreviewList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        List {
            content()
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 32)
        .environmentObject(SitemapPageViewModel())
    }
}

private extension SliderRowView {
    static func createPreviewWidget(label: String,
                                    value: Double? = nil,
                                    minValue: Double = 0.0,
                                    maxValue: Double = 100.0,
                                    step: Double = 1.0,
                                    icon: String = "slider",
                                    switchSupport: Bool = false) -> OpenHABWidget {
        let widget = OpenHABWidget()
        widget.widgetId = UUID().uuidString
        widget.type = .slider
        widget.icon = icon
        widget.minValue = minValue
        widget.maxValue = maxValue
        widget.step = step
        widget.switchSupport = switchSupport

        if let value {
            widget.label = "\(label) [\(Int(value))]"
        } else {
            widget.label = label
        }

        let item = OpenHABItem(
            name: "Preview_\(label.replacingOccurrences(of: " ", with: "_"))",
            type: "Dimmer",
            state: value.map { String($0) } ?? "NULL",
            link: "",
            label: label,
            groupType: nil,
            stateDescription: nil,
            commandDescription: nil,
            members: [],
            category: nil,
            options: nil
        )
        widget.item = item

        return widget
    }
}
#endif

// MARK: - Previews

#Preview("Default Range (0-100)") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Brightness",
                value: 75
            ),
            fallbackSymbol: .sliderHorizontal3
        )
    }
}

#Preview("Custom Range (minValue)") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Temperature",
                value: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            fallbackSymbol: .thermometerMedium
        )
    }
}

#Preview("With Switch Support") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            fallbackSymbol: .lightbulbFill
        )
    }
}

#Preview("All Scenarios") {
    PreviewList {
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Brightness",
                value: 75
            ),
            fallbackSymbol: .sliderHorizontal3
        )
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Temperature",
                value: 21,
                minValue: 16,
                maxValue: 28,
                step: 0.5
            ),
            fallbackSymbol: .thermometerMedium
        )
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Volume",
                value: 30,
                minValue: 0,
                maxValue: 100,
                icon: "soundvolume"
            ),
            fallbackSymbol: .speakerWave2Fill
        )
        SliderRowView(
            widget: SliderRowView.createPreviewWidget(
                label: "Dimmer",
                value: 50,
                switchSupport: true
            ),
            fallbackSymbol: .lightbulbFill
        )
    }
}

#Preview("From PreviewConstants") {
    PreviewList {
        SliderRowView(
            widget: PreviewConstants.openHABSitemapPage!.widgets[3],
            fallbackSymbol: .sliderHorizontal3
        )
    }
}
