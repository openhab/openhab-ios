//
//  UserDefaults.swift
//
//  Created by Dirk Hermanns on 01.06.18.
//  Copyright © 2018 private. All rights reserved.
//
import Foundation
import UIKit

/*
 * This class stores all values e.g. like the localUrl und the username in the NSUserDefaults.
 */
class UserDefaultsRepository {
    
    //FIXME: Determine the right URI which should be used
    static func readActiveUrl() -> String {
        
        if readRemoteUrl() != "" {
            return readRemoteUrl()
        }
        return readLocalUrl();
    }
    
    static func readLocalUrl() -> String {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let localUrl = defaults.string(forKey: "localUrl") else {
            return ""
        }
        
        let trimmedUri = uriWithoutTrailingSlashes(localUrl).trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines)
        
        if (!validateUrl(trimmedUri)) {
            return ""
        }
        
        return trimmedUri
    }
    
    static func saveLocalUrl(_ localUrl : String) {
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(localUrl, forKey: "localUrl")
    }
    
    static func readRemoteUrl() -> String {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let remoteUrl = defaults.string(forKey: "remoteUrl") else {
            return "https://dhe.ddns.net:444"
        }
        
        let trimmedUri = uriWithoutTrailingSlashes(remoteUrl).trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines)
        
        if (!validateUrl(trimmedUri)) {
            return ""
        }
        
        return trimmedUri
    }
    
    static func saveRemoteUrl(_ remoteUrl : String) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(remoteUrl, forKey: "remoteUrl")
    }
    
    static func readUsername() -> String {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let username = defaults.string(forKey: "username") else {
            return "test"
        }
        
        return username
    }
    
    static func saveUsername(_ username : String) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(username, forKey: "username")
    }
    
    static func readPassword() -> String {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let password = defaults.string(forKey: "password") else {
            return "test"
        }
        
        return password
    }
    
    static func savePassword(_ password : String) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(password, forKey: "password")
    }
    
    static func readSitemapName() -> String {
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return ""
        }
        
        guard let sitemapName = defaults.string(forKey: "sitemapName") else {
            return "watch"
        }
        
        return sitemapName
    }
    
    static func saveSitemapName(_ sitemapName : String) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.setValue(sitemapName, forKey: "sitemapName")
    }
    
    static func readSitemap() -> Sitemap {
        
        guard let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID) else {
            return Sitemap.init(frames: [])
        }
        
        guard let sitemap = defaults.object(forKey: "sitemap") as! Data? else {
            return Sitemap.init(frames: [])
        }
        
        return NSKeyedUnarchiver.unarchiveObject(with: sitemap) as! Sitemap
    }
    
    static func saveSitemap(_ sitemap : Sitemap) {
        
        let defaults = UserDefaults(suiteName: AppConstants.APP_GROUP_ID)
        defaults!.set(NSKeyedArchiver.archivedData(withRootObject: sitemap), forKey: "sitemap")
    }
    
    fileprivate static func validateUrl(_ stringURL : String) -> Bool {
        
        // return nil if the URL has not a valid format
        let url : URL? = URL.init(string: stringURL)
        
        return url != nil
    }
    
    static func uriWithoutTrailingSlashes(_ hostUri : String) -> String {
        if !hostUri.hasSuffix("/") {
            return hostUri
        }
        
        return String(hostUri[..<hostUri.index(before: hostUri.endIndex)])
    }
}
