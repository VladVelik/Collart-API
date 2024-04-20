//
//  UpdateOrder.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Model for update order

struct OrderUpdateRequest: Content {
    var title: String?
    var image: File?
    var taskDescription: String?
    var projectDescription: String?
    var experience: ExperienceType?
    var tools: [String]?
    var dataStart: Date?
    var dataEnd: Date?
    var files: [File]?
}
