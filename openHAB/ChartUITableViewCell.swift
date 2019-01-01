//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  ChartUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import SDWebImage

class ChartUITableViewCell: ImageUITableViewCell {
    @objc var baseUrl = ""

    override func displayWidget() {
        widgetImage = viewWithTag(801) as? UIImageView
        var chartUrl: String
        let random = Int(arc4random()) % 1000
        if (widget.item.type == "GroupItem") || (widget.item.type == "Group") {
            chartUrl = "\(baseUrl)/chart?groups=\(widget.item.name)&period=\(widget.period)&random=\(random)"
        } else {
            chartUrl = "\(baseUrl)/chart?items=\(widget.item.name)&period=\(widget.period)&random=\(random)"
        }
        if widget.service != nil && widget.service.count > 0 {
            chartUrl = "\(chartUrl)&service=\(widget.service)"
        }
        print("Chart url \(chartUrl)")
        if widget.image == nil {
            widgetImage.sd_setImage(with: URL(string: chartUrl), placeholderImage: nil, options: SDWebImageOptions.cacheMemoryOnly, completed: { image, error, cacheType, imageURL in
                // NSLog(@"Image load complete %f %f", self.widgetImage.image.size.width, self.widgetImage.image.size.height);
                self.widget.image = image
                self.widgetImage.frame = self.contentView.frame
                if self.delegate != nil {
                    self.delegate.didLoadImage(of: self) 
                }
            })
        } else {
            widgetImage.image = widget.image
        }
    }
}
