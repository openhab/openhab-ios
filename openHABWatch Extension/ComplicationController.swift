//
//  ComplicationController.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 30.06.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import ClockKit

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
        var template: CLKComplicationTemplate? = nil
        
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
