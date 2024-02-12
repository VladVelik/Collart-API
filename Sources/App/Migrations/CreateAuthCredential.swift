import Fluent

struct CreateAuthCredential: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("auth_credentials")
            .id()
            .field("login", .string, .required)
            .field("password_hash", .string, .required)
            .field("user_id", .uuid, .references("users", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("auth_credentials").delete()
    }
}
