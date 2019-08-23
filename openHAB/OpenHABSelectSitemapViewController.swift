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
import UIKit

class OpenHABSelectSitemapViewController: UITableViewController {
    private var selectedSitemap: Int = 0

    var sitemaps: [OpenHABSitemap] = []
    var openHABRootUrl = ""
    var openHABUsername = ""
    var openHABPassword = ""

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

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)

            UIApplication.shared.isNetworkActivityIndicatorVisible = true

            let sitemapsOperation = NetworkConnection.shared.manager.request(sitemapsRequest)
                .validate(statusCode: 200..<300)
                .responseJSON { (response) in
                    switch response.result {
                    case .success:
                        self.sitemaps = []
                        os_log("Sitemap response", log: .default, type: .info)
                        if let data = response.data {
                            // If we are talking to openHAB 1.X, talk XML
                            if self.appData?.openHABVersion == 1 {
                                os_log("openHAB 1", log: .default, type: .info)

                                os_log("%{PUBLIC}@", log: .default, type: .info, String(data: data, encoding: .utf8) ?? "")
                                let doc: GDataXMLDocument? = try? GDataXMLDocument(data: data)
                                if doc == nil {
                                    return
                                }
                                if let name = doc?.rootElement().name() {
                                    os_log("%{PUBLIC}@", log: .default, type: .info, name)
                                }
                                if doc?.rootElement().name() == "sitemaps" {
                                    for element in doc?.rootElement().elements(forName: "sitemap") ?? [] {
                                        if let element = element as? GDataXMLElement {
                                            #if canImport(GDataXMLElement)

                                            let sitemap = OpenHABSitemap(xml: element)
                                            self.sitemaps.append(sitemap)
                                            #endif
                                        }
                                    }
                                } else {
                                    return
                                }
                            } else {
                                // Newer versions speak JSON!
                                os_log("openHAB 2", log: .default, type: .info)

                                do {
                                    os_log("Response will be decoded by JSON", log: .remoteAccess, type: .info)
                                    let sitemapsCodingData = try data.decoded() as [OpenHABSitemap.CodingData]
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
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    case .failure(let error):
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        os_log("%{PUBLIC}@", log: .default, type: .error, error.localizedDescription)
                        self.refreshControl?.endRefreshing()
                    }
            }
            sitemapsOperation.resume()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

        let imageBase = (appData?.openHABVersion == 1 ? "%@/images/%@.png" : "%@/icon/%@")

        if sitemap.icon != "" {
            if let iconUrl = URL(string: String(format: imageBase, openHABRootUrl, sitemap.icon )) {
                os_log("icon url = %{PUBLIC}@", log: .default, type: .info, String(format: imageBase, openHABRootUrl, sitemap.icon) )
                cell.imageView?.setImageWith(iconUrl, placeholderImage: UIImage(named: "blankicon.png"))
            }
        } else {
            if let iconUrl = URL(string: String(format: imageBase, openHABRootUrl, "")) {
                cell.imageView?.setImageWith(iconUrl, placeholderImage: UIImage(named: "blankicon.png"))
            }
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
