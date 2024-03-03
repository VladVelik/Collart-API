import Fluent
import Vapor

final class Tool: Model, Content {
    static let schema = "tools"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Siblings(through: OrderTool.self, from: \.$tool, to: \.$order)
    var orders: [Order]
    
    @Siblings(through: UserTool.self, from: \.$tool, to: \.$user)
    var users: [User]

    init() {}

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
