import Fluent

struct CreateTab: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tabs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("project_id", .uuid, .required)
            .field("tab_type", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tabs").delete()
    }
}
