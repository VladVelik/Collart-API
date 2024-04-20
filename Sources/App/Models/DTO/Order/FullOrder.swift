//
//  FullOrder.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Order with details

extension Order {
    struct FullOrder: Content {
        var id: UUID
        var title: String
        var image: String
        var taskDescription: String
        var projectDescription: String
        var skills: Skill?
        var tools: [Tool]
    }
}


struct OrderWithUserAndTools: Content {
    let order: Order
    let user: User
    let tools: [Tool]
}


struct OrderWithUserAndToolsAndSkill: Content {
    var order: Order
    var user: User
    var tools: [String]
    var skill: SkillOrderNames?
}


struct SkillOrderNames: Content {
    var nameEn: String
    var nameRu: String
}
