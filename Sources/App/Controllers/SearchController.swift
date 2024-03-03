//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 03.03.2024.
//

import Vapor
import Fluent

struct SearchController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let searchRoute = routes.grouped("search")
        searchRoute.get("users", "all", use: getAllUsers)
        searchRoute.get("orders", "all", use: getAllOrders)
        searchRoute.get("filteredOrders", use: getFilteredOrders)
        searchRoute.get("filteredUsers", use: getFilteredUsers)
    }
    
    func getAllUsers(req: Request) throws -> EventLoopFuture<[User]> {
        return User.query(on: req.db)
            .filter(\.$searchable == true)
            .all()
    }
    
    func getAllOrders(req: Request) throws -> EventLoopFuture<[Order]> {
        return Order.query(on: req.db)
            .filter(\.$isActive == true)
            .all()
    }
    
    func getFilteredOrders(req: Request) throws -> EventLoopFuture<[Order]> {
        let skillNames = req.query[[String].self, at: "skills"] ?? []
        let toolNames = req.query[[String].self, at: "tools"] ?? []
        
        let experienceFilter: ExperienceType? = req.query[ExperienceType.self, at: "experience"]

        var skillIDsFuture: EventLoopFuture<[UUID]> = req.eventLoop.future([])
        if !skillNames.isEmpty {
            skillIDsFuture = Skill.query(on: req.db)
                .group(.or) { or in
                    or.filter(\.$nameEn ~~ skillNames)
                    or.filter(\.$nameRu ~~ skillNames)
                }
                .all()
                .map { $0.map { $0.id! } }
        }

        var toolIDsFuture: EventLoopFuture<[UUID]> = req.eventLoop.future([])
        if !toolNames.isEmpty {
            toolIDsFuture = Tool.query(on: req.db)
                .filter(\.$name ~~ toolNames)
                .all()
                .map { $0.map { $0.id! } }
        }
        
        return skillIDsFuture.and(toolIDsFuture).flatMap { (skillIDs, toolIDs) in
            var query = Order.query(on: req.db).filter(\.$isActive == true)
            
            if let experience = experienceFilter {
                query = query.filter(\.$experience == experience)
            }

            if !skillIDs.isEmpty {
                query = query.filter(\.$skill ~~ skillIDs)
            }
            
            if !toolIDs.isEmpty {
                query = query.join(OrderTool.self, on: \Order.$id == \OrderTool.$order.$id)
                    .filter(OrderTool.self, \OrderTool.$tool.$id ~~ toolIDs)
            }

            return query.all()
        }
    }

    func getFilteredUsers(req: Request) throws -> EventLoopFuture<[User]> {
        let skillNames = req.query[[String].self, at: "skills"] ?? []
        let toolNames = req.query[[String].self, at: "tools"] ?? []
        let experienceFilter: ExperienceType? = req.query[ExperienceType.self, at: "experience"]

        var query = User.query(on: req.db).filter(\.$searchable == true)

        if let experience = experienceFilter {
            query = query.filter(\.$experience == experience)
        }
        
        if !skillNames.isEmpty {
            query = query.join(UserSkill.self, on: \User.$id == \UserSkill.$user.$id)
                         .join(Skill.self, on: \UserSkill.$skill.$id == \Skill.$id)
                         .group(.or) { or in
                             or.filter(Skill.self, \Skill.$nameEn ~~ skillNames)
                             or.filter(Skill.self, \Skill.$nameRu ~~ skillNames)
                         }
        }
        
        if !toolNames.isEmpty {
            query = query.join(UserTool.self, on: \User.$id == \UserTool.$user.$id)
                         .join(Tool.self, on: \UserTool.$tool.$id == \Tool.$id)
                         .filter(Tool.self, \Tool.$name ~~ toolNames)
        }

        return query.all()
    }
}
