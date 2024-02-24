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
    let cloudinaryService = CloudinaryService(
        cloudName: "dwkprbrad",
        apiKey: "571257446453121",
        apiSecret: "tgoQJ4AKmlCihUe3t_oImnXTGDM"
    )
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        routes.group("projects") { authGroup in
            let tokenProtected = authGroup.grouped(JWTMiddleware())
            tokenProtected.post("addPortfolio", use: addPortfolioProject)
        }
    }
    
    func addPortfolioProject(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let createRequest = try req.content.decode(PortfolioProjectCreateRequest.self)
        
        // Сначала загрузите изображение проекта
        return try cloudinaryService.upload(file: createRequest.image, on: req).flatMap { imageUrl in
            // Затем загрузите все файлы проекта
            let fileUploads = createRequest.files.map { fileData in
                do {
                    return try cloudinaryService.upload(file: fileData, on: req)
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
}

struct PortfolioProjectCreateRequest: Content {
    var name: String
    var image: File
    var description: String
    var files: [File]
}
