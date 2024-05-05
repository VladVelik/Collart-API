//
//  MessageController.swift
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
        tokenProtected.get("chats", ":userID", use: getAllChatsHandler)
        tokenProtected.post("markRead", use: markMessagesAsRead)
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
            
            return message.save(on: req.db).flatMap {
                WebSocketsService.shared.send(message: message, to: messageData.receiverID)
                return req.eventLoop.future(message)
            }
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
            .range((params.offset ?? 0)..<((params.offset ?? 0) + (params.limit ?? 100)))
            .all()
            .map { messages in
                return messages.reversed()
            }
    }
    
    func getAllChatsHandler(req: Request) throws -> EventLoopFuture<[ChatPreview]> {
        guard let userIDString = req.parameters.get("userID"), let userID = UUID(uuidString: userIDString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        return try getAllChats(for: userID, req: req)
    }
    
    func getAllChats(for userID: UUID, req: Request) throws -> EventLoopFuture<[ChatPreview]> {
        User.query(on: req.db)
            .all()
            .flatMapThrowing { users in
                try users.map { user -> EventLoopFuture<ChatPreview?> in
                    let lastMessageFuture = Message.query(on: req.db)
                        .group(.or) { or in
                            or.group(.and) { and in
                                and.filter(\.$sender.$id == userID)
                                and.filter(\.$receiver.$id == user.id!)
                            }
                            or.group(.and) { and in
                                and.filter(\.$sender.$id == user.id!)
                                and.filter(\.$receiver.$id == userID)
                            }
                        }
                        .sort(\.$createdAt, .descending)
                        .first()
                    
                    let unreadCountFuture = Message.query(on: req.db)
                        .filter(\.$receiver.$id == userID)
                        .filter(\.$sender.$id == user.id!)
                        .filter(\.$isRead == false)
                        .count()
                    
                    return lastMessageFuture.and(unreadCountFuture).map { (lastMessage, unreadCount) in
                        guard let lastMessage = lastMessage, !lastMessage.message.isEmpty else { return nil }
                        return ChatPreview(
                            userID: user.id!,
                            userName: user.name + " " + user.surname,
                            userPhotoURL: user.userPhoto,
                            lastMessage: lastMessage.message,
                            unreadMessagesCount: unreadCount,
                            messageTime: lastMessage.createdAt ?? Date(),
                            isRead: lastMessage.isRead
                        )
                    }
                }
            }
            .flatMap { $0.flatten(on: req.eventLoop) }
            .map { $0.compactMap { $0 } }
    }
    
    func markMessagesAsRead(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let params = try req.content.decode(FetchMessagesRequest.self)
        
        var query = Message.query(on: req.db)
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
            .filter(\.$isRead == false)

        if let offset = params.offset {
            query = query.range((params.offset ?? 0)..<((params.offset ?? 0) + (params.limit ?? 100)))
        }

        return query.all()
            .flatMap { messages in
                messages.map { message in
                    message.isRead = true
                    return message.update(on: req.db)
                }.flatten(on: req.eventLoop)
            }
            .transform(to: .ok)
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
