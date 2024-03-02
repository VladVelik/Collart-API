//
//  File.swift
//  
//
//  Created by Vladislav Sosin on 01.03.2024.
//

import Fluent
import Vapor

struct SkillController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let skillsRoute = routes.grouped("skills")
        skillsRoute.get(use: getAll)
        skillsRoute.get("id", ":skillID", use: get)
        skillsRoute.get(":language", use: getAllByLanguage)
        skillsRoute.post(use: create)
        skillsRoute.put(":skillID", use: update)
        skillsRoute.delete(":skillID", use: delete)
    }

    // Создание скилла
    func create(req: Request) throws -> EventLoopFuture<Skill> {
        let skill = try req.content.decode(Skill.self)
        return skill.save(on: req.db).map { skill }
    }
    
    // Get a skill by ID
    func get(req: Request) throws -> EventLoopFuture<Skill> {
        let skillID = try req.parameters.require("skillID", as: UUID.self)
        return Skill.find(skillID, on: req.db)
            .unwrap(or: Abort(.notFound))
    }

    // Получение всех скиллов
    func getAll(req: Request) throws -> EventLoopFuture<[Skill]> {
        return Skill.query(on: req.db).all()
    }

    // Получение всех скиллов на заданном языке
    func getAllByLanguage(req: Request) throws -> EventLoopFuture<[String]> {
        guard let language = req.parameters.get("language"), ["en", "ru"].contains(language) else {
            throw Abort(.badRequest, reason: "Language parameter must be either 'en' or 'ru'.")
        }
        
        return Skill.query(on: req.db).all().map { skills in
            skills.map { skill in
                language == "en" ? skill.nameEn : skill.nameRu
            }
        }
    }

    // Обновление скилла
    func update(req: Request) throws -> EventLoopFuture<Skill> {
        let updatedSkillData = try req.content.decode(Skill.self)
        let skillID = try req.parameters.require("skillID", as: UUID.self)
        
        return Skill.find(skillID, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { skill in
                skill.nameEn = updatedSkillData.nameEn
                skill.nameRu = updatedSkillData.nameRu
                return skill.save(on: req.db).map { skill }
            }
    }

    // Удаление скилла с проверкой на связи с пользователями и заказами
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let skillID = try req.parameters.require("skillID", as: UUID.self)
        
        // Проверяем, связан ли скилл с каким-либо пользователем
        let isSkillUsedByUser = UserSkill.query(on: req.db)
            .filter(\.$skill.$id == skillID)
            .first()
            .flatMapThrowing { existingUserSkill in
                guard existingUserSkill == nil else {
                    throw Abort(.badRequest, reason: "Skill is in use by a user and cannot be deleted.")
                }
            }
        
        // Проверяем, связан ли скилл с каким-либо заказом
        let isSkillUsedByOrder = Order.query(on: req.db)
            .filter(\.$skill == skillID) // Use the $ prefix for the property wrapper
            .first()
            .flatMapThrowing { existingOrder in
                guard existingOrder == nil else {
                    throw Abort(.badRequest, reason: "Skill is in use by an order and cannot be deleted.")
                }
            }

        
        // Выполняем обе проверки перед удалением скилла
        return isSkillUsedByUser.and(isSkillUsedByOrder).flatMap { _ in
            Skill.find(skillID, on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { skill in
                    skill.delete(on: req.db)
                }
        }.transform(to: .ok)
    }

}