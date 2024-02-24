import Fluent

struct CreateOrder: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("orders")
            .id()
            .field("owner_id", .uuid, .required, .references("users", "id"))
            .field("title", .string, .required)
            .field("image", .string, .required)
            .field("skill", .uuid, .required)
            .field("task_description", .string, .required)
            .field("project_description", .string, .required)
            .field("experience", .string, .required)
            .field("data_start", .datetime, .required)
            .field("data_end", .datetime, .required)
            .field("files", .array(of: .string), .required)
            .field("is_active", .bool, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("orders").delete()
    }
}
