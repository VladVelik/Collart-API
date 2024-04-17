//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 01.03.2024.
//

import Vapor
import Fluent

struct MessageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let messagesRoute = routes.grouped("messages")
        
        let tokenProtected = messagesRoute
        messagesRoute.post("send", use: createMessage)
        tokenProtected.post("between", use: getMessagesBetweenUsers)
        tokenProtected.get("allMessages", use: getAllMessages)
        tokenProtected.get(":messageID", use: getMessage)
        tokenProtected.put(":messageID", use: updateMessage)
        tokenProtected.delete(":messageID", use: deleteMessage)
    }
    
    func createMessage(req: Request) throws -> EventLoopFuture<Message> {
        let messageData = try req.content.decode(Message.CreateRequest.self)
        
        let uploads: [EventLoopFuture<String>] = try messageData.files?.map { file in
            try CloudinaryService.shared.upload(file: file, on: req)
        } ?? []

        return uploads.flatten(on: req.eventLoop).flatMap { fileURLs in
            let message = Message(
                senderID: messageData.senderID,
                receiverID: messageData.receiverID,
                message: messageData.message,
                files: fileURLs,
                createdAt: Date(),
                updatedAt: nil,
                isRead: false
            )

            return message.save(on: req.db).map { message }
        }
    }
    
    func getMessagesBetweenUsers(req: Request) throws -> EventLoopFuture<[Message]> {
        let params = try req.content.decode(FetchMessagesRequest.self)
        
        return Message.query(on: req.db)
            .group(.or) { or in
                or.group(.and) { and in
                    and.filter(\.$sender.$id == params.senderID)
                    and.filter(\.$receiver.$id == params.receiverID)
                }
                or.group(.and) { and in
                    and.filter(\.$sender.$id == params.receiverID)
                    and.filter(\.$receiver.$id == params.senderID)
                }
            }
            .sort(\Message.$createdAt, .descending)
            .range(params.offset..<(params.offset + params.limit))
            .all()
            .map { messages in
                return messages.reversed()
            }
    }

    func getAllMessages(req: Request) throws -> EventLoopFuture<[Message]> {
        return Message.query(on: req.db).all()
    }
    
    func getMessage(req: Request) throws -> EventLoopFuture<Message> {
        Message.find(req.parameters.get("messageID"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }
    
    func updateMessage(req: Request) throws -> EventLoopFuture<Message> {
        let updatedMessage = try req.content.decode(Message.self)
        return Message.find(req.parameters.get("messageID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { message in
                message.message = updatedMessage.message
                message.files = updatedMessage.files
                message.isRead = updatedMessage.isRead
                return message.save(on: req.db).map { message }
            }
    }
    
    func deleteMessage(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        Message.find(req.parameters.get("messageID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { message in
                message.delete(on: req.db)
            }.transform(to: .ok)
    }
}

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
    var offset: Int
    var limit: Int
}
