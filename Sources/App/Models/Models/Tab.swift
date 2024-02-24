import Fluent
import Vapor

final class Tab: Model, Content {
    static let schema = "tabs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "project_id")
    var projectID: UUID

    @Enum(key: "tab_type")
    var tabType: TabType

    init() {}

    init(id: UUID? = nil, userID: UUID, projectID: UUID, tabType: TabType) {
        self.id = id
        self.$user.id = userID
        self.projectID = projectID
        self.tabType = tabType
    }
}
