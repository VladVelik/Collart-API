import Fluent
import Vapor

enum Status: String, Codable {
    case rejected
    case active
    case accepted
}

extension Status {
    static let name: String = "status"
}
