//
//  ChatPreview.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Model for all chats view

struct ChatPreview: Content {
    var userID: UUID
    var userName: String
    var userPhotoURL: String
    var lastMessage: String
    var unreadMessagesCount: Int
    var messageTime: Date
    var isRead: Bool
}
