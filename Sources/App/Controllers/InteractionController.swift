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
        
        interactionsRoute.get("owned", ":userID", use: getInteractionsForUserOwnedOrders)
       // interactionsRoute.get("invites", "owned", ":userID", use: getInteractionsForUserOwnedOrdersAsSender)
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
            status: .active
        )
        return interaction.save(on: req.db).map { interaction }
    }
    
    // Получение интеракции по ID
    func getInteraction(req: Request) throws -> EventLoopFuture<Interaction.FullInteraction> {
        let interactionID = try req.parameters.require("interactionID", as: UUID.self)
        return Interaction.find(interactionID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { interaction in
                let senderFuture = User.find(interaction.$sender.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                    self.loadFullUser(user, req: req)
                }
                let getterFuture = User.find(interaction.$getter.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                    self.loadFullUser(user, req: req)
                }
                let orderFuture = Order.find(interaction.$order.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { order in
                    self.loadFullOrder(order, req: req)
                }
                
                return senderFuture.and(getterFuture).and(orderFuture).flatMap { result in
                    let (sender, getter, fullOrder) = (result.0.0, result.0.1, result.1)
                    let fullInteraction = Interaction.FullInteraction(
                        id: interaction.id,
                        sender: sender,
                        getter: getter,
                        order: fullOrder,
                        status: interaction.status
                    )
                    return req.eventLoop.makeSucceededFuture(fullInteraction)
                }
            }
    }


    // Получение всех интеракций, где пользователь является отправителем
    func getSentInteractions(req: Request) throws -> EventLoopFuture<[Interaction.FullInteraction]> {
        let senderID = try req.parameters.require("userID", as: UUID.self)
        return Interaction.query(on: req.db)
            .filter(\.$sender.$id == senderID)
            .all()
            .flatMap { interactions in
                let fullInteractionsFutures = interactions.map { interaction in
                    let senderFuture = User.find(interaction.$sender.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                        self.loadFullUser(user, req: req)
                    }
                    let getterFuture = User.find(interaction.$getter.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                        self.loadFullUser(user, req: req)
                    }
                    let orderFuture = Order.find(interaction.$order.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { order in
                        self.loadFullOrder(order, req: req)
                    }
                    
                    return senderFuture.and(getterFuture).and(orderFuture).flatMap { result in
                        let (sender, getter, fullOrder) = (result.0.0, result.0.1, result.1)
                        let fullInteraction = Interaction.FullInteraction(
                            id: interaction.id,
                            sender: sender,
                            getter: getter,
                            order: fullOrder,
                            status: interaction.status
                        )
                        return req.eventLoop.makeSucceededFuture(fullInteraction)
                    }
                }
                return fullInteractionsFutures.flatten(on: req.eventLoop)
            }
        
    }

    // Получение всех интеракций, где пользователь является получателем
    func getReceivedInteractions(req: Request) throws -> EventLoopFuture<[Interaction.FullInteraction]> {
        let getterID = try req.parameters.require("userID", as: UUID.self)
        return Interaction.query(on: req.db)
            .filter(\.$getter.$id == getterID)
            .all()
            .flatMap { interactions in
                let fullInteractionsFutures = interactions.map { interaction in
                    let senderFuture = User.find(interaction.$sender.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                        self.loadFullUser(user, req: req)
                    }
                    let getterFuture = User.find(interaction.$getter.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                        self.loadFullUser(user, req: req)
                    }
                    let orderFuture = Order.find(interaction.$order.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { order in
                        self.loadFullOrder(order, req: req)
                    }
                    
                    return senderFuture.and(getterFuture).and(orderFuture).flatMap { result in
                        let (sender, getter, fullOrder) = (result.0.0, result.0.1, result.1)
                        let fullInteraction = Interaction.FullInteraction(
                            id: interaction.id,
                            sender: sender,
                            getter: getter,
                            order: fullOrder,
                            status: interaction.status
                        )
                        return req.eventLoop.makeSucceededFuture(fullInteraction)
                    }
                }
                return fullInteractionsFutures.flatten(on: req.eventLoop)
            }
    }
    
    func getAllUserInteractions(req: Request) throws -> EventLoopFuture<[Interaction.FullInteraction]> {
        let userID = try req.parameters.require("userID", as: UUID.self)
        
        return Interaction.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$sender.$id == userID)
                or.filter(\.$getter.$id == userID)
            }
            .all()
            .flatMap { interactions in
                let fullInteractionsFutures = interactions.map { interaction in
                    let senderFuture = User.find(interaction.$sender.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                        self.loadFullUser(user, req: req)
                    }
                    let getterFuture = User.find(interaction.$getter.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                        self.loadFullUser(user, req: req)
                    }
                    let orderFuture = Order.find(interaction.$order.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { order in
                        self.loadFullOrder(order, req: req)
                    }
                    
                    return senderFuture.and(getterFuture).and(orderFuture).flatMap { result in
                        let (sender, getter, fullOrder) = (result.0.0, result.0.1, result.1)
                        let fullInteraction = Interaction.FullInteraction(
                            id: interaction.id,
                            sender: sender,
                            getter: getter,
                            order: fullOrder,
                            status: interaction.status
                        )
                        return req.eventLoop.makeSucceededFuture(fullInteraction)
                    }
                }
                return fullInteractionsFutures.flatten(on: req.eventLoop)
            }
    }
    
    // Добавление метода в InteractionController
    func getInteractionsForUserOwnedOrders(req: Request) throws -> EventLoopFuture<[Interaction.FullInteraction]> {
        let ownerID = try req.parameters.require("userID", as: UUID.self)
        
        return Order.query(on: req.db)
            .filter(\.$owner.$id == ownerID)
            .all()
            .flatMap { orders in
                let orderIDs = orders.map { $0.id! }
                return Interaction.query(on: req.db)
                    .filter(\.$order.$id ~~ orderIDs)
                    .all()
                    .flatMap { interactions in
                        let fullInteractionsFutures = interactions.map { interaction in
                            let senderFuture = User.find(interaction.$sender.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                                self.loadFullUser(user, req: req)
                            }
                            let getterFuture = User.find(interaction.$getter.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                                self.loadFullUser(user, req: req)
                            }
                            let orderFuture = Order.find(interaction.$order.id, on: req.db).unwrap(or: Abort(.notFound)).flatMap { order in
                                self.loadFullOrder(order, req: req)
                            }
                            
                            return senderFuture.and(getterFuture).and(orderFuture).flatMap { result in
                                let (sender, getter, fullOrder) = (result.0.0, result.0.1, result.1)
                                let fullInteraction = Interaction.FullInteraction(
                                    id: interaction.id,
                                    sender: sender,
                                    getter: getter,
                                    order: fullOrder,
                                    status: interaction.status
                                )
                                return req.eventLoop.makeSucceededFuture(fullInteraction)
                            }
                        }
                        return fullInteractionsFutures.flatten(on: req.eventLoop)
                    }
            }
    }
    
    // Получение всех взаимодействий, где пользователь является отправителем и владельцем заказа
    func getInteractionsForUserOwnedOrdersAsSender(req: Request) throws -> EventLoopFuture<[Interaction.FullInteraction]> {
        let senderID = try req.parameters.require("userID", as: UUID.self)
        
        return Order.query(on: req.db)
            .filter(\.$owner.$id == senderID)
            .all()
            .flatMap { ownedOrders in
                let ownedOrderIDs = ownedOrders.map { $0.id! }
                
                return Interaction.query(on: req.db)
                    .filter(\.$sender.$id == senderID)
                    .filter(\.$order.$id ~~ ownedOrderIDs)
                    .all()
                    .flatMap { interactions in
                        let fullInteractionsFutures = interactions.map { interaction in
                            let getterFuture = self.loadFullUser(interaction.getter, req: req)
                            let orderFuture = self.loadFullOrder(interaction.order, req: req)

                            return getterFuture.and(orderFuture).map { (getter, fullOrder) in
                                Interaction.FullInteraction(
                                    id: interaction.id,
                                    sender: UserWithSkillsAndTools(user: interaction.sender.asPublic(), skills: [], tools: []),
                                    getter: getter,
                                    order: fullOrder,
                                    status: interaction.status
                                )
                            }
                        }
                        return fullInteractionsFutures.flatten(on: req.eventLoop)
                    }
            }
    }


    // Изменение статуса интеракции на "rejected"
    func rejectInteraction(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let interactionID = try req.parameters.require("interactionID", as: UUID.self)
        let requesterData = try req.content.decode(Interaction.Requester.self)
        
        return Interaction.find(interactionID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { interaction in
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
            .with(\.$getter)
            .with(\.$sender)
            .with(\.$order)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { interaction in
                guard interaction.getter.id == requesterData.getterID else {
                    return req.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Только получатель может принять интеракцию."))
                }
                interaction.status = .accepted

                return interaction.save(on: req.db)
                    .flatMap { _ -> EventLoopFuture<Void> in
                        let order = interaction.order
                        order.isActive = false
                        return order.save(on: req.db)
                    }
                    .flatMap {
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

extension InteractionController {
    private func loadFullOrder(_ order: Order, req: Request) -> EventLoopFuture<Order.FullOrder> {
        let skillsFuture = Skill.find(order.skill, on: req.db)
        let toolsFuture = order.$tools.query(on: req.db).all()
        
        return skillsFuture.and(toolsFuture).map { (skills, tools) in
            return Order.FullOrder(
                id: order.id!,
                title: order.title,
                image: order.image,
                taskDescription: order.taskDescription,
                projectDescription: order.projectDescription,
                skills: skills,
                tools: tools
            )
        }
    }
    
    private func loadFullUser(_ user: User, req: Request) -> EventLoopFuture<UserWithSkillsAndTools> {
        let userSkillsFuture = UserSkill.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .all()
        
        let userToolsFuture = UserTool.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .all()
            .flatMap { userTools in
                let toolIDs = userTools.map { $0.$tool.id }
                return Tool.query(on: req.db)
                    .filter(\.$id ~~ toolIDs)
                    .all()
            }
        
        return userSkillsFuture.and(userToolsFuture).flatMap { (userSkills, tools) in
            let skillIDs = userSkills.map { $0.$skill.id }
            let skillsFuture = Skill.query(on: req.db)
                .filter(\.$id ~~ skillIDs)
                .all()
            
            return skillsFuture.flatMap { skills in
                let skillNames = userSkills.compactMap { userSkill -> SkillNames? in
                    guard let skill = skills.first(where: { $0.id == userSkill.$skill.id }) else {
                        return nil
                    }
                    return SkillNames(
                        nameEn: skill.nameEn,
                        primary: userSkill.primary,
                        nameRu: skill.nameRu
                    )
                }
                
                let toolNames = tools.map { $0.name }
                
                let userPublic = user.asPublic()
                return req.eventLoop.makeSucceededFuture(UserWithSkillsAndTools(user: userPublic, skills: skillNames, tools: toolNames))
            }
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
    
    struct FullInteraction: Content {
        var id: UUID?
        var sender: UserWithSkillsAndTools
        var getter: UserWithSkillsAndTools
        var order: Order.FullOrder
        var status: Status
    }
}

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
