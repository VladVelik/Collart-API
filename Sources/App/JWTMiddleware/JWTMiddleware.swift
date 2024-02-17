import Vapor
import JWT

struct JWTMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let token = request.headers.bearerAuthorization?.token else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Missing token."))
        }

        do {
            let payload = try request.jwt.verify(token, as: TokenPayload.self)
            return User.find(payload.userID, on: request.db)
                .unwrap(or: Abort(.unauthorized))
                .flatMap { user in
                    request.auth.login(user)
                    return next.respond(to: request)
                }
        } catch {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Invalid token."))
        }
    }
}
