//
//  ChartUITableViewCell.swift
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import SDWebImage

class ChartUITableViewCell: NewImageTableViewCell {
    @objc var baseUrl = ""

    override func displayWidget() {
        let random = Int.random(in: 0..<1000)

        var chartUrl: URL
        var components = URLComponents(string: baseUrl)
        components?.path = "/api"

        components?.queryItems = [
            URLQueryItem(name: "period", value: widget.period),
            URLQueryItem(name: "random", value: String(random))
        ]
        chartUrl = components?.url ?? URL(string: "")!

        if (widget.item?.type == "GroupItem") || (widget.item?.type == "Group") {
            components?.queryItems?.append(URLQueryItem(name: "groups", value: widget.item?.name))
        } else {
            components?.queryItems?.append(URLQueryItem(name: "items", value: widget.item?.name))
        }
        if widget.service != "" && !widget.service.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "service", value: widget.service))
        }
        print("Chart url \(chartUrl)")
        if widget.image == nil {
            widgetImage?.sd_setImage(with: chartUrl, placeholderImage: nil, options: .cacheMemoryOnly) { image, error, cacheType, imageURL in
                // NSLog(@"Image load complete %f %f", self.widgetImage.image.size.width, self.widgetImage.image.size.height);
                self.widget.image = image
                self.widgetImage?.frame = self.contentView.frame
                if self.delegate != nil {
                    self.delegate?.didLoadImageOf(self)
                }
            }
        } else {
            widgetImage?.image = widget.image
        }
    }
}
