//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 01.03.2024.
//

import Fluent
import Vapor

struct InteractionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let interactionsRoute = routes.grouped("interactions")
        interactionsRoute.post(use: createInteraction)
        interactionsRoute.get(":interactionID", use: getInteraction)
        interactionsRoute.get("sent", ":userID", use: getSentInteractions)
        interactionsRoute.get("received", ":userID", use: getReceivedInteractions)
        interactionsRoute.get("user", ":userID", use: getAllUserInteractions)
        interactionsRoute.post("reject", ":interactionID", use: rejectInteraction)
        interactionsRoute.post("accept", ":interactionID", use: acceptInteraction)
        interactionsRoute.delete(":interactionID", use: deleteInteraction)
    }

    // Создание интеракции
    func createInteraction(req: Request) throws -> EventLoopFuture<Interaction> {
        let interactionData = try req.content.decode(CreateRequest.self)
        guard let senderID = interactionData.senderID,
              let orderID = interactionData.orderID,
              let getterID = interactionData.getterID else {
            throw Abort(.badRequest, reason: "Необходимо предоставить senderID, orderID и getterID.")
        }

        let interaction = Interaction(
            senderID: senderID,
            orderID: orderID,
            getterID: getterID,
            status: .active // Устанавливаем статус активный
        )
        return interaction.save(on: req.db).map { interaction }
    }
    
    // Получение интеракции по ID
    func getInteraction(req: Request) throws -> EventLoopFuture<Interaction> {
        let interactionID = try req.parameters.require("interactionID", as: UUID.self)
        return Interaction.find(interactionID, on: req.db)
            .unwrap(or: Abort(.notFound))
    }

    // Получение всех интеракций, где пользователь является отправителем
    func getSentInteractions(req: Request) throws -> EventLoopFuture<[Interaction]> {
        let senderID = try req.parameters.require("userID", as: UUID.self)
        return Interaction.query(on: req.db)
            .filter(\.$sender.$id == senderID)
            .all()
    }

    // Получение всех интеракций, где пользователь является получателем
    func getReceivedInteractions(req: Request) throws -> EventLoopFuture<[Interaction]> {
        let getterID = try req.parameters.require("userID", as: UUID.self)
        return Interaction.query(on: req.db)
            .filter(\.$getter.$id == getterID)
            .all()
    }
    
    // Получение всех интеракций, где пользователь является отправителем или получателем
    func getAllUserInteractions(req: Request) throws -> EventLoopFuture<[Interaction]> {
        let userID = try req.parameters.require("userID", as: UUID.self)
        
        return Interaction.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$sender.$id == userID)
                or.filter(\.$getter.$id == userID)
            }
            .all()
    }



    // Изменение статуса интеракции на "rejected"
    func rejectInteraction(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let interactionID = try req.parameters.require("interactionID", as: UUID.self)
        let requesterData = try req.content.decode(Interaction.Requester.self)
        
        return Interaction.find(interactionID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { interaction in // Используйте flatMapThrowing для работы с исключениями
                guard interaction.$getter.id == requesterData.getterID else {
                    throw Abort(.unauthorized, reason: "Только получатель может отклонить интеракцию.")
                }
                interaction.status = .rejected
                return interaction
            }
            .flatMap { interaction in
                interaction.save(on: req.db).transform(to: .ok)
            }
    }


    func acceptInteraction(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let interactionID = try req.parameters.require("interactionID", as: UUID.self)
        let requesterData = try req.content.decode(Interaction.Requester.self)

        return Interaction.query(on: req.db)
            .filter(\.$id == interactionID)
            .with(\.$getter) // Загружаем связь с getter
            .with(\.$sender) // Загружаем связь с sender
            .with(\.$order) // Загружаем связь с order
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { interaction in
                guard interaction.getter.id == requesterData.getterID else {
                    return req.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Только получатель может принять интеракцию."))
                }
                interaction.status = .accepted

                return interaction.save(on: req.db)
                    .flatMap { _ -> EventLoopFuture<Void> in
                        // Помечаем заказ как неактивный
                        let order = interaction.order
                        order.isActive = false
                        return order.save(on: req.db)
                    }
                    .flatMap {
                        // Удаляем все остальные интеракции, связанные с этим заказом
                        Interaction.query(on: req.db)
                            .filter(\.$order.$id == interaction.order.id ?? UUID())
                            .filter(\.$id != interactionID) // Исключаем текущую интеракцию
                            .all()
                            .flatMap { interactions -> EventLoopFuture<Void> in
                                let deleteFutures = interactions.map { $0.delete(on: req.db) }
                                return EventLoopFuture.andAllComplete(deleteFutures, on: req.db.eventLoop)
                            }
                    }
                    .flatMap {
                        // Добавляем заказ в таб `collaborations` для обоих пользователей
                        let addTabForSender = Tab(userID: interaction.sender.id ?? UUID(), projectID: interaction.order.id ?? UUID(), tabType: .collaborations).save(on: req.db)
                        let addTabForGetter = Tab(userID: interaction.getter.id ?? UUID(), projectID: interaction.order.id ?? UUID(), tabType: .collaborations).save(on: req.db)
                        return addTabForSender.and(addTabForGetter).transform(to: ())
                    }
                    .flatMap {
                        // Удаляем запись этого ордера из активных табов для обоих пользователей
                        Tab.query(on: req.db)
                            .filter(\.$projectID == interaction.order.id ?? UUID())
                            .filter(\.$tabType == .active)
                            .all()
                            .flatMap { tabs -> EventLoopFuture<Void> in
                                let deleteFutures = tabs.map { $0.delete(on: req.db) }
                                return EventLoopFuture.andAllComplete(deleteFutures, on: req.db.eventLoop)
                            }
                    }
                    .transform(to: .ok)
            }
    }


    func deleteInteraction(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let interactionID = try req.parameters.require("interactionID", as: UUID.self)
        let senderData = try req.content.decode(Interaction.Sender.self)
        
        return Interaction.query(on: req.db)
            .filter(\.$id == interactionID)
            .with(\.$sender)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { interaction in
                guard interaction.sender.id == senderData.senderID,
                      interaction.status == .active || interaction.status == .rejected else {
                    return req.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Только отправитель может удалить активную или отклоненную интеракцию."))
                }
                return interaction.delete(on: req.db).transform(to: .ok)
            }
    }

}

struct CreateRequest: Content {
    var senderID: UUID?
    var orderID: UUID?
    var getterID: UUID?
}

extension Interaction {
    struct Requester: Content {
        var getterID: UUID
    }
    
    struct Sender: Content {
        var senderID: UUID
    }
}
