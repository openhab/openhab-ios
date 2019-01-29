//
//  UITableView.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 09.01.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

extension UITableView {

    final func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath, cellType: T.Type = T.self) -> T {
            guard let cell = self.dequeueReusableCell(withIdentifier: cellType.reuseIdentifier, for: indexPath) as? T else {
                fatalError("Unable to Dequeue Reusable Table View Cell")
            }
            return cell
    }

    final func register<T: UITableViewCell>(cellType: T.Type) {
        self.register(cellType.self, forCellReuseIdentifier: cellType.reuseIdentifier)
    }

}
