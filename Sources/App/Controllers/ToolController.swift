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

    // Delete a tool
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let toolID = try req.parameters.require("toolID", as: UUID.self)

        // Check if the tool is associated with any orders
        return Tool.find(toolID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { tool in
                tool.$orders.query(on: req.db).count().flatMap { count in
                    guard count == 0 else {
                        return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Tool is in use by an order and cannot be deleted."))
                    }
                    return tool.delete(on: req.db).transform(to: .ok)
                }
            }
    }
}
