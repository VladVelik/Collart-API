import Fluent
import Vapor

final class AuthCredential: Model, Content {
    static let schema = "auth_credentials"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "login")
    var login: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: UUID? = nil, login: String, passwordHash: String, userID: UUID) {
        self.id = id
        self.login = login
        self.passwordHash = passwordHash
        self.$user.id = userID
    }
}
