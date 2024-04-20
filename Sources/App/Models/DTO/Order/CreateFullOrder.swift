//
//  CreateFullOrder.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Model for create order

struct OrderCreateRequest: Content {
    var title: String
    var image: File?
    var skill: String
    var taskDescription: String
    var projectDescription: String
    var experience: ExperienceType
    var tools: [String]
    var dataStart: Date
    var dataEnd: Date
    var files: [File]?
}
