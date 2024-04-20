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
        ws.onClose.whenComplete { _ in
            self.disconnect(userID: userID)
        }
    }
    
    func disconnect(userID: UUID) {
        connections.removeValue(forKey: userID)
    }
    
    func send(message: Message, to receiverID: UUID) {
        guard let websocket = connections[receiverID], let db = self.db else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { (date, encoder) throws in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                let dateString = dateFormatter.string(from: date)
                var container = encoder.singleValueContainer()
                try container.encode(dateString)
            }
            
            let data = try encoder.encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                websocket.send(jsonString)
            }
        } catch {
            print("Ошибка при кодировании сообщения: \(error)")
        }
    }
}
