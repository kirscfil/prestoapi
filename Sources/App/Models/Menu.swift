//
//  Model.swift
//  App
//
//  Created by Filip Kirschner on 16/03/2018.
//

import Foundation
import Vapor

struct Menu: Content {
    
    let date: Date
    let categories: [MealCategory]
    
}

struct Meal: Content {
    
    let name: String
    let weight: Int?
    let basePrice: Int?
    
}

struct MealCategory: Content {
    
    let name: MealCategoryName
    var meals: [Meal]
    
    init(name: MealCategoryName, meals: [Meal] = []) {
        self.name = name
        self.meals = meals
    }
    
}

enum MealCategoryName: String, Content {
    
    case soup = "soup"
    case daily = "daily"
    case salad = "salad"
    case burger = "burger"
    case special = "special"
    case pasta = "pasta"
    case steak = "steak"
}
