import Fluent

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.enum(ExperienceType.name)
            .case("no_experience")
            .case("1-3_years")
            .case("3-5_years")
            .case("more_than_5_years")
            .create()
            .flatMap { experienceType in
                database.schema("users")
                    .id()
                    .field("email", .string, .required)
                    .field("name", .string, .required)
                    .field("surname", .string, .required)
                    .field("description", .string, .required)
                    .field("user_photo", .string, .required)
                    .field("cover", .string, .required)
                    .field("searchable", .bool, .required)
                    .field("experience", experienceType, .required)
                    .create()
            }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema).delete()
    }
}
