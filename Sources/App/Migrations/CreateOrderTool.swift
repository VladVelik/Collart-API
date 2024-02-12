import Fluent

struct CreateOrderTool: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("order_tool")
            .id()
            .field("order_id", .uuid, .required, .references("orders", "id", onDelete: .cascade))
            .field("tool_id", .uuid, .required, .references("tools", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("order_tool").delete()
    }
}
