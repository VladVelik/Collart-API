//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 19.04.2024.
//

import Vapor
import Fluent

final class WebSocketsService {
    var db: Database?
    static var shared: WebSocketsService = WebSocketsService()
    
    private init() {}
    
    var connections: [UUID: WebSocket] = [:]

    func connect(userID: UUID, ws: WebSocket) {
        connections[userID] = ws
        ws.onText { websocket, text in
            self.receiveMessage(text, from: userID, on: ws.eventLoop, using: websocket)
        }
        
        ws.onClose.whenComplete { _ in
            self.connections.removeValue(forKey: userID)
        }
    }
    
    func disconnect(userID: UUID) {
        self.connections.removeValue(forKey: userID)
    }
    
    func send(message: Message, to receiverID: UUID) {
        guard let websocket = connections[receiverID] else {
            return
        }
        do {
            let data = try JSONEncoder().encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                websocket.send(jsonString)
            }
        } catch {
            print("Ошибка при кодировании сообщения: \(error)")
        }
    }
    
    func receiveMessage(_ text: String, from senderID: UUID, on eventLoop: EventLoop, using websocket: WebSocket) {
        guard let db = self.db else {
            print("Database connection not available in WebSocket service.")
            return
        }
        do {
            let messageData = try JSONDecoder().decode(Message.CreateRequest.self, from: Data(text.utf8))
            
            let message = Message(
                senderID: messageData.senderID,
                receiverID: messageData.receiverID,
                message: messageData.message,
                files: messageData.files?.compactMap { $0.filename } ?? [],
                createdAt: messageData.createdAt ?? Date(),
                updatedAt: messageData.updatedAt,
                isRead: messageData.isRead
            )
            
            _ = message.save(on: db).flatMap { _ in
                if let receiverWs = self.connections[messageData.receiverID] {
                    do {
                        let data = try JSONEncoder().encode(message)
                        if let jsonString = String(data: data, encoding: .utf8) {
                            receiverWs.send(jsonString)
                        }
                    } catch {
                        print("Failed to encode message: \(error)")
                    }
                }
                return eventLoop.makeSucceededVoidFuture()
            }.flatMapError { error in
                print("Database save error: \(error)")
                return eventLoop.makeFailedFuture(error)
            }
            
        } catch {
            print("JSON decoding error: \(error)")
            websocket.send("JSON decoding error: \(error)")
        }
    }

}
