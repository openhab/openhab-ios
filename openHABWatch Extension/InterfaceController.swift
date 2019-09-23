//
//  InterfaceController.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 01.05.18.
//  Copyright © 2018 private. All rights reserved.
//

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
        OpenHabService.singleton.readSitemap { (sitemap, errorString) -> Void in

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

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
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
