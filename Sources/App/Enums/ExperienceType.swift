//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 30.01.2024.
//

import Vapor

enum ExperienceType: String, Codable {
    case noExperience = "no experience"
    case oneToThreeYears = "1-3 years"
    case threeToFiveYears = "3-5 years"
    case moreThanFiveYears = "more than 5 years"
}
