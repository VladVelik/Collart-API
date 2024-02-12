import Fluent
import Vapor

final class Tab: Model, Content {
    static let schema = "tabs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Enum(key: "type")
    var type: TabType

    @Children(for: \.$tab)
    var projects: [PortfolioProject]

    init() {}

    init(id: UUID? = nil, userID: UUID, type: TabType) {
        self.id = id
        self.$user.id = userID
        self.type = type
    }
}
