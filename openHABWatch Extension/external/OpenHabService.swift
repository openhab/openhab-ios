//
//  OpenHabService.swift
//  openhabwatch WatchKit Extension
//
//  Created by Dirk Hermanns on 31.05.18.
//  Copyright © 2018 private. All rights reserved.
//

import Foundation

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
        let requestUrl = baseUrl + "/rest/sitemaps/" + sitemapName + "?jsoncallback=callback"
        var request = URLRequest(url: URL(string: requestUrl)!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("Basic \(getBase64EncodedCredentials())", forHTTPHeaderField: "Authorization")
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            
            guard error == nil else {
                resultHandler(Sitemap.init(frames: []), "Can't read the sitemap from '\(requestUrl)'. Message is '\(String(describing: error))'")
                return
            }
            guard data != nil else {
                return
            }
            
            DispatchQueue.main.async {
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    guard let jsonDict :NSDictionary = json as? NSDictionary else {
                        resultHandler(Sitemap.init(frames: []), "Can't get json payload using baseUrl '\(requestUrl)'")
                        return
                    }
                    if let errorKey = jsonDict.object(forKey: "error") {
                        let errorMessage = (errorKey as! NSDictionary).value(forKey: "message") as! String
                        resultHandler(Sitemap.init(frames: []),
                                      "Error calling \(requestUrl): \(errorMessage)")
                        return
                    }
                    let homepageDict = jsonDict.object(forKey: "homepage") as! NSDictionary
                    if (homepageDict.count == 0) {
                        resultHandler(Sitemap.init(frames: []), "Unable to find an 'homepage' entry.")
                        return
                    }
                    let widgetsDict = homepageDict.object(forKey: "widgets") as! NSMutableArray
                    if (widgetsDict.count == 0) {
                        resultHandler(Sitemap.init(frames: []), "")
                        return
                    }
                    var frames : [Frame] = []
                    frames.append(self.readWidgets(widgets: widgetsDict))
                    let sitemap = Sitemap.init(frames: frames)
                    
                    resultHandler(sitemap, "")
                } catch let error as NSError {
                    print(error.localizedDescription)
                }
            }
        })
        task.resume()
    }
    
    private func readWidgets(widgets : NSMutableArray) -> Frame {
        
        var items: [Item] = []
        if widgets.count == 0 {
            return Frame.init(items: items);
        }
        
        for widget in widgets {
            let widgetDict = widget as! NSDictionary
            let item = widgetDict.value(forKey: "item")
            let itemDict = item as! NSDictionary
            
            var itemLabel = ""
            // use the label of the widget itself, if the sitemap has no label
            if let itemLabelFromSitemap = widgetDict.value(forKey: "label") as? String {
                itemLabel = itemLabelFromSitemap
            } else {
                // Use the label from the item itself
                itemLabel = itemDict.value(forKey: "label") as! String
            }
            
            items.append(
                Item.init(name: itemDict.value(forKey: "name") as! String,
                          label: itemLabel,
                          state: itemDict.value(forKey: "state") as! String))
        }
        return Frame.init(items: items);
    }
    
    func switchOpenHabItem(itemName : String,_ resultHandler : @escaping ((Data?, URLResponse?, Error?) -> Void)) {
        
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
