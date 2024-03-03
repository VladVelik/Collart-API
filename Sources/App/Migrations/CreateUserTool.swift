import Fluent

struct CreateUserTool: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_tool")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("tool_id", .uuid, .required, .references("tools", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_tool").delete()
    }
}
