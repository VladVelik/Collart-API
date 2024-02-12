import Fluent
import Vapor

final class OrderParticipant: Model {
    static let schema = "order_participants"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "order_id")
    var order: Order

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: UUID? = nil, orderID: UUID, userID: UUID) {
        self.id = id
        self.$order.id = orderID
        self.$user.id = userID
    }
}
