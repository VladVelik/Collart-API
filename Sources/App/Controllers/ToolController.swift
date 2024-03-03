//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 01.03.2024.
//

import Fluent
import Vapor

struct ToolController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let toolsRoute = routes.grouped("tools")
        toolsRoute.post(use: create)
        toolsRoute.get(":toolID", use: get)
        toolsRoute.get(use: getAll)
        toolsRoute.put(":toolID", use: update)
        toolsRoute.delete(":toolID", use: delete)
        
        toolsRoute.get("user", ":userID", use: getUserTools)
        toolsRoute.get("order", ":orderID", use: getOrderTools)
        
        toolsRoute.post("addUserTool", use: addUserTool)
        toolsRoute.delete("removeUserTool", use: removeUserTool)
    }

    // Create a tool
    func create(req: Request) throws -> EventLoopFuture<Tool> {
        let tool = try req.content.decode(Tool.self)
        return tool.save(on: req.db).map { tool }
    }
    
    // Get a tool by ID
    func get(req: Request) throws -> EventLoopFuture<Tool> {
        let toolID = try req.parameters.require("toolID", as: UUID.self)
        return Tool.find(toolID, on: req.db)
            .unwrap(or: Abort(.notFound))
    }

    // Get all tools
    func getAll(req: Request) throws -> EventLoopFuture<[Tool]> {
        return Tool.query(on: req.db).all()
    }

    // Update a tool
    func update(req: Request) throws -> EventLoopFuture<Tool> {
        let toolID = try req.parameters.require("toolID", as: UUID.self)
        let updatedTool = try req.content.decode(Tool.self)
        return Tool.find(toolID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { tool in
                tool.name = updatedTool.name
                return tool.save(on: req.db).map { tool }
            }
    }

    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let toolID = try req.parameters.require("toolID", as: UUID.self)

        return Tool.find(toolID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { tool in
                // Проверяем, связан ли инструмент с каким-либо заказом
                let isToolUsedByOrder = tool.$orders.query(on: req.db).count().flatMap { count -> EventLoopFuture<Void> in
                    guard count == 0 else {
                        return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Tool is in use by an order and cannot be deleted."))
                    }
                    return req.eventLoop.makeSucceededFuture(())
                }
                
                // Проверяем, связан ли инструмент с каким-либо пользователем
                let isToolUsedByUser = UserTool.query(on: req.db)
                    .filter(\.$tool.$id == toolID)
                    .count()
                    .flatMap { count -> EventLoopFuture<Void> in
                        guard count == 0 else {
                            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Tool is in use by a user and cannot be deleted."))
                        }
                        return req.eventLoop.makeSucceededFuture(())
                    }
                
                return isToolUsedByOrder.and(isToolUsedByUser).flatMap { _ in
                    tool.delete(on: req.db).transform(to: .ok)
                }
            }
    }
    
    func getUserTools(req: Request) throws -> EventLoopFuture<[Tool]> {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "User ID is missing")
        }

        return UserTool.query(on: req.db)
            .filter(\.$user.$id == userID)
            .with(\.$tool)
            .all()
            .map { userTools in
                userTools.map { $0.tool }
            }
    }

    func getOrderTools(req: Request) throws -> EventLoopFuture<[Tool]> {
        guard let orderID = req.parameters.get("orderID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Order ID is missing")
        }

        return OrderTool.query(on: req.db)
            .filter(\.$order.$id == orderID)
            .with(\.$tool)
            .all()
            .map { orderTools in
                orderTools.map { $0.tool }
            }
    }
    
    func addUserTool(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let data = try req.content.decode(UserToolData.self)
        
        return User.find(data.userID, on: req.db)
            .unwrap(or: Abort(.notFound, reason: "User not found"))
            .flatMap { user in
                return Tool.find(data.toolID, on: req.db)
                    .unwrap(or: Abort(.notFound, reason: "Tool not found"))
                    .flatMap { tool in
                        let userTool = UserTool(userID: user.id!, toolID: tool.id!)
                        return userTool.save(on: req.db).transform(to: .created)
                    }
            }
    }

    func removeUserTool(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let data = try req.content.decode(UserToolData.self)
        
        return UserTool.query(on: req.db)
            .filter(\.$user.$id == data.userID)
            .filter(\.$tool.$id == data.toolID)
            .first()
            .unwrap(or: Abort(.notFound, reason: "UserTool not found"))
            .flatMap { userTool in
                userTool.delete(on: req.db).transform(to: .ok)
            }
    }


}

struct UserToolData: Content {
    let userID: UUID
    let toolID: UUID
}
