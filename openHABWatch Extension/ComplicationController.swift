// Copyright (c) 2010-2020 Contributors to the openHAB project
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
import Foundation

class ComplicationController: NSObject, CLKComplicationDataSource {
    // No Timetravel supported
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = getTemplate(complication: complication)
        if template != nil {
            handler(CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template!))
        }
    }

    // MARK: - Placeholder Templates

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
                CLKImageProvider(onePieceImage: UIImage(named: "Complication/Modular")!)
        case .utilitarianSmall:
            template = CLKComplicationTemplateUtilitarianSmallRingImage()
            (template as! CLKComplicationTemplateUtilitarianSmallRingImage).imageProvider =
                CLKImageProvider(onePieceImage: UIImage(named: "Complication/Utilitarian")!)
        case .circularSmall:
            template = CLKComplicationTemplateCircularSmallRingImage()
            (template as! CLKComplicationTemplateCircularSmallRingImage).imageProvider =
                CLKImageProvider(onePieceImage: UIImage(named: "Complication/Circular")!)
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                let modTemplate = CLKComplicationTemplateGraphicCornerTextImage()
                modTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular")!)
                modTemplate.textProvider = CLKSimpleTextProvider(text: "openHAB")
                template = modTemplate
            } else {
                abort()
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let modTemplate = CLKComplicationTemplateGraphicCircularImage()
                modTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular")!)
                template = modTemplate
            } else {
                abort()
            }
        default: break
        }

        return template
    }
}
