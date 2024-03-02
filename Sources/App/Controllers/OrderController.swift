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
            tokenProtected.get("myOrders", use: getAllOrders)
            tokenProtected.get("myOrders", ":orderID", use: getOrder)
            tokenProtected.delete(":orderId", use: deleteOrder)
            
            tokenProtected.post("addOrderToFavorite", ":orderId", use: addOrderToFavorite)
            tokenProtected.delete("removeOrderFromFavorite", ":orderId", use: removeOrderFromFavorite)
        }
    }
    
    // Получение списка всех заказов текущего пользователя
    func getAllOrders(req: Request) throws -> EventLoopFuture<[Order]> {
        let userID = try req.auth.require(User.self).requireID()
        return Order.query(on: req.db)
            .filter(\.$owner.$id == userID).all()
    }

    // Получение деталей конкретного заказа текущего пользователя по ID
    func getOrder(req: Request) throws -> EventLoopFuture<Order> {
        let userID = try req.auth.require(User.self).requireID()
        guard req.parameters.get("orderID", as: UUID.self) != nil else {
            throw Abort(.badRequest, reason: "Order ID is missing or invalid")
        }
        return Order.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .first()
            .unwrap(or: Abort(.notFound))
    }

    
    func addOrder(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let createRequest = try req.content.decode(OrderCreateRequest.self)
        
        // Сначала загрузим изображение заказа на Cloudinary
        let imageUpload = try cloudinaryService.upload(file: createRequest.image, on: req)
        
        // Затем загрузим файлы заказа на Cloudinary
        let filesUploads = try createRequest.files.map { file in
            try cloudinaryService.upload(file: file, on: req)
        }
        
        // Найдем Skill по имени
        let skillLookup = Skill.query(on: req.db)
            .group(.or) { or in
                or.filter(\Skill.$nameEn == createRequest.skill)
                or.filter(\Skill.$nameRu == createRequest.skill)
            }
            .first()
            .unwrap(or: Abort(.badRequest, reason: "Skill not found"))
        
        
        return imageUpload.and(skillLookup).flatMap { (imageURL, skill) in
            filesUploads.flatten(on: req.eventLoop).flatMap { filesURLs in
                // Создание заказа (Order)
                let order = Order(
                    ownerID: userID,
                    title: createRequest.title,
                    image: imageURL,
                    skill: skill.id ?? UUID(),
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
                        // Создать новые связи OrderTool
                        let toolsFutures = tools.map { toolName -> EventLoopFuture<Void> in
                            // Здесь предполагается, что инструменты уже существуют в базе данных
                            return Tool.query(on: req.db).filter(\.$name == toolName).first().unwrap(or: Abort(.notFound)).flatMap { tool in
                                let orderTool = OrderTool(orderID: orderID, toolID: tool.id!)
                                return orderTool.save(on: req.db)
                            }
                        }
                        // Дождаться выполнения всех futures
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
            
            // Удаление связанных записей в таблицах OrderTool, Interactions, OrderParticipant, и Tab
            let deleteOrderToolFuture = OrderTool.query(on: req.db).filter(\.$order.$id == projectID).delete()
            let deleteInteractionsFuture = Interaction.query(on: req.db).filter(\.$order.$id == projectID).delete()
            let deleteOrderParticipantFuture = OrderParticipant.query(on: req.db).filter(\.$order.$id == projectID).delete()
            let deleteTabsFuture = Tab.query(on: req.db).filter(\.$projectID == projectID).delete()
            
            // Собираем все фьючерсы вместе
            return deleteImageFuture.and(deleteFilesFutures)
                .and(deleteOrderToolFuture)
                .and(deleteInteractionsFuture)
                .and(deleteOrderParticipantFuture)
                .and(deleteTabsFuture).flatMap { _ in
                    // Удаляем сам заказ
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

        // Находим запись в Tab с типом TabType.portfolio и удаляем ее
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
        
        // Извлекаем имя файла без расширения
        let fileName = lastComponent.split(separator: ".").first
        return fileName.map(String.init)
    }

}

struct OrderCreateRequest: Content {
    var title: String
    var image: File
    var skill: String
    var taskDescription: String
    var projectDescription: String
    var experience: ExperienceType
    var tools: [String]
    var dataStart: Date
    var dataEnd: Date
    var files: [File]
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
