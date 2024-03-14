import Vapor
import Fluent

struct UserController: RouteCollection {
    let cloudinaryService = CloudinaryService(
        cloudName: "dwkprbrad",
        apiKey: "571257446453121",
        apiSecret: "tgoQJ4AKmlCihUe3t_oImnXTGDM"
    )
    
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
        
        return try cloudinaryService.upload(file: input.file, on: req).flatMap { imageUrl in
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
        return try cloudinaryService.delete(publicId: publicId, on: req).flatMap { status in
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

        // Запрашиваем все UserSkill для этого пользователя
        return UserSkill.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
            .flatMap { userSkills in
                // Извлекаем идентификаторы навыков из UserSkill
                let skillIDs = userSkills.map { $0.$skill.id }

                // Запрашиваем навыки по этим идентификаторам
                return Skill.query(on: req.db)
                    .filter(\.$id ~~ skillIDs)
                    .all()
            }
    }
    
    func updateUser(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let updateUserRequest = try req.content.decode(UpdateUserRequest.self)
        
        let userID = try req.auth.require(User.self).requireID()

        return req.db.transaction { db in
            User.find(userID, on: db)
                .unwrap(or: Abort(.notFound))
                .flatMap { user in
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

                    return user.save(on: db).flatMap {
                        if updateLogin {
                            return AuthCredential.query(on: db)
                                .filter(\.$user.$id == userID)
                                .first()
                                .unwrap(or: Abort(.notFound))
                                .flatMap { authCredential in
                                    authCredential.login = user.email
                                    return authCredential.save(on: db)
                                }
                        } else {
                            return db.eventLoop.makeSucceededFuture(())
                        }
                    }.flatMap {
                        if let password = updateUserRequest.passwordHash, let confirmPassword = updateUserRequest.confirmPasswordHash, !password.isEmpty, password == confirmPassword {
                            return AuthCredential.query(on: db)
                                .filter(\.$user.$id == userID)
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
                }
        }
    }
}

struct FileUpload: Codable {
    var file: File
}

struct CloudinaryUploadResponse: Codable {
    let url: String
}
