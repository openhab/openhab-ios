//
//  NSData+NSData_HexString.m
//  openHAB
//
//  Created by Victor Belov on 05/04/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "NSData+HexString.h"

@implementation NSData (HexString)

- (NSString *)hexString {
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer)
        return [NSString string];
    
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return [NSString stringWithString:hexString];
}

@end
