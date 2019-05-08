//
//  OpenHABSelectSitemapViewController.swift
//  openHAB
//
//  Created by Victor Belov on 14/01/14.
//  Copyright (c) 2014 Victor Belov. All rights reserved.
//
//  Converted to Swift 4 by Tim Müller-Seydlitz and Swiftify on 06/01/18
//

import os.log
import SDWebImage
import UIKit

class OpenHABSelectSitemapViewController: UITableViewController {
    private var selectedSitemap: Int = 0

    var sitemaps: [OpenHABSitemap] = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""

    override init(style: UITableView.Style) {
        super.init(style: style)

        // Custom initialization

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABSelectSitemapViewController viewDidLoad", log: .viewCycle, type: .info)

        if !sitemaps.isEmpty {
            os_log("We have sitemap list here!", log: .viewCycle, type: .info)
        }
        if appData?.openHABRootUrl != nil {
            if let open = appData?.openHABRootUrl {
                os_log("OpenHABSelectSitemapViewController openHABRootUrl : %{PUBLIC}@", log: .viewCycle, type: .info, open)
            }
        }
        tableView.tableFooterView = UIView()
        //sitemaps = []
        openHABRootUrl = appData?.openHABRootUrl ?? ""
        let prefs = UserDefaults.standard
        openHABUsername = prefs.string(forKey: "username") ?? ""
        openHABPassword = prefs.string(forKey: "password") ?? ""
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let sitemapsUrl = Endpoint.sitemaps(openHABRootUrl: openHABRootUrl).url {
            var sitemapsRequest = URLRequest(url: sitemapsUrl)
            sitemapsRequest.setAuthCredentials(openHABUsername, openHABPassword)

            let operation = OpenHABHTTPRequestOperation(request: sitemapsRequest as URLRequest, delegate: nil)

            operation.setCompletionBlockWithSuccess({ operation, responseObject in
                let response = responseObject as? Data
                self.sitemaps = []
                os_log("Sitemap response", log: .default, type: .info)

                // If we are talking to openHAB 1.X, talk XML
                if self.appData?.openHABVersion == 1 {
                    os_log("openHAB 1", log: .default, type: .info)

                    if let response = response {
                        os_log("%{PUBLIC}@", log: .default, type: .info, String(data: response, encoding: .utf8) ?? "")
                    }
                    var doc: GDataXMLDocument?
                    if let response = response {
                        doc = try? GDataXMLDocument(data: response)
                    }
                    if doc == nil {
                        return
                    }
                    if let name = doc?.rootElement().name() {
                        os_log("%{PUBLIC}@", log: .default, type: .info, name)
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
                        os_log("openHAB 2", log: .default, type: .info)

                        do {
                            os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                            let sitemapsCodingData = try decoder.decode([OpenHABSitemap.CodingData].self, from: response)
                            for sitemapCodingDatum in sitemapsCodingData {
                                if sitemapsCodingData.count != 1 && sitemapCodingDatum.name != "_default" {
                                    os_log("Sitemap %{PUBLIC}@", log: .default, type: .info, sitemapCodingDatum.label)

                                    self.sitemaps.append(sitemapCodingDatum.openHABSitemap)
                                }
                            }
                        } catch {
                            os_log("Should not throw %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
                        }
                    }
                }
                self.appData?.sitemaps = self.sitemaps
                self.tableView.reloadData()
            }, failure: { operation, error in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                os_log("%{PUBLIC}@ %{PUBLIC}@", log: .default, type: .error, error.localizedDescription, Int(operation.response?.statusCode ?? 0))
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

        let imageBase = appData?.openHABVersion == 1 ? "%@/images/%@.png" : "%@/icon/%@"

        if sitemap.icon != "" {
            var iconUrlString: String?
            iconUrlString = String(format: imageBase, openHABRootUrl, sitemap.icon )
            os_log("icon url = %{PUBLIC}@", log: .default, type: .info, iconUrlString ?? "")
            cell.imageView?.sd_setImage(with: URL(string: iconUrlString ?? ""), placeholderImage: UIImage(named: "blankicon.png"), options: [])
        } else {
            let iconUrlString = String(format: imageBase, openHABRootUrl, "")
            cell.imageView?.sd_setImage(with: URL(string: iconUrlString), placeholderImage: UIImage(named: "blankicon.png"), options: [])
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        os_log("Selected sitemap %d", log: .default, type: .info, indexPath.row)
        let sitemap = sitemaps[indexPath.row]
        let prefs = UserDefaults.standard
        prefs.setValue(sitemap.name, forKey: "defaultSitemap")
        selectedSitemap = indexPath.row
        appData?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    var appData: OpenHABDataObject? {
        return AppDelegate.appDelegate.appData
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
