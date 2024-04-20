//
//  RegisterUser.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Model for sign in

struct CreateUserRequest: Content {
    let email: String
    let passwordHash: String
    let confirmPasswordHash: String
    let name: String
    let surname: String
    let description: String
    let userPhoto: String
    let cover: String
    let searchable: Bool
    let experience: ExperienceType
    let skills: [String]
    let tools: [String]
}
