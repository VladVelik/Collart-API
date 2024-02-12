import Fluent

struct CreateOrderParticipant: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("order_participants")
            .id()
            .field("order_id", .uuid, .required, .references("orders", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("order_participants").delete()
    }
}
