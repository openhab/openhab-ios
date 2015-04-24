//
//  OpenHABWidget.m
//  HelloRestKit
//
//  Created by Victor Belov on 08/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABWidget.h"
#import "OpenHABItem.h"
#import "OpenHABLinkedPage.h"
#import "GDataXMLNode.h"
#import "OpenHABWidgetMapping.h"

@implementation OpenHABWidget
@synthesize widgetId, label, icon, type, url, period, minValue, maxValue, step, refresh, height, isLeaf, iconColor, labelcolor, valuecolor, item, linkedPage, text, mappings, delegate, image;

- (OpenHABWidget *) initWithXML:(GDataXMLElement *)xmlElement
{
    self = [super init];
    self.mappings = [[NSMutableArray alloc] init];
    for (GDataXMLElement *child in [xmlElement children]) {
        if (![[child name] isEqual:@"widget"]) {
            if ([[child name] isEqual:@"item"]) {
                item = [[OpenHABItem alloc] initWithXML:child];
            } else if ([[child name] isEqual:@"mapping"]) {
                OpenHABWidgetMapping *mapping = [[OpenHABWidgetMapping alloc] initWithXML:child];
                [self.mappings addObject:mapping];
            } else if ([[child name] isEqual:@"linkedPage"]) {
                linkedPage = [[OpenHABLinkedPage alloc] initWithXML:child];
            } else {
                NSString *propertyValue = [child stringValue];
                if ([[self allPropertyNames] containsObject:[child name]])
                    [self setValue:propertyValue forKey:[child name]];
            }
        }
    }
    return self;
}

- (OpenHABWidget *) initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    self.mappings = [[NSMutableArray alloc] init];
    for (NSString *key in [dictionary allKeys]) {
        if ([key isEqualToString:@"item"]) {
            item = [[OpenHABItem alloc] initWithDictionary:[dictionary objectForKey:key]];
        } else if ([key isEqualToString:@"mappings"]) {
            NSArray *widgetMappings = [dictionary objectForKey:@"mappings"];
            for (NSDictionary *mappingDictionary in widgetMappings) {
                OpenHABWidgetMapping *mapping = [[OpenHABWidgetMapping alloc] initWithDictionary:mappingDictionary];
                [self.mappings addObject:mapping];
            }
        } else if ([key isEqualToString:@"linkedPage"]) {
            linkedPage = [[OpenHABLinkedPage alloc] initWithDictionary:[dictionary objectForKey:key]];
        } else {
            if ([[dictionary objectForKey:key] isKindOfClass:[NSString class]]) {
                if ([[self allPropertyNames] containsObject:key]) {
                    [self setValue:[dictionary objectForKey:key] forKey:key];
                }
            } else {
                if ([[self allPropertyNames] containsObject:key]) {
                    [self setValue:[[dictionary objectForKey:key] stringValue] forKey:key];
                }
            }
        }
    }
    return self;
}

- (NSString *) labelText
{
    NSArray *array = [self.label componentsSeparatedByString:@"["];
    NSString *valueString = [array objectAtIndex:0];
    while ([valueString hasSuffix:@" "]) {
        valueString = [valueString substringToIndex:valueString.length - 1];
    }
    return valueString;
}

- (NSString *) labelValue
{
    NSArray *array = [self.label componentsSeparatedByString:@"["];
    if (array.count > 1) {
        NSString *valueString = [array objectAtIndex:1];
        while ([valueString hasSuffix:@"]"] || [valueString hasSuffix:@" "]) {
            valueString = [valueString substringToIndex:valueString.length - 1];
        }
        return valueString;
    }
    return nil;
}

- (int) mappingIndexByCommand:(NSString *)command
{
    if (self.mappings != nil) {
        for (int i=0; i<[self.mappings count]; i++) {
            OpenHABWidgetMapping *mapping = [self.mappings objectAtIndex:i];
            if (mapping.command == command)
                return i;
        }
    }
    return -1;
}

- (void) sendCommand:(NSString *)command
{
    if (self.delegate != nil && self.item != nil)
        [self.delegate sendCommand:self.item commandToSend:command];
    if (self.item == nil)
        NSLog(@"Item = nil");
    if (self.delegate == nil)
        NSLog(@"Delegate = nil");
}

@end
