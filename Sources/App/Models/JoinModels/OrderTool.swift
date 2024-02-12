import Fluent
import Vapor

final class OrderTool: Model {
    static let schema = "order_tool"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "order_id")
    var order: Order

    @Parent(key: "tool_id")
    var tool: Tool

    init() {}

    init(id: UUID? = nil, orderID: UUID, toolID: UUID) {
        self.id = id
        self.$order.id = orderID
        self.$tool.id = toolID
    }
}
