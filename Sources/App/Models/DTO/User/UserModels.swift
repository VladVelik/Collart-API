//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

struct UserWithSkillsAndTools: Content {
    let user: User.Public
    let skills: [SkillNames]
    let tools: [String]
}
