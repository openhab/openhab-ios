//
//  SwitchRowViewModel.swift
//  openHABWatchSwift Extension
//
//  Created by Tim Müller-Seydlitz on 19.10.19.
//  Copyright © 2019 openHAB e.V. All rights reserved.
//

import Combine
import SwiftUI

final class RepositoryRowViewModel: ObservableObject {

    @Published private(set) var image = UIImage(named: "placeholder")

    func lazyLoadImage(url: URL) {
        URLSession.shared.dataTask(with: url) { (data, _, _) -> Void in
            DispatchQueue.main.async {
                if let data = data, let img = UIImage(data: data) {
                    self.image = img
                }
            }
        }
        .resume()
    }
}
