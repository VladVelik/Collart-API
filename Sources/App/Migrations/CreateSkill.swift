import Fluent

struct CreateSkill: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("skills")
            .id()
            .field("name_en", .string, .required)
            .field("name_ru", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("skills").delete()
    }
}
