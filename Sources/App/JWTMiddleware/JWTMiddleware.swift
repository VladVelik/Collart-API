import Vapor
import JWT

import Vapor

//struct JWTMiddleware: Middleware {
//    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
//        guard let token = request.headers.bearerAuthorization?.token else {
//            return request.eventLoop.makeFailedFuture(Abort(.badGateway, reason: "Missing token."))
//        }
//        
//        do {
//            let payload = try request.jwt.verify(token, as: TokenPayload.self)
//            request.auth.login(payload)
//            return next.respond(to: request)
//        } catch let error as TokenValidationError {
//            switch error {
//            case .tokenExpired:
//                print("Token expired.")
//                return request.eventLoop.makeFailedFuture(Abort(.notFound, reason: "Token expired."))
//            case .userIDInvalid:
//                print("Invalid userID.")
//                return request.eventLoop.makeFailedFuture(Abort(.conflict, reason: "Invalid userID."))
//            }
//        } catch {
//            print("JWT verification failed: \(error.localizedDescription)")
//            return request.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "JWT verification failed: \(error.localizedDescription)"))
//        }
//    }
//}
//
//
//struct ErrorResponse: Content {
//    let reason: String
//}

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
