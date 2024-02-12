import Fluent
import Vapor

final class PortfolioProject: Model, Content {
    static let schema = "portfolio_projects"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "tab_id")
    var tab: Tab

    @Field(key: "name")
    var name: String

    @Field(key: "image")
    var image: URL

    @Field(key: "description")
    var description: String

    @Field(key: "files")
    var files: [URL]

    init() {}

    init(id: UUID? = nil, userID: UUID, tabID: UUID, name: String, image: URL, description: String, files: [URL]) {
        self.id = id
        self.$user.id = userID
        self.$tab.id = tabID
        self.name = name
        self.image = image
        self.description = description
        self.files = files
    }
}
