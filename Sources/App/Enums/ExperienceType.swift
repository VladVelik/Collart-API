import Fluent
import Vapor

enum ExperienceType: String, Codable {
    case noExperience = "no_experience"
    case oneToThreeYears = "1-3_years"
    case threeToFiveYears = "3-5_years"
    case moreThanFiveYears = "more_than_5_years"
}

extension ExperienceType {
    static let name: String = "experience_type"
}
