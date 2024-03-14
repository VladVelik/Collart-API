import Fluent
import Vapor

final class Order: Model, Content {
    static let schema = "orders"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "title")
    var title: String

    @Field(key: "image")
    var image: String
    
    @Field(key: "skill")
    var skill: UUID

    @Field(key: "task_description")
    var taskDescription: String

    @Field(key: "project_description")
    var projectDescription: String

    @Enum(key: "experience")
    var experience: ExperienceType
    
    @Timestamp(key: "data_start", on: .none)
    var dataStart: Date?

    @Timestamp(key: "data_end", on: .none)
    var dataEnd: Date?
    
    @Field(key: "files")
    var files: [String]

    @Field(key: "is_active")
    var isActive: Bool
    
    @Siblings(through: OrderTool.self, from: \.$order, to: \.$tool)
    var tools: [Tool]
    
    @Siblings(through: OrderParticipant.self, from: \.$order, to: \.$user)
    var participants: [User]

    init() {}

    init(
        id: UUID? = nil,
        ownerID: UUID,
        title: String,
        image: String,
        skill: UUID,
        taskDescription: String,
        projectDescription: String,
        experience: ExperienceType,
        dataStart: Date,
        dataEnd: Date,
        files: [String],
        isActive: Bool
    ) {
        self.id = id
        self.$owner.id = ownerID
        self.title = title
        self.image = image
        self.skill = skill
        self.taskDescription = taskDescription
        self.projectDescription = projectDescription
        self.experience = experience
        self.dataStart = dataStart
        self.dataEnd = dataEnd
        self.files = files
        self.isActive = isActive
    }
}
