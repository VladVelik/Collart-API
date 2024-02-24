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
        }
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
