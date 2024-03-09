import Fluent
import Vapor

final class UserSkill: Model {
    static let schema = "user_skill"

    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "primary")
    var primary: Bool

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "skill_id")
    var skill: Skill

    init() {}

    init(id: UUID? = nil, primary: Bool, userID: UUID, skillID: UUID) {
        self.id = id
        self.primary = primary
        self.$user.id = userID
        self.$skill.id = skillID
    }
}
