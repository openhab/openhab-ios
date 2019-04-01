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
import Alamofire
import os.log

class OpenHABSelectSitemapViewController: UITableViewController {
    private var selectedSitemap: Int = 0

    var sitemaps: [OpenHABSitemap] = []
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
        openHABUsername = prefs.string(forKey: "username") ?? ""
        openHABPassword = prefs.string(forKey: "password") ?? ""
        ignoreSSLCertificate = prefs.bool(forKey: "ignoreSSL")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.setAuthCredentials(openHABUsername, openHABPassword)

            let operation = AFHTTPRequestOperation(request: sitemapsRequest as URLRequest)

            let policy = AFRememberingSecurityPolicy(pinningMode: AFSSLPinningMode.none)
            operation.securityPolicy = policy
            if ignoreSSLCertificate {
                os_log("Warning - ignoring invalid certificates", log: OSLog.remoteAccess, type: .info)

                operation.securityPolicy.allowInvalidCertificates = true
            }
            if appData()?.openHABVersion == 2 {
                Alamofire.request(sitemapsUrl)
                    .validate(statusCode: 200..<300)
                    .responseJSON { response in
                        if response.result.error == nil {
                            debugPrint("HTTP Response Body: \(response.data.debugDescription)")
                        } else {
                            debugPrint("HTTP Request failed: \(response.result.error.debugDescription)")
                        }
                }
            }

            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                let response = responseObject as? Data
                self.sitemaps = []
                print("Sitemap response")
                // If we are talking to openHAB 1.X, talk XML
                if self.appData()?.openHABVersion == 1 {
                    print("openHAB 1")
                    if let response = response {
                        print("\(String(data: response, encoding: .utf8) ?? "")")
                    }
                    var doc: GDataXMLDocument?
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
                                self.sitemaps.append(sitemap)
                            }
                        }
                    } else {
                        return
                    }
                } else {
                    // Newer versions speak JSON!
                    let decoder = JSONDecoder()
                    if let response = response {
                        print("openHAB 2")
                        do {
                            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                            let sitemapsCodingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: response)
                            for sitemapCodingDatum in sitemapsCodingData {
                                if sitemapsCodingData.count != 1 && sitemapCodingDatum.name != "_default" {
                                    print("Sitemap \(sitemapCodingDatum.label)")
                                    self.sitemaps.append(sitemapCodingDatum.openHABSitemap)
                                }
                            }
                        } catch {
                            print("Should not throw \(error)")
                        }
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
            operation.start()
        }
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
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: OpenHABSelectSitemapViewController.tableViewCellIdentifier, for: indexPath)
        //cell = UITableViewCell(style: .default, reuseIdentifier: OpenHABSelectSitemapViewController.tableViewCellIdentifier)
        let sitemap = sitemaps[indexPath.row]
        if sitemap.label != "" {
            cell.textLabel?.text = sitemap.label
        } else {
            cell.textLabel?.text = sitemap.name
        }

        let imageBase = appData()?.openHABVersion == 1 ? "%@/images/%@.png" : "%@/icon/%@"

        if sitemap.icon != "" {
            var iconUrlString: String?
            iconUrlString = String(format: imageBase, openHABRootUrl, sitemap.icon )
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
        let sitemap = sitemaps[indexPath.row]
        let prefs = UserDefaults.standard
        prefs.setValue(sitemap.name, forKey: "defaultSitemap")
        selectedSitemap = indexPath.row
        appData()?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    func appData() -> OpenHABDataObject? {
        let theDelegate = UIApplication.shared.delegate as? AppDelegate
        return theDelegate?.appData
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
