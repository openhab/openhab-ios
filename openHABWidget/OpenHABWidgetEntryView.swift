// Copyright (c) 2010-2024 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import SwiftUI
import WidgetKit

struct OpenHABWidgetEntryView: View {
    //    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family

    //    @ViewBuilder
    var body: some View {
        switch family {
        case .systemLarge:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
        //            Text(entry.configuration.favoriteEmoji)
        case .systemSmall:
            VStack {
                Text("Time:")
                //                Text(entry.date, style: .time)

                Text("Favorite Emoji:")
                //                Text(entry.configuration.favoriteEmoji)

                if #available(iOS 17.0, *) {
                    HStack(alignment: .top) {
                        Button(intent: SetSwitchState()) {
                            Image(systemName: "bolt.fill")
                        }
                    }
                    .tint(.white)
                    .padding()
                }
            }
        //            .containerBackground(for: .widget) {
        //                Color.gameBackgroundColor
        //            }
        //            .widgetURL(entry.hero.url)
        case .systemMedium:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
        //            Text(entry.configuration.favoriteEmoji)
        case .systemExtraLarge:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
        //            Text(entry.configuration.favoriteEmoji)
        case .accessoryCircular:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
        //            Text(entry.configuration.favoriteEmoji)
        case .accessoryRectangular:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
        //            Text(entry.configuration.favoriteEmoji)
        case .accessoryInline:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
        //            Text(entry.configuration.favoriteEmoji)
        @unknown default:
            Text("Time:")
            //            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
            //            Text(entry.configuration.favoriteEmoji)
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct OpenHABWidgetView: Widget {
    let kind: String = "OpenHABWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { _ in
            OpenHABWidgetEntryView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall])
    }
}

private extension ConfigurationAppIntent {
    static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }

    static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    OpenHABWidgetView()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley)
    SimpleEntry(date: .now, configuration: .starEyes)
}
