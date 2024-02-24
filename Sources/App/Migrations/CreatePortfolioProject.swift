import Fluent

struct CreatePortfolioProject: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("portfolio_projects")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            //.field("tab_id", .uuid, .required, .references("tabs", "id"))
            .field("name", .string, .required)
            .field("image", .string, .required)
            .field("description", .string, .required)
            .field("files", .array(of: .string), .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("portfolio_projects").delete()
    }
}
