//
//  TabController.swift
//  
//
//  Created by Vladislav Sosin on 03.03.2024.
//

import Vapor
import Fluent

struct TabController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let tabRoute = routes.grouped("tab")
        
        let tokenProtected = tabRoute.grouped(JWTMiddleware())
        tokenProtected.get("portfolio", ":userID", use: getAllPortfolioProjects)
        tokenProtected.get("active", ":userID", use: getAllActiveOrders)
        tokenProtected.get("collaborations", ":userID", use: getAllCollaborations)
        tokenProtected.get("favorites", ":userID", use: getAllFavoriteOrders)
    }
    
    // Получение всех проектов портфолио пользователя
    func getAllPortfolioProjects(req: Request) throws -> EventLoopFuture<[PortfolioProject]> {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "User ID is required")
        }
        return Tab.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$tabType == .portfolio)
            .all()
            .flatMap { tabs in
                let projectIDs = tabs.map { $0.projectID }
                return PortfolioProject.query(on: req.db)
                    .filter(\.$id ~~ projectIDs)
                    .all()
            }
    }

    // Получение всех активных заказов пользователя
    func getAllActiveOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndToolsAndSkill]> {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "User ID is required")
        }
        return Order.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .filter(\.$isActive == true)
            .with(\.$owner)
            .all()
            .flatMap { orders in
                let orderDetailsFutures = orders.map { order in
                    let toolsFuture = order.$tools.query(on: req.db).all()
                    
                    let skillFuture = Skill.find(order.skill, on: req.db).unwrap(or: Abort(.badRequest))
                    
                    return toolsFuture.and(skillFuture).map { tools, skill in
                        let skillNames = SkillOrderNames(nameEn: skill.nameEn, nameRu: skill.nameRu)
                        return OrderWithUserAndToolsAndSkill(order: order, user: order.owner, tools: tools.map { $0.name }, skill: skillNames)
                    }
                }
                return orderDetailsFutures.flatten(on: req.eventLoop)
            }
    }
    
    // Получение всех коллабораций пользователя
    func getAllCollaborations(req: Request) throws -> EventLoopFuture<[OrderWithUserAndToolsAndSkill]> {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "User ID is required")
        }
        return Tab.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$tabType == .collaborations)
            .all()
            .flatMap { tabs in
                let orderIDs = tabs.map { $0.projectID }
                return Order.query(on: req.db)
                    .filter(\.$id ~~ orderIDs)
                    .with(\.$owner)
                    .all()
                    .flatMap { orders in
                        let orderDetailsFutures = orders.map { order in
                            let toolsFuture = order.$tools.query(on: req.db).all()
                            
                            let skillFuture = Skill.find(order.skill, on: req.db).unwrap(or: Abort(.badRequest))
                            
                            return toolsFuture.and(skillFuture).map { tools, skill in
                                let skillNames = SkillOrderNames(nameEn: skill.nameEn, nameRu: skill.nameRu)
                                return OrderWithUserAndToolsAndSkill(order: order, user: order.owner, tools: tools.map { $0.name }, skill: skillNames)
                            }
                        }
                        return orderDetailsFutures.flatten(on: req.eventLoop)
                    }
            }
    }
    
    // Получение всех избранных заказов пользователя
    func getAllFavoriteOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndToolsAndSkill]> {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "User ID is required")
        }
        return Tab.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$tabType == .favorite)
            .all()
            .flatMap { tabs in
                let orderIDs = tabs.map { $0.projectID }
                return Order.query(on: req.db)
                    .filter(\.$id ~~ orderIDs)
                    .with(\.$owner)
                    .all()
                    .flatMap { orders in
                        let orderDetailsFutures = orders.map { order in
                            let toolsFuture = order.$tools.query(on: req.db).all()
                            
                            let skillFuture = Skill.find(order.skill, on: req.db).unwrap(or: Abort(.badRequest))
                            
                            return toolsFuture.and(skillFuture).map { tools, skill in
                                let skillNames = SkillOrderNames(nameEn: skill.nameEn, nameRu: skill.nameRu)
                                return OrderWithUserAndToolsAndSkill(order: order, user: order.owner, tools: tools.map { $0.name }, skill: skillNames)
                            }
                        }
                        return orderDetailsFutures.flatten(on: req.eventLoop)
                    }
            }
    }
}
