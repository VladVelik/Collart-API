import Fluent

struct CreateMessage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("messages")
            .id()
            .field("sender_id", .uuid, .required, .references("users", "id"))
            .field("receiver_id", .uuid, .required, .references("users", "id"))
            .field("message", .string, .required)
            .field("files", .array(of: .string), .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("is_read", .bool, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("messages").delete()
    }
}

