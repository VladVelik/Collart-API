//
//  InteractiomsModel.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Interactions models

extension Interaction {
    struct Requester: Content {
        var getterID: UUID
    }
    
    struct Sender: Content {
        var senderID: UUID
    }
    
    struct FullInteraction: Content {
        var id: UUID?
        var sender: UserWithSkillsAndTools
        var getter: UserWithSkillsAndTools
        var order: OrderWithUserAndToolsAndSkill
        var status: Status
    }
}


struct CreateRequest: Content {
    var senderID: UUID?
    var orderID: UUID?
    var getterID: UUID?
}
