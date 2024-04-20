import Vapor

// MARK: - Others models

struct UpdatePhotoData: Content {
    let photoURL: String
}


struct FileUpload: Codable {
    var file: File
}


struct CloudinaryUploadResponse: Codable {
    let url: String
}


struct UserToolData: Content {
    let userID: UUID
    let toolID: UUID
}


struct SkillNames: Content {
    var nameEn: String
    var primary: Bool
    var nameRu: String
}
