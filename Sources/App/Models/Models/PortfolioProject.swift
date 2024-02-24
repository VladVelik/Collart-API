import Fluent
import Vapor

final class PortfolioProject: Model, Content {
    static let schema = "portfolio_projects"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "name")
    var name: String

    @Field(key: "image")
    var image: String

    @Field(key: "description")
    var description: String

    @Field(key: "files")
    var files: [String]

    init() {}

    init(id: UUID? = nil, userID: UUID, name: String, image: String, description: String, files: [String]) {
        self.id = id
        self.$user.id = userID
        self.name = name
        self.image = image
        self.description = description
        self.files = files
    }
}
