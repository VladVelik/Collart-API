import Vapor

//struct CloudinaryService {
//    let cloudName: String
//    let apiKey: String
//    let apiSecret: String
//    let uploadPreset: String
//
//    init(cloudName: String, apiKey: String, apiSecret: String, uploadPreset: String) {
//        self.cloudName = cloudName
//        self.apiKey = apiKey
//        self.apiSecret = apiSecret
//        self.uploadPreset = uploadPreset
//    }
//
//    func uploadImage(req: Request, imageData: Data) async throws -> String {
//        let base64Image = imageData.base64EncodedString()
//        let url = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
//        let payload = [
//            "file": "data:image/jpeg;base64,\(base64Image)",
//            "upload_preset": uploadPreset
//        ]
//
//        let response = try await req.client.post(URI(string: url)) { req in
//            try req.content.encode(payload, as: .json)
//            req.headers.add(name: .authorization, value: "Basic \(apiKey)")
//        }
//
//        guard response.status == .ok else {
//            throw Abort(.internalServerError, reason: "Failed to upload image to Cloudinary.")
//        }
//
//        let jsonResponse = try response.content.decode(CloudinaryUploadResponse.self)
//        return jsonResponse.secureUrl
//    }
//
//}
//
//struct CloudinaryUploadResponse: Codable {
//    let secureUrl: String
//
//    enum CodingKeys: String, CodingKey {
//        case secureUrl = "secure_url"
//    }
//}
