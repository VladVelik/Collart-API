import Fluent
import Vapor

final class UserTool: Model {
    static let schema = "user_tool"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "tool_id")
    var tool: Tool

    init() {}

    init(id: UUID? = nil, userID: UUID, toolID: UUID) {
        self.id = id
        self.$user.id = userID
        self.$tool.id = toolID
    }
}
