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
    var userPhoto: URL
    
    @Field(key: "cover")
    var cover: URL
    
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
    
    init() {}
    
    init(
        id: UUID? = nil,
        email: String,
        name: String,
        surname: String,
        description: String,
        userPhoto: URL,
        cover: URL,
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
