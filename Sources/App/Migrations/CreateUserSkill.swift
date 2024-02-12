import Fluent

struct CreateUserSkill: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_skill")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("skill_id", .uuid, .required, .references("skills", "id"))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_skill").delete()
    }
}
