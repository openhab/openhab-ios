//
//  ChartUITableViewCell.h
//  openHAB
//
//  Created by Victor Belov on 16/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "GenericUITableViewCell.h"

@interface ChartUITableViewCell : GenericUITableViewCell

@property (nonatomic, retain) UIImageView *chartImage;
@property (nonatomic, retain) NSString *baseUrl;

@end
