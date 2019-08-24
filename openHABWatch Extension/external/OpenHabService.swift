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

        let baseUrl = Preferences.readActiveUrl()
        let sitemapName = Preferences.sitemapName
        if baseUrl == "" {
            return
        }

        // Get the current data from REST-Call

        guard let requestUrl = Endpoint.watchSitemap(openHABRootUrl: baseUrl, sitemapName: sitemapName).url else { return }
        var request = URLRequest(url: requestUrl, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setAuthCredentials(Preferences.username, Preferences.password)
        //let session = URLSession.shared
        let session = URLSession(
            configuration: URLSessionConfiguration.ephemeral,
            delegate: CertificatePinningURLSessionDelegate(),
            delegateQueue: nil)
        let task = session.dataTask(with: request) { (data, _, error) -> Void in

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
        }
        task.resume()
    }

    func switchOpenHabItem(for item: Item, command: String, _ resultHandler : @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        guard let commandUrl = URL(string: item.link) else { return }
        var request = URLRequest(url: commandUrl)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setAuthCredentials(Preferences.username, Preferences.password)
        request.httpMethod = "POST"
        let postString = command
        request.httpBody = postString.data(using: .utf8)
        let session = URLSession(
            configuration: URLSessionConfiguration.ephemeral,
            delegate: CertificatePinningURLSessionDelegate(),
            delegateQueue: nil)
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.sync {
                resultHandler(data, response, error)
            }
        }
        task.resume()
    }
}
