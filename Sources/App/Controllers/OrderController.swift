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
            
            tokenProtected.get("myOrders", use: getAllOrders)
            tokenProtected.get("myOrders", ":orderID", use: getOrder)
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
        guard let orderID = req.parameters.get("orderID", as: UUID.self) else {
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


//    func updateOrder(req: Request) throws -> EventLoopFuture<HTTPStatus> {
//        let userID = try req.auth.require(User.self).requireID()
//        let updateData = try req.content.decode(OrderUpdateRequest.self)
//        //let orderID = try req.parameters.require("orderID", as: UUID.self)
//
//        return Order.find(orderID, on: req.db).unwrap(or: Abort(.notFound)).flatMapThrowing { order in
//            var updateFutures: [EventLoopFuture<Void>] = []
//
//            // Если предоставлено новое изображение, удалить старое из Cloudinary и загрузить новое
//            if let newImage = updateData.image {
//                let deleteOldImageFuture = try cloudinaryService.delete(publicId: order.image, on: req)
//                updateFutures.append(deleteOldImageFuture)
//                let uploadNewImageFuture = try cloudinaryService.upload(file: newImage, on: req).map { newImageUrl in
//                    order.image = newImageUrl
//                }
//                updateFutures.append(uploadNewImageFuture)
//            }
//
//            // Если предоставлены новые файлы, удалить старые из Cloudinary и загрузить новые
//            if let newFiles = updateData.files, !newFiles.isEmpty {
//                let deleteOldFilesFutures = order.files.map { try cloudinaryService.delete(publicId: $0, on: req) }
//                updateFutures.append(contentsOf: deleteOldFilesFutures)
//
//                let uploadNewFilesFutures = try newFiles.map { try cloudinaryService.upload(file: $0, on: req) }.flatten(on: req.eventLoop).map { newFileUrls in
//                    order.files = newFileUrls
//                }
//                updateFutures.append(uploadNewFilesFutures)
//            }
//
//            // Обновить данные заказа
//            if let title = updateData.title { order.title = title }
//            if let taskDescription = updateData.taskDescription { order.taskDescription = taskDescription }
//            if let projectDescription = updateData.projectDescription { order.projectDescription = projectDescription }
//            if let experience = updateData.experience { order.experience = experience }
//            if let dataStart = updateData.dataStart { order.dataStart = dataStart }
//            if let dataEnd = updateData.dataEnd { order.dataEnd = dataEnd }
//            //if let isActive = updateData.isActive { order.isActive = isActive }
//
//            // Найти Skill по имени, если он предоставлен
//            let skillFuture: EventLoopFuture<Void> = (updateData.skill != nil) ? Skill.query(on: req.db)
//                .group(.or) { or in
//                    or.filter(\Skill.$nameEn == updateData.skill!)
//                    or.filter(\Skill.$nameRu == updateData.skill!)
//                }
//                .first()
//                .unwrap(or: Abort(.badRequest, reason: "Skill not found"))
//                .flatMapThrowing { skill in
//                    order.skill = try skill.requireID()
//                } : req.eventLoop.makeSucceededFuture(())
//
//            updateFutures.append(skillFuture)
//
//            // Обновить инструменты, если они предоставлены
//            let toolsUpdateFuture: EventLoopFuture<Void> = (updateData.tools != nil) ? Tool.query(on: req.db)
//                .filter(\.$name ~~ updateData.tools!)
//                .all()
//                .flatMap { tools in
//                    // Удаление существующих OrderTool для этого Order
//                    OrderTool.query(on: req.db)
//                        .filter(\.$order.$id == orderID) // Уточнение key path с использованием $ для доступа к свойству модели
//                        .delete()
//                        .flatMapThrowing { _ in
//                            // Создание новых OrderTool
//                            let orderTools = try tools.map { tool in
//                                OrderTool(orderID: orderID, toolID: try tool.requireID())
//                            }
//                            return orderTools.map { orderTool in
//                                orderTool.save(on: req.db)
//                            }.flatten(on: req.eventLoop)
//                        }
//                } : req.eventLoop.makeSucceededFuture(())
//
//            updateFutures.append(toolsUpdateFuture)
//
//            // Выполнение всех обновлений
//            return EventLoopFuture.andAllSucceed(updateFutures, on: req.eventLoop).flatMap {
//                
//                // Сохранение обновленных данных заказа
//                 order.save(on: req.db)
//            }
//        }.transform(to: .ok)
//    }

    

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
    var skill: String?
    var taskDescription: String?
    var projectDescription: String?
    var experience: ExperienceType?
    var tools: [String]?
    var dataStart: Date?
    var dataEnd: Date?
    var files: [File]?
}
