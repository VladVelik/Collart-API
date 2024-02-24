import Fluent
import Vapor

final class Skill: Model, Content {
    static let schema = "skills"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name_en")
    var nameEn: String
    
    @Field(key: "name_ru")
    var nameRu: String

    @Siblings(through: UserSkill.self, from: \.$skill, to: \.$user)
    var users: [User]

    init() {}

    init(id: UUID? = nil, nameEn: String, nameRu: String) {
        self.id = id
        self.nameEn = nameEn
        self.nameRu = nameRu
    }
}
