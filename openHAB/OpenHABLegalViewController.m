//
//  OpenHABLegalViewController.m
//  openHAB
//
//  Created by Victor Belov on 25/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

#import "OpenHABLegalViewController.h"

@interface OpenHABLegalViewController ()

@end

@implementation OpenHABLegalViewController

@synthesize legalTextView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSURL *legalPath = [[NSBundle mainBundle] URLForResource: @"legal" withExtension:@"rtf"];
    NSAttributedString *legalAttributedString = [[NSAttributedString alloc]   initWithFileURL:legalPath options:@{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType} documentAttributes:nil error:nil];
    legalTextView.attributedText = legalAttributedString;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
