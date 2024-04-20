//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 23.02.2024.
//

import Vapor
import Fluent
import Crypto
import JWT

struct ProjectController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        routes.group("projects") { authGroup in
            let tokenProtected = authGroup.grouped(JWTMiddleware())
            tokenProtected.get("getPortfolioProjects", use: getPortfolioProjects)
            tokenProtected.get(":projectId", use: getPortfolioProject)
            tokenProtected.put(":projectId", use: updatePortfolioProject)
            tokenProtected.delete(":projectId", use: deletePortfolioProject)
            tokenProtected.post("addPortfolio", use: addPortfolioProject)
        }
    }
    
    func getPortfolioProjects(req: Request) throws -> EventLoopFuture<[PortfolioProject]> {
        let userID = try req.auth.require(User.self).requireID()
        return PortfolioProject.query(on: req.db).filter(\.$user.$id == userID).all()
    }

    func getPortfolioProject(req: Request) throws -> EventLoopFuture<PortfolioProject> {
        guard let projectID = req.parameters.get("projectId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Необходимо указать ID проекта")
        }
        return PortfolioProject.find(projectID, on: req.db)
            .unwrap(or: Abort(.notFound))
    }
    
    func updatePortfolioProject(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let projectID = try req.parameters.require("projectId", as: UUID.self)
        let updateData = try req.content.decode(PortfolioProjectUpdateRequest.self)
        
        return PortfolioProject.find(projectID, on: req.db).unwrap(or: Abort(.notFound)).flatMapThrowing { portfolioProject in
            var deleteFutures: [EventLoopFuture<Void>] = []

            // Если предоставлено новое изображение, удалите старое
            if let _ = updateData.image {
                let oldImageUrl = portfolioProject.image
                let publicId = extractResourceName(from: oldImageUrl)
                let deleteFuture = try CloudinaryService.shared.delete(publicId: publicId ?? "", on: req)
                deleteFutures.append(deleteFuture)
            }
            
            // Если предоставлены новые файлы, удалите старые
            if let newFiles = updateData.files, !newFiles.isEmpty {
                let deleteFileFutures = try portfolioProject.files.map { oldFileUrl in
                    let publicId = extractResourceName(from: oldFileUrl)
                    return try CloudinaryService.shared.delete(publicId: publicId ?? "", on: req)
                }
                deleteFutures.append(contentsOf: deleteFileFutures)
            }

            // Сначала удалите старые изображения и файлы
            return EventLoopFuture.andAllSucceed(deleteFutures, on: req.eventLoop).flatMapThrowing {
                // Загрузка новых изображений и файлов
                let uploadImageFuture = updateData.image != nil ?
                    try CloudinaryService.shared.upload(file: updateData.image!, on: req).map { imageUrl -> String in
                        portfolioProject.image = imageUrl
                        return imageUrl
                    } : req.eventLoop.makeSucceededFuture(portfolioProject.image)
                
                let uploadFilesFuture = updateData.files != nil ?
                    try updateData.files!.map { file in
                        try CloudinaryService.shared.upload(file: file, on: req)
                    }.flatten(on: req.eventLoop).map { fileUrls -> [String] in
                        portfolioProject.files = fileUrls
                        return fileUrls
                    } : req.eventLoop.makeSucceededFuture(portfolioProject.files)
                
                return uploadImageFuture.and(uploadFilesFuture).flatMap { (_, _) in
                    // Обновление полей проекта, если они предоставлены
                    if let newName = updateData.name {
                        portfolioProject.name = newName
                    }
                    if let newDescription = updateData.description {
                        portfolioProject.description = newDescription
                    }
                    
                    // Сохранение обновленного проекта в базе данных
                    return portfolioProject.save(on: req.db)
                }
            }
        }.transform(to: .ok)
    }

    func addPortfolioProject(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let createRequest = try req.content.decode(PortfolioProjectCreateRequest.self)
        
        // Сначала загрузите изображение проекта
        return try CloudinaryService.shared.upload(file: createRequest.image, on: req).flatMap { imageUrl in
            // Затем загрузите все файлы проекта
            let fileUploads = createRequest.files.map { fileData in
                do {
                    return try CloudinaryService.shared.upload(file: fileData, on: req)
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
            
            return fileUploads.flatten(on: req.eventLoop).flatMap { fileUrls in
                // Теперь, когда у вас есть все URL-адреса, создайте и сохраните проект портфолио
                let portfolioProject = PortfolioProject(
                    userID: userID,
                    name: createRequest.name,
                    image: imageUrl,
                    description: createRequest.description,
                    files: fileUrls
                )
                
                return portfolioProject.save(on: req.db).flatMap { _ in
                    // Создайте вкладку типа 'portfolio' для этого проекта
                    guard let projectID = portfolioProject.id else {
                        return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to save portfolio project"))
                    }
                    
                    let tab = Tab(userID: userID, projectID: projectID, tabType: .portfolio)
                    return tab.save(on: req.db).transform(to: .created)
                }
            }
        }
    }
 
    func deletePortfolioProject(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let projectID = try req.parameters.require("projectId", as: UUID.self)

        return PortfolioProject.find(projectID, on: req.db).unwrap(or: Abort(.notFound)).flatMapThrowing { portfolioProject in
            // Собираем все фьючерсы удаления файлов из Cloudinary
            var deleteFutures: [EventLoopFuture<Void>] = []
            
            // Удаление основного изображения проекта, если оно есть
            if let publicId = extractResourceName(from: portfolioProject.image) {
                deleteFutures.append(try CloudinaryService.shared.delete(publicId: publicId, on: req))
            }
            
            // Удаление всех файлов проекта
            let fileDeleteFutures = try portfolioProject.files.map { fileUrl in
                if let publicId = extractResourceName(from: fileUrl) {
                    return try CloudinaryService.shared.delete(publicId: publicId, on: req)
                } else {
                    return req.eventLoop.makeSucceededFuture(())
                }
            }
            deleteFutures.append(contentsOf: fileDeleteFutures)

            // Удаление всех файлов из Cloudinary и затем удаление проекта и вкладки
            return EventLoopFuture.andAllSucceed(deleteFutures, on: req.eventLoop).flatMap {
                portfolioProject.delete(on: req.db)
            }.flatMap {
                Tab.query(on: req.db).filter(\.$projectID == projectID).delete()
            }
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
