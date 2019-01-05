//
//  OpenHABSelectSitemapViewController.swift
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import SDWebImage
import UIKit

class OpenHABSelectSitemapViewController: UITableViewController {
    private var selectedSitemap: Int = 0

    var sitemaps: NSMutableArray = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""
    var ignoreSSLCertificate = false

    override init(style: UITableView.Style) {
        super.init(style: style)
        
        // Custom initialization
    
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("OpenHABSelectSitemapViewController viewDidLoad")
        if sitemaps.count != 0 {
            print("We have sitemap list here!")
        }
        if appData()?.openHABRootUrl != nil {
            if let open = appData()?.openHABRootUrl {
                print("OpenHABSelectSitemapViewController openHABRootUrl = \(open)")
            }
        }
        tableView.tableFooterView = UIView()
        //sitemaps = []
        openHABRootUrl = appData()?.openHABRootUrl ?? ""
        let prefs = UserDefaults.standard
        openHABUsername = prefs.value(forKey: "username") as? String ?? ""
        openHABPassword = prefs.value(forKey: "password") as? String ?? ""
        ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let sitemapsUrlString = "\(openHABRootUrl)/rest/sitemaps"
        let sitemapsUrl = URL(string: sitemapsUrlString)
        var sitemapsRequest: NSMutableURLRequest? = nil
        if let sitemapsUrl = sitemapsUrl {
            sitemapsRequest = NSMutableURLRequest(url: sitemapsUrl)
        }
        sitemapsRequest?.setAuthCredentials(openHABUsername, openHABPassword)
        var operation: AFHTTPRequestOperation? = nil
        if let sitemapsRequest = sitemapsRequest {
            operation = AFHTTPRequestOperation(request: sitemapsRequest as URLRequest)
        }
        let policy = AFRememberingSecurityPolicy(pinningMode: AFSSLPinningMode.none)
        operation?.securityPolicy = policy
        if ignoreSSLCertificate {
            print("Warning - ignoring invalid certificates")
            operation?.securityPolicy.allowInvalidCertificates = true
        }
        if appData()?.openHABVersion == 2 {
            print("Setting setializer to JSON")
            operation?.responseSerializer = AFJSONResponseSerializer()
        }
        operation?.setCompletionBlockWithSuccess({ operation, responseObject in
            let response = responseObject as? Data
            self.sitemaps = []
            print("Sitemap response")
            // If we are talking to openHAB 1.X, talk XML
            if self.appData()?.openHABVersion == 1 {
                print("openHAB 1")
                if let response = response {
                    print("\(String(data: response, encoding: .utf8) ?? "")")
                }
                var doc: GDataXMLDocument? = nil
                if let response = response {
                    doc = try? GDataXMLDocument(data: response)
                }
                if doc == nil {
                    return
                }
                if let name = doc?.rootElement().name() {
                    print("\(name)")
                }
                if doc?.rootElement().name() == "sitemaps" {
                    for element in doc?.rootElement().elements(forName: "sitemap") ?? [] {
                        if let element = element as? GDataXMLElement {
                            let sitemap = OpenHABSitemap(xml: element)
                            self.sitemaps.add(sitemap!)
                        }
                    }
                } else {
                    return
                }
                // Newer versions speak JSON!
            } else {
                print("openHAB 2")
// MARK - Needs to ported to Swift 4 - But not yet ready
//                guard let jsonArray = responseObject as? [[String: Any]] else {
//                    return
//                }
//                if jsonArray.count != 1 {
//                    for sitemapJson in jsonArray {
//                        let sitemap = OpenHABSitemap(dictionaty: sitemapJson)
//                        if  sitemap?.name != "_default" {
//                            print("Sitemap \(sitemap?.label ?? "not found")")
//                            self.sitemaps.append(sitemap)
//                        }
//                    }
                if (responseObject is [Any]) {
                    print("Response is array")
                    for sitemapJson: Any? in responseObject as! [Any?] {
                        let sitemap = OpenHABSitemap(dictionaty: sitemapJson as? [AnyHashable : Any])
                        if (responseObject as AnyObject).count != 1 && !(sitemap?.name == "_default") {
                            print("Sitemap \(sitemap?.label)")
                            self.sitemaps.add(sitemap!)
                        }
                    }
                } else {
                    // Something went wrong, we should have received an array
                    return
                }
            }
            self.appData()?.sitemaps = self.sitemaps
            self.tableView.reloadData()
        }, failure: { operation, error in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            print("Error:------>\(error.localizedDescription)")
            print(String(format: "error code %ld", Int(operation.response?.statusCode ?? 0)))
        })
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        operation?.start()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return sitemaps.count
    }

    static let tableViewCellIdentifier = "SelectSitemapCell"

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: OpenHABSelectSitemapViewController.tableViewCellIdentifier, for: indexPath)
        cell = UITableViewCell(style: .default, reuseIdentifier: OpenHABSelectSitemapViewController.tableViewCellIdentifier)
        let sitemap = sitemaps[indexPath.row] as? OpenHABSitemap
        if sitemap?.label != nil {
            cell.textLabel?.text = sitemap?.label
        } else {
            cell.textLabel?.text = sitemap?.name
        }

        let imageBase = appData()?.openHABVersion == 1 ? "%@/images/%@.png" : "%@/icon/%@"

        if sitemap?.icon != nil {
            var iconUrlString: String? = nil
            if let icon = sitemap?.icon {
                iconUrlString = String(format: imageBase, openHABRootUrl, icon)
            }
            print("icon url = \(iconUrlString ?? "")")
            cell.imageView?.sd_setImage(with: URL(string: iconUrlString ?? ""), placeholderImage: UIImage(named: "blankicon.png"), options: [])
        } else {
            let iconUrlString = String(format: imageBase, openHABRootUrl, "")
            cell.imageView?.sd_setImage(with: URL(string: iconUrlString), placeholderImage: UIImage(named: "blankicon.png"), options: [])
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(String(format: "Selected sitemap %ld", indexPath.row))
        let sitemap = sitemaps[indexPath.row] as? OpenHABSitemap
        let prefs = UserDefaults.standard
        prefs.setValue(sitemap?.name, forKey: "defaultSitemap")
        selectedSitemap = indexPath.row
        appData()?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? OpenHABAppDataDelegate?
        return theDelegate??.appData()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
