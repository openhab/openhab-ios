//
//  UITableView.swift
//  openHAB
//
//  Created by Tim Müller-Seydlitz on 09.01.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import UIKit

extension UITableView {

    func dequeueReusableCell<T: UITableViewCell>(for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Unable to Dequeue Reusable Table View Cell")
        }

        return cell
    }

    func register<T: UITableViewCell>(_: T.Type) {
        register(T.self, forCellReuseIdentifier: T.reuseIdentifier)
    }

}
