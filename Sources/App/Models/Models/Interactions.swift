import Fluent
import Vapor

final class Interaction: Model, Content {
    static let schema = "interactions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "sender_id")
    var sender: User

    @Parent(key: "order_id")
    var order: Order

    @Parent(key: "getter_id")
    var getter: User

    @Enum(key: "status")
    var status: Status

    init() {}

    init(id: UUID? = nil, senderID: UUID, orderID: UUID, getterID: UUID, status: Status) {
        self.id = id
        self.$sender.id = senderID
        self.$order.id = orderID
        self.$getter.id = getterID
        self.status = status
    }
}
