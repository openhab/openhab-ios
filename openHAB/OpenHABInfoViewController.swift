//  Converted to Swift 4 by Swiftify v4.2.28993 - https://objectivec2swift.com/
//
//  OpenHABInfoViewController.swift
//  openHAB
//
//  Created by Victor Belov on 27/05/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//

import UIKit

class OpenHABInfoViewController: UITableViewController {
    @IBOutlet var appVersionLabel: UILabel!
    @IBOutlet var openHABVersionLabel: UILabel!
    @IBOutlet var openHABUUIDLabel: UILabel!
    @IBOutlet var openHABSecretLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let versionBuildString = "\(appVersionString ?? "") (\(appBuildString ?? ""))"
        appVersionLabel.text = versionBuildString
        openHABVersionLabel.text = "-"
        openHABUUIDLabel.text = "-"
        openHABSecretLabel.text = "-"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadOpenHABInfo() {
        /*    NSURL *pageToLoadUrl = [[NSURL alloc] initWithString:self.pageUrl];
            NSMutableURLRequest *pageRequest = [NSMutableURLRequest requestWithURL:pageToLoadUrl];
            [pageRequest setAuthCredentials:self.openHABUsername :self.openHABPassword];
            currentPageOperation = [[AFHTTPRequestOperation alloc] initWithRequest:pageRequest];
            if (self.ignoreSSLCertificate) {
                NSLog(@"Warning - ignoring invalid certificates");
                currentPageOperation.securityPolicy.allowInvalidCertificates = YES;
            }
            [currentPageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSData *response = (NSData*)responseObject;
                NSError *error;
            } failure:^(AFHTTPRequestOperation *operation, NSError *error){
                NSLog(@"Error:------>%@", [error description]);
                NSLog(@"error code %ld",(long)[operation.response statusCode]);
            }];
            [currentPageOperation start];
        */
    }
}