import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usersRoute = routes.grouped("users")
        usersRoute.get(":userID", use: get)
        
        let tokenProtected = usersRoute.grouped(JWTMiddleware())
        tokenProtected.post(":userID", "photo", use: { req in
            try self.uploadImage(req: req, imageType: .photo)
        })
        tokenProtected.delete("photo", ":publicId", use: { req in
            try self.deleteImage(req: req, imageType: .photo)
        })
        tokenProtected.post(":userID", "cover", use: { req in
            try self.uploadImage(req: req, imageType: .cover)
        })
        tokenProtected.delete("cover", ":publicId", use: { req in
            try self.deleteImage(req: req, imageType: .cover)
        })
        
        tokenProtected.get("skills", use: getUserSkills)
        tokenProtected.put("updateUser", use: updateUser)
    }
    
    func get(req: Request) throws -> EventLoopFuture<UserWithSkillsAndTools> {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "User ID is required")
        }

        return User.find(userID, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
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
            
            return skillsFuture.and(toolsFuture).map { (skillNamesAndUser, toolNames) in
                let (skillNames, user) = skillNamesAndUser
                let userPublic = user.asPublic()
                return UserWithSkillsAndTools(user: userPublic, skills: skillNames, tools: toolNames)
            }
        }
    }

    
    func update(req: Request) throws -> EventLoopFuture<User> {
        let updatedUserData = try req.content.decode(User.self)
        return User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                user.email = updatedUserData.email
                user.name = updatedUserData.name
                user.surname = updatedUserData.surname
                user.description = updatedUserData.description
                user.userPhoto = updatedUserData.userPhoto
                user.cover = updatedUserData.cover
                user.searchable = updatedUserData.searchable
                user.experience = updatedUserData.experience
                return user.save(on: req.db).map { user }
            }
    }
    
    func uploadImage(req: Request, imageType: ImageType) throws -> EventLoopFuture<User.Public> {
        let userID = try req.parameters.require("userID", as: UUID.self)
        
        let input = try req.content.decode(FileUpload.self)
        
        return try CloudinaryService.shared.upload(file: input.file, on: req).flatMap { imageUrl in
            return User.find(userID, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                switch imageType {
                case .photo:
                    user.userPhoto = imageUrl
                case .cover:
                    user.cover = imageUrl
                }
                return user.save(on: req.db).map { user.asPublic() }
            }
        }
    }
    
    func deleteImage(req: Request, imageType: ImageType) throws -> EventLoopFuture<HTTPStatus> {
        guard let publicId = req.parameters.get("publicId") else {
            throw Abort(.badRequest, reason: "Missing publicId")
        }
        let userID = try req.auth.require(User.self).requireID()
        return try CloudinaryService.shared.delete(publicId: publicId, on: req).flatMap { status in
            // После успешного удаления изображения, ищем пользователя и обновляем его запись
            User.find(userID, on: req.db).flatMap { user in
                guard let user = user else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "User not found"))
                }
                switch imageType {
                case .photo:
                    user.userPhoto = ""
                case .cover:
                    user.cover = ""
                }
                return user.save(on: req.db).transform(to: .ok)
            }
        }
    }
    
    func getUserSkills(_ req: Request) throws -> EventLoopFuture<[Skill]> {
        // Извлекаем идентификатор пользователя из токена
        let userID = try req.auth.require(User.self).requireID()

        return UserSkill.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
            .flatMap { userSkills in
                let skillIDs = userSkills.map { $0.$skill.id }

                return Skill.query(on: req.db)
                    .filter(\.$id ~~ skillIDs)
                    .all()
            }
    }
    
    func updateUser(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let userID = try req.auth.require(User.self).requireID()
        let updateUserRequest = try req.content.decode(UpdateUserRequest.self)
        
        return req.db.transaction { db in
            self.updateUserDetails(userID: userID, updateUserRequest: updateUserRequest, db: db, req: req)
        }
    }
}


// MARK: - Private methods
extension UserController {
    private func updateUserDetails(userID: UUID, updateUserRequest: UpdateUserRequest, db: Database, req: Request) -> EventLoopFuture<HTTPStatus> {
        User.find(userID, on: db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                self.updateUserImages(user: user, updateUserRequest: updateUserRequest, req: req)
                    .flatMap {
                        self.applyUserUpdates(user: user, updateUserRequest: updateUserRequest)
                        return user.save(on: db)
                    }
                    .flatMap {
                        self.updateAuthCredentialIfNeeded(user: user, updateUserRequest: updateUserRequest, db: db)
                    }
                    .flatMap {
                        self.updatePasswordIfNeeded(user: user, updateUserRequest: updateUserRequest, db: db)
                    }
                    .flatMap { _ in
                        self.updateUserSkillsAndToolsIfNeeded(user: user, updateUserRequest: updateUserRequest, db: db)
                    }
            }
    }
    
    private func applyUserUpdates(user: User, updateUserRequest: UpdateUserRequest) {
        var updateLogin = false
        
        if let email = updateUserRequest.email, !email.isEmpty {
            user.email = email
            updateLogin = true
        }
        if let name = updateUserRequest.name, !name.isEmpty { user.name = name }
        if let surname = updateUserRequest.surname, !surname.isEmpty { user.surname = surname }
        if let description = updateUserRequest.description, !description.isEmpty { user.description = description }
        if let searchable = updateUserRequest.searchable { user.searchable = searchable }
        if let experience = updateUserRequest.experience { user.experience = experience }
    }
    
