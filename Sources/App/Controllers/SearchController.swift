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
        routes.group("search") { search in
            let tokenProtected = search.grouped(JWTMiddleware())
            tokenProtected.get("users", "all", use: getAllUsers)
            tokenProtected.get("orders", "all", use: getAllOrders)
            tokenProtected.get("filteredOrders", use: getFilteredOrders)
            tokenProtected.get("filteredUsers", use: getFilteredUsers)
        }
    }
    
    func getAllUsers(req: Request) throws -> EventLoopFuture<[UserWithSkillsAndTools]> {
        let currentUser = try req.auth.require(User.self)
        return User.query(on: req.db)
            .filter(\.$searchable == true)
            .filter(\.$id != currentUser.id!)
            .all()
            .flatMap { searchableUsers in
                let usersWithSkillsAndToolsFutures = searchableUsers.map { user -> EventLoopFuture<UserWithSkillsAndTools> in
                    let skillsFuture = UserSkill.query(on: req.db)
                        .filter(\.$user.$id == user.id!)
                        .all()
                        .flatMap { userSkills -> EventLoopFuture<([SkillNames], User)> in
                            let skillIDs = userSkills.map { $0.$skill.id }
                            return Skill.query(on: req.db)
                                .filter(\.$id ~~ skillIDs)
                                .all()
                                .map { skills -> ([SkillNames], User) in
                                    let skillDict = Dictionary(uniqueKeysWithValues: skills.map { ($0.id!, $0) })
                                    let skillNames = userSkills.compactMap { userSkill -> SkillNames? in
                                        guard let skill = skillDict[userSkill.$skill.id] else {
                                            return nil
                                        }
                                        return SkillNames(
                                            nameEn: skill.nameEn,
                                            primary: userSkill.primary,
                                            nameRu: skill.nameRu
                                        )
                                    }
                                    return (skillNames, user)
                                }
                        }
                    
                    // Получаем инструменты пользователя
                    let toolsFuture = UserTool.query(on: req.db)
                        .filter(\.$user.$id == user.id!)
                        .all()
                        .flatMap { userTools -> EventLoopFuture<[String]> in
                            let toolIDs = userTools.map { $0.$tool.id }
                            return Tool.query(on: req.db)
                                .filter(\.$id ~~ toolIDs)
                                .all()
                                .map { tools in
                                    tools.map { $0.name }
                                }
                        }
                    
                    // Объединяем результаты запросов для навыков и инструментов
                    return skillsFuture.and(toolsFuture).map { (skillNamesAndUser, toolNames) in
                        let (skillNames, user) = skillNamesAndUser
                        let userPublic = user.asPublic()
                        return UserWithSkillsAndTools(user: userPublic, skills: skillNames, tools: toolNames)
                    }
                }
                return usersWithSkillsAndToolsFutures.flatten(on: req.eventLoop)
            }
    }
    
    
    
    func getAllOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndToolsAndSkill]> {
        let currentUserID = try req.auth.require(User.self).requireID()
        
        return Order.query(on: req.db)
            .filter(\.$isActive == true)
            .with(\.$owner)
            .all()
            .flatMap { orders in
                let filteredOrders = orders.filter { $0.$owner.id != currentUserID }
                
                let ordersWithDetailsFutures = filteredOrders.map { order in
                    let toolsFuture = order.$tools.query(on: req.db).all()
                    let skillFuture = Skill.find(order.skill, on: req.db)//.unwrap(or: Abort(.notFound))
                    
                    return toolsFuture.and(skillFuture).map { (tools, skill) in
                        let toolNames = tools.map { $0.name }
                        let skillNames = SkillOrderNames(nameEn: skill?.nameEn ?? "", nameRu: skill?.nameRu ?? "")
                        return OrderWithUserAndToolsAndSkill(
                            order: order,
                            user: order.owner,
                            tools: toolNames,
                            skill: skillNames
                        )
                    }
                }
                return ordersWithDetailsFutures.flatten(on: req.eventLoop)
            }
    }
    
    
    func getFilteredOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndToolsAndSkill]> {
        let currentUserID = try req.auth.require(User.self).requireID()
        let skillNames = req.content[[String].self, at: "skills"] ?? []
        let toolNames = req.content[[String].self, at: "tools"] ?? []
        let experienceFilter: [ExperienceType] = req.content[[ExperienceType].self, at: "experience"] ?? []
        
        var skillIDsFuture: EventLoopFuture<[UUID]> = req.eventLoop.future([])
        if !skillNames.isEmpty {
            skillIDsFuture = Skill.query(on: req.db)
                .group(.or) { or in
                    or.filter(\.$nameEn ~~ skillNames)
                    or.filter(\.$nameRu ~~ skillNames)
                }
                .all()
                .map { $0.compactMap { $0.id } }
        } else {
            skillIDsFuture = req.eventLoop.future([])
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
            
            if !experienceFilter.isEmpty {
                query = query.group(.or) { or in
                    for experience in experienceFilter {
                        or.filter(\.$experience == experience)
                    }
                }
            }
            
            if !skillIDs.isEmpty {
                query = query.filter(\.$skill ~~ skillIDs)
            }
            
            if !toolIDs.isEmpty {
                query = query.join(OrderTool.self, on: \Order.$id == \OrderTool.$order.$id)
                    .filter(OrderTool.self, \OrderTool.$tool.$id ~~ toolIDs)
            }
            
            return query
                .with(\.$owner)
                .all()
                .flatMap { orders in
                    let filteredOrders = orders.filter { $0.$owner.id != currentUserID }
                    
                    let ordersWithDetailsFutures = filteredOrders.map { order in
                        let toolsFuture = order.$tools.query(on: req.db).all()
                        let skillFuture = Skill.find(order.skill, on: req.db)
                        
                        return toolsFuture.and(skillFuture).map { tools, skill in
                            let skillInfo = skill.map { SkillOrderNames(nameEn: $0.nameEn, nameRu: $0.nameRu) }
                            return OrderWithUserAndToolsAndSkill(order: order, user: order.owner, tools: tools.map { $0.name }, skill: skillInfo)
                        }
                    }
                    return ordersWithDetailsFutures.flatten(on: req.eventLoop)
                }
        }
    }
    
    func getFilteredUsers(req: Request) throws -> EventLoopFuture<[UserWithSkillsAndTools]> {
        let currentUserID = try req.auth.require(User.self).requireID()
        let skillNames = req.content[[String].self, at: "skills"] ?? []
        let toolNames = req.content[[String].self, at: "tools"] ?? []
        let experienceFilter: [ExperienceType] = req.content[[ExperienceType].self, at: "experience"] ?? []
        
        let skillIDsFuture = Skill.query(on: req.db)
            .group(.or) { or in
                or.filter(\.$nameEn ~~ skillNames)
                or.filter(\.$nameRu ~~ skillNames)
            }
            .all()
            .map { $0.map { $0.id! } }
        
        let toolIDsFuture = Tool.query(on: req.db)
            .filter(\.$name ~~ toolNames)
            .all()
            .map { $0.map { $0.id! } }
        
        return skillIDsFuture.and(toolIDsFuture).flatMap { skillIDs, toolIDs in
            var query = User.query(on: req.db)
                .filter(\.$searchable == true)
                .filter(\.$id != currentUserID)
            
            if !skillIDs.isEmpty {
                query = query.join(UserSkill.self, on: \UserSkill.$user.$id == \User.$id)
                    .filter(UserSkill.self, \UserSkill.$skill.$id ~~ skillIDs)
            }
            
            if !toolIDs.isEmpty {
                query = query.join(UserTool.self, on: \UserTool.$user.$id == \User.$id)
                    .filter(UserTool.self, \UserTool.$tool.$id ~~ toolIDs)
            }
            
            if !experienceFilter.isEmpty {
                query = query.filter(\User.$experience ~~ experienceFilter)
            }
            
            return query.with(\.$skills).with(\.$tools).all().map { users in
                users.map { user in
                    let skills = user.skills.compactMap { skill in
                        SkillNames(nameEn: skill.nameEn, primary: true, nameRu: skill.nameRu)
                    }
                    let tools = user.tools.map { $0.name }
                    return UserWithSkillsAndTools(user: user.asPublic(), skills: skills, tools: tools)
                }
            }
        }
    }
}
