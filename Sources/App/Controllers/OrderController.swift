//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 24.02.2024.
//

import Vapor
import Fluent
import Crypto
import JWT

struct OrderController: RouteCollection {
    let cloudinaryService = CloudinaryService(
        cloudName: "dwkprbrad",
        apiKey: "571257446453121",
        apiSecret: "tgoQJ4AKmlCihUe3t_oImnXTGDM"
    )
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        routes.group("orders") { authGroup in
            let tokenProtected = authGroup.grouped(JWTMiddleware())
            tokenProtected.post("addOrder", use: addOrder)
            tokenProtected.put(":orderId", use: updateOrder)
            tokenProtected.get("myOrders", use: getAllUserOrders)
            tokenProtected.get("myOrders", ":orderID", use: getOrder)
            tokenProtected.delete(":orderId", use: deleteOrder)
            
            tokenProtected.post("addOrderToFavorite", ":orderId", use: addOrderToFavorite)
            tokenProtected.delete("removeOrderFromFavorite", ":orderId", use: removeOrderFromFavorite)
        }
    }
    
    // Получение списка всех заказов текущего пользователя
    func getAllUserOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndToolsAndSkill]> {
        let userID = try req.auth.require(User.self).requireID()

        return Order.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .with(\.$owner)
            .all()
            .flatMap { orders in
                let orderDetailsFutures = orders.map { order in
                    // Получаем инструменты для заказа
                    let toolsFuture = order.$tools.query(on: req.db).all()

                    // Получаем детали скилла, используя ID скилла в заказе
                    let skillFuture = Skill.find(order.skill, on: req.db).unwrap(or: Abort(.notFound))

                    return toolsFuture.and(skillFuture).map { tools, skill in
                        // Создаём SkillNames для скилла
                        let skillNames = SkillOrderNames(nameEn: skill.nameEn, nameRu: skill.nameRu)
                        return OrderWithUserAndToolsAndSkill(order: order, user: order.owner, tools: tools.map { $0.name }, skill: skillNames)
                    }
                }
                return orderDetailsFutures.flatten(on: req.eventLoop)
            }
    }

    // Получение деталей конкретного заказа по ID
    func getOrder(req: Request) throws -> EventLoopFuture<OrderWithUserAndToolsAndSkill> {
        guard let orderID = req.parameters.get("orderID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Order ID is missing or invalid")
        }
        
        return Order.query(on: req.db)
            .filter(\.$id == orderID)
            .with(\.$owner)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { order in
                let toolsFuture = order.$tools.query(on: req.db).all()
                let skillFuture = Skill.find(order.skill, on: req.db).unwrap(or: Abort(.notFound))
                
                return toolsFuture.and(skillFuture).flatMap { (tools, skill) in
                    let userFuture = User.find(order.$owner.id, on: req.db).unwrap(or: Abort(.notFound))
                    return userFuture.map { user in
                        let skillNames = SkillOrderNames(nameEn: skill.nameEn, nameRu: skill.nameRu)
                        return OrderWithUserAndToolsAndSkill(
                            order: order,
                            user: order.owner,
                            tools: tools.map { $0.name },
                            skill: skillNames
                        )
                    }
                }
            }
    }

    
    func addOrder(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let createRequest = try req.content.decode(OrderCreateRequest.self)
        
        let skillLookup = Skill.query(on: req.db)
            .group(.or) { or in
                or.filter(\Skill.$nameEn == createRequest.skill)
                or.filter(\Skill.$nameRu == createRequest.skill)
            }
            .first()
            //.unwrap(or: Abort(.badRequest, reason: "Skill not found"))
        

        // Сначала загрузим изображение заказа на Cloudinary
        let imageUpload: EventLoopFuture<String?> = try createRequest.image.map {
                try cloudinaryService.upload(file: $0, on: req).map(Optional.some)
            } ?? req.eventLoop.future(nil)
        
        let filesUploads: [EventLoopFuture<String>] = try createRequest.files?.map {
            try cloudinaryService.upload(file: $0, on: req)
        } ?? []
        
        
        return imageUpload.and(skillLookup).flatMap { (imageURL, skill) in
            filesUploads.flatten(on: req.eventLoop).flatMap { filesURLs in
                // Создание заказа (Order)
                let order = Order(
                    ownerID: userID,
                    title: createRequest.title,
                    image: imageURL ?? "",
                    skill: skill?.id ?? UUID(),
                    taskDescription: createRequest.taskDescription,
                    projectDescription: createRequest.projectDescription,
                    experience: createRequest.experience,
                    dataStart: createRequest.dataStart,
                    dataEnd: createRequest.dataEnd,
                    files: filesURLs,
                    isActive: true
                )
                
                return order.save(on: req.db).flatMap { _ in
                    guard let orderID = order.id else {
                        return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                    }
                    
                    // Найти UUID для инструментов
                    let toolsLookup = Tool.query(on: req.db)
                        .filter(\.$name ~~ createRequest.tools)
                        .all()
                        .flatMapThrowing { tools in
                            try tools.map { tool in
                                OrderTool(orderID: orderID, toolID: try tool.requireID()).save(on: req.db)
                            }.flatten(on: req.eventLoop)
                        }
                    
                    // Создать запись в OrderParticipant для создателя заказа
                    let participantRecord = OrderParticipant(orderID: orderID, userID: userID).save(on: req.db)
                    
                    // Добавить запись в Tab для заказа
                    let tabRecord = Tab(userID: userID, projectID: orderID, tabType: .active).save(on: req.db)
                    
                    return toolsLookup.and(participantRecord).and(tabRecord).transform(to: .created)
                }
            }
        }
    }
    
    func updateOrder(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let orderID = try req.parameters.require("orderId", as: UUID.self)
        let updateData = try req.content.decode(OrderUpdateRequest.self)
        
        return Order.find(orderID, on: req.db).unwrap(or: Abort(.notFound)).flatMapThrowing { order in
            var deleteFutures: [EventLoopFuture<Void>] = []
            
            if let newImage = updateData.image {
                let deleteOldImageFuture = try cloudinaryService.delete(publicId: extractResourceName(from: order.image) ?? "", on: req)
                deleteFutures.append(deleteOldImageFuture)
                let uploadNewImageFuture = try cloudinaryService.upload(file: newImage, on: req).map { newImageUrl in
                    order.image = newImageUrl
                }
                deleteFutures.append(uploadNewImageFuture)
            }
            
            // Если предоставлены новые файлы, удалить старые из Cloudinary и загрузить новые
            if let newFiles = updateData.files, !newFiles.isEmpty {
                let deleteOldFilesFutures = try order.files.map { try cloudinaryService.delete(publicId: extractResourceName(from: $0) ?? "", on: req) }
                deleteFutures.append(contentsOf: deleteOldFilesFutures)
                
                let uploadNewFilesFutures = try newFiles.map { try cloudinaryService.upload(file: $0, on: req) }.flatten(on: req.eventLoop).map { newFileUrls in
                    order.files = newFileUrls
                }
                deleteFutures.append(uploadNewFilesFutures)
            }
            
            if let title = updateData.title { order.title = title }
            if let taskDescription = updateData.taskDescription { order.taskDescription = taskDescription }
            if let projectDescription = updateData.projectDescription { order.projectDescription = projectDescription }
            if let experience = updateData.experience { order.experience = experience }
            if let dataStart = updateData.dataStart { order.dataStart = dataStart }
            if let dataEnd = updateData.dataEnd { order.dataEnd = dataEnd }
            
            return EventLoopFuture.andAllSucceed(deleteFutures, on: req.eventLoop).flatMap {
                return order.save(on: req.db) // Сохраняем изменения в order
            }.flatMapThrowing {
                if let tools = updateData.tools {
                    // Удалить старые связи OrderTool
                    return OrderTool.query(on: req.db).filter(\.$order.$id == orderID).delete().flatMap {
                        let toolsFutures = tools.map { toolName -> EventLoopFuture<Void> in
                            return Tool.query(on: req.db).filter(\.$name == toolName).first().unwrap(or: Abort(.notFound)).flatMap { tool in
                                let orderTool = OrderTool(orderID: orderID, toolID: tool.id!)
                                return orderTool.save(on: req.db)
                            }
                        }
                        return EventLoopFuture.andAllSucceed(toolsFutures, on: req.eventLoop)
                    }
                } else {
                    return req.eventLoop.makeSucceededFuture(())
                }
            }
        }.transform(to: HTTPStatus.ok)
    }
    
    // Метод для удаления заказа, связанных файлов на Cloudinary и записей в связанных таблицах
    func deleteOrder(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let projectID = try req.parameters.require("orderId", as: UUID.self)
        
        // Найти заказ для удаления
        return Order.find(projectID, on: req.db).unwrap(or: Abort(.notFound)).flatMapThrowing { order in
            // Удаление изображения заказа с Cloudinary
            let deleteImageFuture = try cloudinaryService.delete(publicId: extractResourceName(from: order.image) ?? "", on: req)
            
            // Удаление файлов заказа с Cloudinary
            let deleteFilesFutures = try order.files.map { fileUrl in
                try cloudinaryService.delete(publicId: extractResourceName(from: fileUrl) ?? "", on: req)
            }.flatten(on: req.eventLoop)
            
            let deleteOrderToolFuture = OrderTool.query(on: req.db).filter(\.$order.$id == projectID).delete()
            let deleteInteractionsFuture = Interaction.query(on: req.db).filter(\.$order.$id == projectID).delete()
            let deleteOrderParticipantFuture = OrderParticipant.query(on: req.db).filter(\.$order.$id == projectID).delete()
            let deleteTabsFuture = Tab.query(on: req.db).filter(\.$projectID == projectID).delete()
            
            return deleteImageFuture.and(deleteFilesFutures)
                .and(deleteOrderToolFuture)
                .and(deleteInteractionsFuture)
                .and(deleteOrderParticipantFuture)
                .and(deleteTabsFuture).flatMap { _ in
                    order.delete(on: req.db)//.transform(to: .ok)
                }
        }.transform(to: .ok)
    }
    
    // Добавление проекта в портфолио пользователя
    func addOrderToFavorite(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let projectID = try req.parameters.require("orderId", as: UUID.self)

        // Создание записи в Tab с типом TabType.portfolio
        let tab = Tab(userID: userID, projectID: projectID, tabType: .favorite)

        return tab.save(on: req.db).transform(to: .created)
    }
    
    // Удаление проекта из портфолио пользователя
    func removeOrderFromFavorite(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let projectID = try req.parameters.require("orderId", as: UUID.self)

        return Tab.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$projectID == projectID)
            .filter(\.$tabType == .favorite)
            .first()
            .unwrap(or: Abort(.notFound, reason: "Project not found in portfolio"))
            .flatMap { tab in
                tab.delete(on: req.db)
            }.transform(to: .ok)
    }

    private func extractResourceName(from url: String) -> String? {
        let components = url.split(separator: "/")
        guard let lastComponent = components.last else { return nil }
        
        let fileName = lastComponent.split(separator: ".").first
        return fileName.map(String.init)
    }

}

struct OrderCreateRequest: Content {
    var title: String
    var image: File?
    var skill: String
    var taskDescription: String
    var projectDescription: String
    var experience: ExperienceType
    var tools: [String]
    var dataStart: Date
    var dataEnd: Date
    var files: [File]?
}

struct OrderUpdateRequest: Content {
    var title: String?
    var image: File?
    var taskDescription: String?
    var projectDescription: String?
    var experience: ExperienceType?
    var tools: [String]?
    var dataStart: Date?
    var dataEnd: Date?
    var files: [File]?
}

struct OrderWithUserAndTools: Content {
    let order: Order
    let user: User
    let tools: [Tool]
}

struct OrderWithUserAndToolsAndSkill: Content {
    var order: Order
    var user: User
    var tools: [String]
    var skill: SkillOrderNames?
}

struct SkillOrderNames: Content {
    var nameEn: String
    var nameRu: String
}
