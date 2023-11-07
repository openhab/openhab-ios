// Copyright (c) 2010-2023 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import WatchKit

class InterfaceController: WKInterfaceController {
    @IBOutlet private var activityImage: WKInterfaceImage!
    @IBOutlet private var buttonTable: WKInterfaceTable!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        activityImage.setImageNamed("Activity")
        activityImage.setHidden(true)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        refresh(Preferences.sitemap)
        // load the current Sitemap
        OpenHabService.singleton.readSitemap { (sitemap, errorString) in

            if errorString != "" {
                // Timeouts happen when the app is in background state.
                // This shouldn't popup an error message.
                if AppState.singleton.active {
                    self.displayAlert(message: errorString)
                    return
                }
            }
            Preferences.sitemap = sitemap
            self.refresh(sitemap)
        }
    }

    fileprivate func refresh(_ sitemap: Sitemap) {
        if sitemap.frames.isEmpty {
            return
        }

        buttonTable.setNumberOfRows(sitemap.frames[0].items.count, withRowType: "buttonRow")
        for i in 0 ..< buttonTable.numberOfRows {
            let row = buttonTable.rowController(at: i) as! ButtonTableRowController
            row.setInterfaceController(interfaceController: self)
            row.setItem(item: sitemap.frames[0].items[i])
        }
    }

    func displayAlert(message: String) {
        DispatchQueue.main.async {
            let okAction = WKAlertAction(title: "Ok", style: .default) {
                print("ok action")
            }
            self.presentAlert(withTitle: "Fehler", message: message, preferredStyle: .actionSheet, actions: [okAction])
        }
    }

    func displayActivityImage() {
        activityImage.setHidden(false)
        activityImage.startAnimatingWithImages(in: NSRange(1 ... 15), duration: 1.0, repeatCount: 0)
    }

    func hideActivityImage() {
        activityImage.setHidden(true)
        activityImage.stopAnimating()
    }
}
