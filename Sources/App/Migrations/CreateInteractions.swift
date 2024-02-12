import Fluent

struct CreateInteractions: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.enum("status")
            .case("rejected")
            .case("active")
            .case("accepted")
            .create()
            .flatMap { status in
                database.schema("interactions")
                    .id()
                    .field("sender_id", .uuid, .required, .references("users", "id"))
                    .field("order_id", .uuid, .required, .references("orders", "id", onDelete: .cascade))
                    .field("getter_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
                    .field("status", status, .required)
                    .create()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("interactions").delete()
    }
}
