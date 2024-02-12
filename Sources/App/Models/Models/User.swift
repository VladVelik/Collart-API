import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "surname")
    var surname: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "user_photo")
    var userPhoto: String
    
    @Field(key: "cover")
    var cover: String
    
    @Field(key: "searchable")
    var searchable: Bool
    
    @Enum(key: "experience")
    var experience: ExperienceType
    
    @Children(for: \.$user)
    var authCredentials: [AuthCredential]

    @Children(for: \.$user)
    var authProviders: [AuthProvider]
    
    @Children(for: \.$user)
    var tabs: [Tab]

    @Children(for: \.$user)
    var portfolioProjects: [PortfolioProject]
    
    @Children(for: \.$sender)
    var sentMessages: [Message]
    
    @Children(for: \.$receiver)
    var receivedMessages: [Message]
    
    @Children(for: \.$owner)
    var orders: [Order]
    
    @Siblings(through: UserSkill.self, from: \.$user, to: \.$skill)
    var skills: [Skill]
    
    @Children(for: \.$sender)
    var initiatedInteractions: [Interaction]
    
    @Children(for: \.$getter)
    var receivedInteractions: [Interaction]
    
    @Siblings(through: OrderParticipant.self, from: \.$user, to: \.$order)
    var participatingOrders: [Order]
    
    init() {}
    
    init(
        id: UUID? = nil,
        email: String,
        name: String,
        surname: String,
        description: String,
        userPhoto: String,
        cover: String,
        searchable: Bool,
        experience: ExperienceType
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.surname = surname
        self.description = description
        self.userPhoto = userPhoto
        self.cover = cover
        self.searchable = searchable
        self.experience = experience
    }
}

extension User: Authenticatable {}

extension User {
    struct Public: Content {
        let id: UUID?
        let email: String
        let name: String
        let surname: String
        let description: String
        let userPhoto: String
        let cover: String
        let searchable: Bool
        let experience: ExperienceType
    }

    func asPublic() -> Public {
        return Public(
            id: self.id,
            email: self.email,
            name: self.name,
            surname: self.surname,
            description: self.description,
            userPhoto: self.userPhoto,
            cover: self.cover,
            searchable: self.searchable,
            experience: self.experience
        )
    }
}


