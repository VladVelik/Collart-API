import Fluent
import Vapor

enum TabType: String, Codable {
    case portfolio = "portfolio"
    case active = "active"
    case collaborations = "collaborations"
    case favorite = "favorite"
}

extension TabType {
    static let name: String = "tab_type"
}
