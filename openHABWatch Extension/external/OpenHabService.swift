//
//  OpenHabService.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation
import os.log

class OpenHabService {

    static let singleton = OpenHabService()

    /* Reads the sitemap that should be displayed on the watch */
    func readSitemap(_ resultHandler : @escaping ((Sitemap, String) -> Void)) {

        let baseUrl = UserDefaultsRepository.readActiveUrl()
        let sitemapName = UserDefaultsRepository.readSitemapName()
        if baseUrl == "" {
            return
        }

        // Get the current data from REST-Call

        guard let requestUrl = Endpoint.watchSitemap(openHABRootUrl: baseUrl, sitemapName: sitemapName).url else { return }
        var request = URLRequest(url: requestUrl, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("Basic \(getBase64EncodedCredentials())", forHTTPHeaderField: "Authorization")
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in

            guard error == nil else {
                resultHandler(Sitemap.init(frames: []), "Can't read the sitemap from '\(requestUrl)'. Message is '\(String(describing: error))'")
                return
            }
            guard let data = data else { return }

            DispatchQueue.main.async {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                    let codingData = try decoder.decode(OpenHABSitemap.CodingData.self, from: data)
                    if let sitemap = Sitemap.init(with: codingData) {
                        resultHandler(sitemap, "")
                    }
                } catch let error {
                    os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                }
            }
        })
        task.resume()
    }

    func switchOpenHabItem(itemName: String, _ resultHandler : @escaping ((Data?, URLResponse?, Error?) -> Void)) {

        let url = URL(string: UserDefaultsRepository.readRemoteUrl() + "/rest/items/" + itemName)!
        var request = URLRequest(url: url)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(getBase64EncodedCredentials())", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        let postString = "TOGGLE"
        request.httpBody = postString.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.sync {
                resultHandler(data, response, error)
            }
        }
        task.resume()
    }

    private func getBase64EncodedCredentials() -> String {
        let loginString = "\(UserDefaultsRepository.readUsername()):\(UserDefaultsRepository.readPassword())"
        guard let loginData = loginString.data(using: String.Encoding.utf8) else {
            return ""
        }
        return loginData.base64EncodedString()
    }
}
