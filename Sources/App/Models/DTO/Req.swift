import Vapor

struct CreateUserRequest: Content {
    let email: String
    let passwordHash: String
    let confirmPasswordHash: String
    let name: String
    let surname: String
    let description: String
    let userPhoto: String
    let cover: String
    let searchable: Bool
    let experience: ExperienceType
}

struct LoginRequest: Content {
    let email: String
    let password: String
}

struct TokenResponse: Content {
    let token: String
}

struct ProviderLoginRequest: Content {
    let provider: String
    let accessToken: String
}

struct GoogleUserInfo {
    let email: String
    let name: String
    let picture: String
}
