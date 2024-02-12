import Fluent
import Vapor

final class Message: Model, Content {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "sender_id")
    var sender: User

    @Parent(key: "receiver_id")
    var receiver: User

    @Field(key: "message")
    var message: String

    @Field(key: "files")
    var files: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "is_read")
    var isRead: Bool

    init() {}

    init(id: UUID? = nil, senderID: UUID, receiverID: UUID, message: String, files: [String], isRead: Bool) {
        self.id = id
        self.$sender.id = senderID
        self.$receiver.id = receiverID
        self.message = message
        self.files = files
        self.isRead = isRead
    }
}

