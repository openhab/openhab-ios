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

    @IBOutlet weak var activityImage: WKInterfaceImage!
    @IBOutlet weak var buttonTable: WKInterfaceTable!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        activityImage.setImageNamed("Activity")
        activityImage.setHidden(true)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        self.refresh(UserDefaultsRepository.readSitemap())
        // load the current Sitemap
        OpenHabService.singleton.readSitemap({(sitemap, errorString) -> Void in

            if errorString != "" {
                // Timeouts happen when the app is in background state.
                // This shouldn't popup an error message.
                if AppState.singleton.active {
                    self.displayAlert(message: errorString)
                    return
                }
            }
            UserDefaultsRepository.saveSitemap(sitemap)
            self.refresh(sitemap)
        })
    }

    fileprivate func refresh(_ sitemap: (Sitemap)) {

        if sitemap.frames.count == 0 {
            return
        }

        self.buttonTable.setNumberOfRows(sitemap.frames[0].items.count, withRowType: "buttonRow")
        for i in 0..<self.buttonTable.numberOfRows {
            let row = self.buttonTable.rowController(at: i) as! ButtonTableRowController
            row.setInterfaceController(interfaceController: self)
            row.setItem(item: sitemap.frames[0].items[i])
        }
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func displayAlert(message: String) {
        let okAction = WKAlertAction.init(title: "Ok", style: .default) {
            print("ok action")
        }

        presentAlert(withTitle: "Fehler", message: message, preferredStyle: .actionSheet, actions: [okAction])
    }

    func displayActivityImage() {
        activityImage.setHidden(false)
        activityImage.startAnimatingWithImages(in: NSRange(1...15), duration: 1.0, repeatCount: 0)
    }

    func hideActivityImage() {
        activityImage.setHidden(true)
        activityImage.stopAnimating()
    }
}
