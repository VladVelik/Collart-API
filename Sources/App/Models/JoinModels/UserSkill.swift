import Fluent
import Vapor

final class UserSkill: Model {
    static let schema = "user_skill"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "skill_id")
    var skill: Skill

    init() {}

    init(id: UUID? = nil, userID: UUID, skillID: UUID) {
        self.id = id
        self.$user.id = userID
        self.$skill.id = skillID
    }
}
