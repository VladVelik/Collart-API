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
    var image: URL

    @Field(key: "task_description")
    var taskDescription: String

    @Field(key: "project_description")
    var projectDescription: String

    @Enum(key: "experience")
    var experience: ExperienceType
    
    @Field(key: "data_start")
    var dataStart: Date

    @Field(key: "data_end")
    var dataEnd: Date

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
        image: URL,
        taskDescription: String,
        projectDescription: String,
        experience: ExperienceType,
        dataStart: Date,
        dataEnd: Date,
        isActive: Bool
    ) {
        self.id = id
        self.$owner.id = ownerID
        self.title = title
        self.image = image
        self.taskDescription = taskDescription
        self.projectDescription = projectDescription
        self.experience = experience
        self.dataStart = dataStart
        self.dataEnd = dataEnd
        self.isActive = isActive
    }
}
