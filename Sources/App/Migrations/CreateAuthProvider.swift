import Fluent

struct CreateAuthProvider: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("auth_providers")
            .id()
            .field("provider", .string, .required)
            .field("access_token", .string, .required)
            .field("salt", .string, .required)
            .field("user_id", .uuid, .references("users", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("auth_providers").delete()
    }
}

