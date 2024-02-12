import Fluent

struct CreateTool: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tools")
            .id()
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("tools").delete()
    }
}
