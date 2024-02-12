import Fluent

struct CreateTab: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.enum("tab_type")
            .case("portfolio")
            .case("active")
            .case("collaborations")
            .case("favorite")
            .create()
            .flatMap { tabType in
                database.schema("tabs")
                    .id()
                    .field("user_id", .uuid, .required, .references("users", "id"))
                    .field("type", tabType, .required)
                    .create()
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tabs").delete()
    }
}
