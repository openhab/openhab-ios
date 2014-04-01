//
//  NSURLRequest+Auth.h
//  HelloRestKit
//
//  Created by Victor Belov on 10/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (Auth)

- (void) setAuthCredentials:(NSString *)username :(NSString *)password;

@end
