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
        
        let tokenProtected = messagesRoute.grouped(JWTMiddleware())
        tokenProtected.post(use: createMessage)
        tokenProtected.get(use: getAllMessages)
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
                isRead: false
            )

            return message.save(on: req.db).map { message }
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
        var isRead: Bool
    }
}
