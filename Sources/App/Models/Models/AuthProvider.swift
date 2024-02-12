import Fluent
import Vapor

final class AuthProvider: Model, Content {
    static let schema = "auth_providers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "provider")
    var provider: String

    @Field(key: "access_token")
    var accessToken: String
    
    @Field(key: "salt")
    var salt: String

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: UUID? = nil, provider: String, accessToken: String, salt: String, userID: UUID) {
        self.id = id
        self.provider = provider
        self.accessToken = accessToken
        self.salt = salt
        self.$user.id = userID
    }
}