    private func updateAuthCredentialIfNeeded(user: User, updateUserRequest: UpdateUserRequest, db: Database) -> EventLoopFuture<Void> {
        if updateUserRequest.email != nil && !updateUserRequest.email!.isEmpty {
            return AuthCredential.query(on: db)
                .filter(\.$user.$id == user.id ?? UUID())
                .first()
                .unwrap(or: Abort(.notFound))
                .flatMap { authCredential in
                    authCredential.login = user.email
                    return authCredential.save(on: db)
                }
        } else {
            return db.eventLoop.makeSucceededFuture(())
        }
    }
    
    private func updatePasswordIfNeeded(user: User, updateUserRequest: UpdateUserRequest, db: Database) -> EventLoopFuture<HTTPStatus> {
        if let password = updateUserRequest.passwordHash, 
            let confirmPassword = updateUserRequest.confirmPasswordHash,
            !password.isEmpty, password == confirmPassword {
            return AuthCredential.query(on: db)
                .filter(\.$user.$id == user.id ?? UUID())
                .first()
                .unwrap(or: Abort(.notFound))
                .flatMap { authCredential in
                    do {
                        let hashedPassword = try Bcrypt.hash(password)
                        authCredential.passwordHash = hashedPassword
                        return authCredential.save(on: db).transform(to: .ok)
                    } catch {
                        return db.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to hash password"))
                    }
                }
        } else {
            return db.eventLoop.makeSucceededFuture(.ok)
        }
    }
    
    private func updateUserSkillsAndToolsIfNeeded(user: User, updateUserRequest: UpdateUserRequest, db: Database) -> EventLoopFuture<HTTPStatus> {
        let skillUpdateFuture: EventLoopFuture<Void>
        
        if let skills = updateUserRequest.skills {
            skillUpdateFuture = UserSkill.query(on: db)
                .filter(\.$user.$id == user.id!)
                .delete()
                .flatMap {
                    Skill.query(on: db)
                        .group(.or) { or in
                            or.filter(\.$nameRu ~~ skills)
                            or.filter(\.$nameEn ~~ skills)
                        }
                        .all()
                        .flatMap { fetchedSkills in
                            var isFirst = true
                            let userSkills = fetchedSkills.map { skill -> EventLoopFuture<Void> in
                                let isPrimary = isFirst
                                isFirst = false
                                let userSkill = UserSkill(primary: isPrimary, userID: user.id!, skillID: skill.id!)
                                return userSkill.save(on: db)
                            }
                            return EventLoopFuture<Void>.andAllSucceed(userSkills, on: db.eventLoop)
                        }
                }
        } else {
            skillUpdateFuture = db.eventLoop.makeSucceededFuture(())
        }

        let toolUpdateFuture: EventLoopFuture<Void>
        
        if let tools = updateUserRequest.tools {
            toolUpdateFuture = UserTool.query(on: db)
                .filter(\.$user.$id == user.id!)
                .delete()
                .flatMap {
                    Tool.query(on: db)
                        .filter(\.$name ~~ tools)
                        .all()
                        .flatMap { fetchedTools in
                            let userTools = fetchedTools.map { tool -> EventLoopFuture<Void> in
                                let userTool = UserTool(userID: user.id!, toolID: tool.id!)
                                return userTool.save(on: db)
                            }
                            return EventLoopFuture<Void>.andAllSucceed(userTools, on: db.eventLoop)
                        }
                }
        } else {
            toolUpdateFuture = db.eventLoop.makeSucceededFuture(())
        }

        return skillUpdateFuture.and(toolUpdateFuture).transform(to: .ok)
    }
    
    private func updateUserImages(user: User, updateUserRequest: UpdateUserRequest, req: Request) -> EventLoopFuture<Void> {
        var deleteFutures: [EventLoopFuture<Void>] = []

        if let newPhoto = updateUserRequest.image {
            do {
                let deleteOldPhotoFuture = try CloudinaryService.shared.delete(publicId: extractResourceName(from: user.userPhoto) ?? "", on: req)
                deleteFutures.append(deleteOldPhotoFuture)

                let uploadNewPhotoFuture = try CloudinaryService.shared.upload(file: newPhoto, on: req).map { newPhotoUrl in
                    user.userPhoto = newPhotoUrl
                }
                deleteFutures.append(uploadNewPhotoFuture)
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }

        if let newCover = updateUserRequest.cover {
            do {
                let deleteOldCoverFuture = try CloudinaryService.shared.delete(publicId: extractResourceName(from: user.cover) ?? "", on: req)
                deleteFutures.append(deleteOldCoverFuture)

                let uploadNewCoverFuture = try CloudinaryService.shared.upload(file: newCover, on: req).map { newCoverUrl in
                    user.cover = newCoverUrl
                }
                deleteFutures.append(uploadNewCoverFuture)
            } catch {
                return req.eventLoop.makeFailedFuture(error)
            }
        }

        return EventLoopFuture.andAllSucceed(deleteFutures, on: req.eventLoop)
    }


    private func extractResourceName(from url: String?) -> String? {
        return url?.components(separatedBy: "/").last?.components(separatedBy: ".").first
    }
}
