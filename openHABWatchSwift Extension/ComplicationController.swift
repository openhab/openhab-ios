// Copyright (c) 2010-2019 Contributors to the openHAB project
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

class ComplicationController: NSObject, CLKComplicationDataSource {
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

    fileprivate func getTemplate(complication: CLKComplication) -> CLKComplicationTemplate? {
        // default ist circularSmall
        var template: CLKComplicationTemplate?

        switch complication.family {
        case .modularSmall:
            template = CLKComplicationTemplateModularSmallRingImage()
            (template as! CLKComplicationTemplateModularSmallRingImage).imageProvider =
                CLKImageProvider(onePieceImage: UIImage(named: "Complication/Modular") ?? UIImage())
        case .utilitarianSmall:
            template = CLKComplicationTemplateUtilitarianSmallRingImage()
            (template as! CLKComplicationTemplateUtilitarianSmallRingImage).imageProvider =
                CLKImageProvider(onePieceImage: UIImage(named: "Complication/Utilitarian") ?? UIImage())
        case .circularSmall:
            template = CLKComplicationTemplateCircularSmallRingImage()
            (template as! CLKComplicationTemplateCircularSmallRingImage).imageProvider =
                CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular") ?? UIImage())
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                let modTemplate = CLKComplicationTemplateGraphicCornerTextImage()
                modTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular") ?? UIImage())
                modTemplate.textProvider = CLKSimpleTextProvider(text: "openHAB")
                template = modTemplate
            } else {
                abort()
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let modTemplate = CLKComplicationTemplateGraphicCircularImage()
                modTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular") ?? UIImage())
                template = modTemplate
            } else {
                abort()
            }
        default: break
        }

        return template
    }
}
