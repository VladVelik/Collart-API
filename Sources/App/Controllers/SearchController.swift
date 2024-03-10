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
    
    func getAllUsers(req: Request) throws -> EventLoopFuture<[UserWithSkillsAndTools]> {
        return User.query(on: req.db)
            .filter(\.$searchable == true)
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


    
    func getAllOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndTools]> {
        return Order.query(on: req.db)
            .with(\.$owner)
            .filter(\.$isActive == true)
            .all()
            .flatMap { orders in
                let toolsFutures = orders.map { order in
                    order.$tools.query(on: req.db).all().map { (order, $0) }
                }
                
                return toolsFutures.flatten(on: req.eventLoop).map { results in
                    results.map { order, tools in
                        OrderWithUserAndTools(order: order, user: order.owner, tools: tools)
                    }
                }
            }
    }
    
    func getFilteredOrders(req: Request) throws -> EventLoopFuture<[OrderWithUserAndTools]> {
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

            return query
                .with(\.$owner)
                .all()
                .flatMap { orders in
                    let orderWithToolsFutures = orders.map { order in
                        order.$tools.query(on: req.db).all().map { tools in
                            OrderWithUserAndTools(order: order, user: order.owner, tools: tools)
                        }
                    }
                    return orderWithToolsFutures.flatten(on: req.eventLoop)
                }
        }
    }

    func getFilteredUsers(req: Request) throws -> EventLoopFuture<[UserWithSkillsAndTools]> {
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

        return query
                .all()
                .flatMap { users in
                    let usersWithSkillsAndToolsFutures = users.map { user in
                        let skillsFuture = UserSkill.query(on: req.db)
                            .filter(\.$user.$id == user.id!)
                            .all()
                            .flatMap { userSkills in
                                let skillIDs = userSkills.map { $0.$skill.id }
                                return Skill.query(on: req.db)
                                    .filter(\.$id ~~ skillIDs)
                                    .all()
                            }

                        let toolsFuture = UserTool.query(on: req.db)
                            .filter(\.$user.$id == user.id!)
                            .all()
                            .flatMap { userTools in
                                let toolIDs = userTools.map { $0.$tool.id }
                                return Tool.query(on: req.db)
                                    .filter(\.$id ~~ toolIDs)
                                    .all()
                            }

                        return skillsFuture.and(toolsFuture).map { (skills, tools) in
                            let skillNames = skills.map { SkillNames(nameEn: $0.nameEn, primary: false, nameRu: $0.nameRu) } // Используем placeholder для primary
                            let toolNames = tools.map { $0.name }
                            return UserWithSkillsAndTools(user: user.asPublic(), skills: skillNames, tools: toolNames)
                        }
                    }
                    return usersWithSkillsAndToolsFutures.flatten(on: req.eventLoop)
                }
    }
}
