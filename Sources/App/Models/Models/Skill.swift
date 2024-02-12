import Fluent
import Vapor

final class Skill: Model, Content {
    static let schema = "skills"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Siblings(through: UserSkill.self, from: \.$skill, to: \.$user)
    var users: [User]

    init() {}

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
