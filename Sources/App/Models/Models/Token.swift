
import Vapor
import JWT

enum TokenValidationError: Error {
    case tokenExpired
    case userIDInvalid
}

struct TokenPayload: JWTPayload, Authenticatable {
    let userID: UUID
    let exp: ExpirationClaim

    func verify(using signer: JWTSigner) throws {

        try exp.verifyNotExpired()
    }
}
