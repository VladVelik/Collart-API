//
//  UpdateUser.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Model for user update

struct UpdateUserRequest: Content {
    var email: String?
    var passwordHash: String?
    var confirmPasswordHash: String?
    var name: String?
    var surname: String?
    var description: String?
    var searchable: Bool?
    var experience: ExperienceType?
    var skills: [String]?
    var tools: [String]?
    var image: File?
    var cover: File?
}
