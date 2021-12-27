// Copyright (c) 2010-2021 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import ClockKit
import DeviceKit
import WatchKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        // watchOS7: replacing depreciated CLKComplicationSupportedFamilies
        let descriptors = [
            CLKComplicationDescriptor(identifier: "complication", displayName: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String, supportedFamilies: CLKComplicationFamily.allCases)
            // Multiple complication support can be added here with more descriptors
        ]
        handler(descriptors)
    }

    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do any necessary work to support these newly shared complication descriptors
    }

    // MARK: - Timeline Configuration

    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }

    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        let template = getTemplate(complication: complication)
        if template != nil {
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template!))
        }
    }

    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        handler(getTemplate(complication: complication))
    }

    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(getTemplate(complication: complication))
    }

    private func getTemplate(complication: CLKComplication) -> CLKComplicationTemplate? {
        // default ist circularSmall
        var template: CLKComplicationTemplate?

        switch complication.family {
        case .modularSmall:
            template = CLKComplicationTemplateModularSmallRingImage(imageProvider: CLKImageProvider(onePieceImage: UIImage(named: "OHTemplateIcon") ?? UIImage()), fillFraction: 1, ringStyle: CLKComplicationRingStyle.closed)
        case .utilitarianSmall:
            template = CLKComplicationTemplateUtilitarianSmallRingImage(imageProvider: CLKImageProvider(onePieceImage: UIImage(named: "OHTemplateIcon") ?? UIImage()), fillFraction: 1, ringStyle: CLKComplicationRingStyle.closed)
        case .circularSmall:
            template = CLKComplicationTemplateCircularSmallRingImage(imageProvider: CLKImageProvider(onePieceImage: UIImage(named: "OHTemplateIcon") ?? UIImage()), fillFraction: 1, ringStyle: CLKComplicationRingStyle.closed)
        case .extraLarge:
            template = CLKComplicationTemplateExtraLargeSimpleImage(imageProvider: CLKImageProvider(onePieceImage: UIImage(named: "OHTemplateIcon") ?? UIImage()))
        case .graphicCorner:
            template = CLKComplicationTemplateGraphicCornerTextImage(textProvider: CLKSimpleTextProvider(text: "openHAB"), imageProvider: CLKFullColorImageProvider(fullColorImage: getGraphicCornerImage()))
        case .graphicBezel:
            let modTemplate = CLKComplicationTemplateGraphicCircularImage(imageProvider: CLKFullColorImageProvider(fullColorImage: getGraphicCornerImage()))
            template = CLKComplicationTemplateGraphicBezelCircularText(circularTemplate: modTemplate, textProvider: CLKSimpleTextProvider(text: "openHAB"))
        case .graphicCircular:
            template = CLKComplicationTemplateGraphicCircularImage(imageProvider: CLKFullColorImageProvider(fullColorImage: getGraphicCircularImage()))
        default: break
        }

        return template
    }

    private func getGraphicCornerImage() -> UIImage {
        let dimension: CGFloat = Device.current.diagonal < 2.0 ? 20 : 22
        return getGraphicImage(withSize: CGSize(width: dimension, height: dimension))
    }

    private func getGraphicCircularImage() -> UIImage {
        let dimension: CGFloat = Device.current.diagonal < 2.0 ? 42 : 47
        return getGraphicImage(withSize: CGSize(width: dimension, height: dimension))
    }

    private func getGraphicImage(withSize size: CGSize) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        UIGraphicsBeginImageContextWithOptions(rect.size, false, WKInterfaceDevice.current().screenScale)

        if let image = UIImage(named: "OHIcon") {
            image.draw(in: rect.insetBy(dx: -(rect.width / 10), dy: -(rect.height / 10)))
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image ?? UIImage()
    }
}
