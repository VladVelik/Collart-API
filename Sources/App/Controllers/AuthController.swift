import Vapor
import Fluent
import Crypto
import JWT

struct AuthController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        routes.group("authentication") { authGroup in
            authGroup.post("register", use: register)
            authGroup.post("login", use: login)
            
            let tokenProtected = authGroup.grouped(JWTMiddleware())
            tokenProtected.get("user", use: getUser)
        }
    }
    
    func register(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let createRequest = try req.content.decode(CreateUserRequest.self)
        
        guard createRequest.passwordHash == createRequest.confirmPasswordHash else {
            throw Abort(.badRequest, reason: "Passwords did not match")
        }
        
        return User.query(on: req.db)
            .filter(\.$email == createRequest.email)
            .first()
            .flatMapThrowing { existingUser in
                guard existingUser == nil else {
                    throw Abort(.badRequest, reason: "User with this email already exists")
                }
                
                // Создаем нового пользователя
                let user = User(email: createRequest.email, name: createRequest.name, surname: createRequest.surname, description: createRequest.description, userPhoto: createRequest.userPhoto, cover: createRequest.cover, searchable: createRequest.searchable, experience: createRequest.experience)
                
                let hashedPassword = try Bcrypt.hash(createRequest.passwordHash)
                
                return user.save(on: req.db).flatMapThrowing { _ in
                    Skill.query(on: req.db).filter(\.$nameRu ~~ createRequest.skills).all().flatMapThrowing { skills in
                        // Убеждаемся, что все навыки найдены
                        guard skills.count == createRequest.skills.count else {
                            throw Abort(.badRequest, reason: "Some skills were not found")
                        }
                        
                        let userSkills = try skills.map { skill -> UserSkill in
                            return UserSkill(userID: try user.requireID(), skillID: try skill.requireID())
                        }
                        
                        return userSkills.map { $0.save(on: req.db) }
                            .flatten(on: req.eventLoop)
                            .flatMapThrowing {
                                // Создаем учетные данные для входа в систему
                                let credential = AuthCredential(
                                    login: createRequest.email,
                                    passwordHash: hashedPassword,
                                    userID: try user.requireID())
                                return credential.save(on: req.db)
                            }
                    }
                }
            }
            .transform(to: .created)
    }
    
    
    func login(_ req: Request) throws -> EventLoopFuture<TokenResponse> {
        let loginRequest = try req.content.decode(LoginRequest.self)
        return AuthCredential.query(on: req.db)
            .filter(\.$login == loginRequest.email)
            .with(\.$user)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { credential in
                guard try Bcrypt.verify(loginRequest.password, created: credential.passwordHash) else {
                    throw Abort(.unauthorized)
                }
                let token = try generateToken(for: credential.user, req: req)
                return TokenResponse(token: token)
            }
    }
    
    func generateToken(for user: User, req: Request) throws -> String {
        let payload = TokenPayload(userID: try user.requireID(), exp: ExpirationClaim(value: Date().addingTimeInterval(60 * 60 * 24 * 30)))
        return try req.jwt.sign(payload)
    }
    
    func getUser(_ req: Request) throws -> EventLoopFuture<User.Public> {
        let user = try req.auth.require(User.self)
        return req.eventLoop.future(user.asPublic())
    }
}
