//
//  UserDefaultsExtension.swift
//  openHABWatch Extension
//
//  Created by Tim Müller-Seydlitz on 12.06.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Foundation

extension UserDefaults {
    static var shared: UserDefaults {
        return UserDefaults(suiteName: AppConstants.APP_GROUP_ID)!
    }
}
