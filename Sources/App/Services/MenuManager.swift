//
//  MenuManager.swift
//  App
//
//  Created by Filip Kirschner on 16/03/2018.
//

import Foundation
import Vapor

class MenuManager {
    
    static let shared = MenuManager()
    
    private var menu: Menu?
    
    func getMenu() -> Future<Menu> {
        let promise = Promise<Menu>()
        if let menu = self.menu, NSCalendar.current.isDate(menu.date, inSameDayAs: Date()) {
            print("cached results returned")
            promise.complete(menu)
        } else {
            print("cache invalid, requesting new results...")
            PrestoScraper.shared.scrapeLatestMenu(callback: { (menu, error) in
                if let menu = menu {
                    print("Menu retrieved, completing promise")
                    self.menu = menu
                    promise.complete(menu)
                } else {
                    promise.fail(error ?? NSError(domain: prestoErrorDomain, code: PrestoError.epicFail.rawValue, userInfo: nil))
                }
            })
        }
        return promise.future
    }
    
}
