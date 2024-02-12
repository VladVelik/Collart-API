import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usersRoute = routes.grouped("users")
        usersRoute.post(use: create)
        usersRoute.get(":userID", use: get)
        usersRoute.put(":userID", use: update)
        usersRoute.delete(":userID", use: delete)
    }
    
    func create(req: Request) throws -> EventLoopFuture<User> {
        let user = try req.content.decode(User.self)
        return user.save(on: req.db).map { user }
    }
    
    func get(req: Request) throws -> EventLoopFuture<User> {
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
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

    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { user in
                user.delete(on: req.db)
            }.transform(to: .noContent)
    }
}
