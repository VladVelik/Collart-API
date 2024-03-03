//
//  File.swift
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
        tokenProtected.get("portfolio", use: getAllPortfolioProjects)
        tokenProtected.get("active", use: getAllActiveOrders)
        tokenProtected.get("collaborations", use: getAllCollaborations)
        tokenProtected.get("favorites", use: getAllFavoriteOrders)
    }
    
    // Получение всех проектов портфолио пользователя
    func getAllPortfolioProjects(req: Request) throws -> EventLoopFuture<[PortfolioProject]> {
        let userID = try req.auth.require(User.self).requireID()
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
    func getAllActiveOrders(req: Request) throws -> EventLoopFuture<[Order]> {
        let userID = try req.auth.require(User.self).requireID()
        return Order.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .filter(\.$isActive == true)
            .all()
    }

    // Получение всех коллабораций пользователя
    func getAllCollaborations(req: Request) throws -> EventLoopFuture<[Order]> {
        let userID = try req.auth.require(User.self).requireID()
        return Tab.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$tabType == .collaborations)
            .all()
            .flatMap { tabs in
                let orderIDs = tabs.map { $0.projectID }
                return Order.query(on: req.db)
                    .filter(\.$id ~~ orderIDs)
                    .all()
            }
    }

    // Получение всех избранных заказов пользователя
    func getAllFavoriteOrders(req: Request) throws -> EventLoopFuture<[Order]> {
        let userID = try req.auth.require(User.self).requireID()
        return Tab.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$tabType == .favorite)
            .all()
            .flatMap { tabs in
                let orderIDs = tabs.map { $0.projectID }
                return Order.query(on: req.db)
                    .filter(\.$id ~~ orderIDs)
                    .all()
            }
    }

}
