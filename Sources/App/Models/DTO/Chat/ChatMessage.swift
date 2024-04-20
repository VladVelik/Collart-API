//
//  ChatMessage.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Message in chat models

extension Message {
    struct CreateRequest: Content {
        var senderID: UUID
        var receiverID: UUID
        var message: String
        var files: [File]?
        var createdAt: Date?
        var updatedAt: Date?
        var isRead: Bool
    }
}


struct FetchMessagesRequest: Content {
    var senderID: UUID
    var receiverID: UUID
    var offset: Int?
    var limit: Int?
}
