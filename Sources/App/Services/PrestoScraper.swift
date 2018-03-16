//
//  PrestoScraper.swift
//  PrestoAPIPackageDescription
//
//  Created by Filip Kirschner on 15/03/2018.
//

import Foundation

class PrestoScraper {
    
    static let shared = PrestoScraper()
    
    private let prestoURL = "http://www.meat-market.cz/bistro/"
    
    private func getHtmlFromServer() {
        let url = URL(string: prestoURL)!
        let task = URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            do {
                if let data = data,
                   let html = String(data: data, encoding: .utf8),
                   let menu = try self.parseHtml(html) {
                    self.processCallbacks(menu: menu, error: nil)
                }
            } catch (let error) {
                
            }
            
        }
        task.resume()
    }
    
    private func parseHtml(_ html: String) throws -> Menu? {
        do {
            let doc: Document = try SwiftSoup.parse(html)
            var mealsList = try doc.select(".tweet_list>p").map { try clean($0.html()) }
            
            // Extract date
            guard let dateRow = mealsList.first,
                  let date = extractDateFrom(string: dateRow) else {
                // Date was not extracted
                // Handle error and return
                print("FAILED: date not extracted")
                return nil
            }
            // Save the date
            guard NSCalendar.current.isDate(date.addingTimeInterval(4 * 60 * 60), inSameDayAs: Date()) else {
                // No today's menu yet
                // Handle error and return
                print("FAILED: date not current")
                return nil
            }
            
            mealsList.removeFirst()
            
            // Separate topics
            var categories = [MealCategory]()
            mealsList.forEach({
                row in
                let rowContent = detectHeadersAndSeparate(row)
                if let category = rowContent.category {
                    categories.append(MealCategory(name: category))
                }
                if let meal = rowContent.meal,
                   var currentCategory = categories.last {
                    currentCategory.meals.append(meal)
                    categories.removeLast()
                    categories.append(currentCategory)
                }
            })
            print("Menu extracted...")
            return Menu(date: date, categories: categories)
        } catch (let error) {
            print("FAILED: something went wrong")
            print(error)
            return nil
        }
    }
    
    private func detectHeadersAndSeparate(_ string: String) -> (category: MealCategoryName?, meal: Meal?) {
        if let headerString = string.matches(for: "^[^:]*(?=:)").first {
            if let bodyString = string.matches(for: "(?<=:\\s).*$").first {
                return (MealCategoryName(headerString), Meal(bodyString))
            } else {
                return (MealCategoryName(headerString), nil)
            }
        } else {
            return (nil, Meal(string.removingRegexMatches(pattern: ":\\s{0,1}", replaceWith: "") ?? ""))
        }
    }
    
    private func clean(_ string: String) -> String {
        return string.removingRegexMatches(pattern: "<[^>]*>")?
                     .replacingOccurrences(of: "&nbsp;", with: " ")
                     .replacingOccurrences(of: "&amp;", with: "&")
                     .removingRegexMatches(pattern: "\\s{4,}", replaceWith: " - ")?
                     .removingRegexMatches(pattern: "^[\\s-]*")?
                     .removingRegexMatches(pattern: "\\s*$")?
                     .removingRegexMatches(pattern: "\\s+", replaceWith: " ") ?? ""
    }
    
    private func extractDateFrom(string: String) -> Date? {
        let dateRegex = "\\d{1,2}[.]\\s{0,1}\\d{1,2}[.]\\s{0,1}\\d{4}"
        if let dateString = string.matches(for: dateRegex).first?.replacingOccurrences(of: " ", with: "") {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d.M.yyyy"
            return dateFormatter.date(from: dateString)
        }
        return nil
    }
    
    var callbacks = [(Menu?, Error?) -> ()]()
    
    func scrapeLatestMenu(callback: @escaping (_ menu: Menu?, _ error: Error?) -> ()) {
        callbacks.append(callback)
        if callbacks.count == 1 {
            getHtmlFromServer()
        }
    }
    
    func processCallbacks(menu: Menu?, error: Error?) {
        print("resolving callbacks...")
        for callback in callbacks {
            callback(menu, error)
        }
        callbacks.removeAll()
    }
}


extension String {
    
    func matches(for regex: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    func removingRegexMatches(pattern: String, replaceWith: String = "") -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
            let range = NSMakeRange(0, self.count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch {
            return nil
        }
    }
    
}

extension Meal {
    
    private static let weightRegex = "\\d{1,4}\\s{0,1}g"
    private static let priceRegex = "\\d{1,3}\\s{0,1},-[[\\/\\smenu()]*]*[\\s\\d,-]*"
    private static let numberRegex = "^\\d+"
    
    init(_ string: String) {
        var processedString = string
        if let weightString = processedString.matches(for: Meal.weightRegex).first {
            self.weight = Int(weightString.matches(for: Meal.numberRegex).first ?? "")
            processedString = processedString.removingRegexMatches(pattern: Meal.weightRegex) ?? ""
        } else {
            self.weight = nil
        }
        if let priceString = processedString.matches(for: Meal.priceRegex).first {
            self.basePrice = Int(priceString.matches(for: Meal.numberRegex).first ?? "")
            processedString = processedString.removingRegexMatches(pattern: Meal.priceRegex) ?? ""
        } else {
            self.basePrice = nil
        }
        self.name = processedString.removingRegexMatches(pattern: "^\\s", replaceWith: "")?.removingRegexMatches(pattern: "\\s$", replaceWith: "") ?? ""
    }
    
}

extension MealCategoryName {
    
    init?(_ string: String) {
        for (_, category) in MealCategoryName.titlesDictionary.enumerated() {
            for title in category.value {
                if string.lowercased().contains(title) {
                    self = category.key
                    return
                }
            }
        }
        return nil
    }
    
    private static let titlesDictionary: [MealCategoryName: [String]] = [
        .soup: ["polévka"],
        .daily: ["hlavní chod"],
        .salad: ["salát", "salad"],
        .burger: ["burger"],
        .steak: ["steak", "stejk"],
        .special: ["special", "speciál", "specialita"],
        .pasta: ["pasta", "těstoviny"]
    ]
    
}
