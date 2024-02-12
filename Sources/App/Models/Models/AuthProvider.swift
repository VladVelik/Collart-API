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

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: UUID? = nil, provider: String, accessToken: String, userID: UUID) {
        self.id = id
        self.provider = provider
        self.accessToken = accessToken
        self.$user.id = userID
    }
}
