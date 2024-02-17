import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let usersRoute = routes.grouped("users")
        usersRoute.post(use: create)
        usersRoute.get(":userID", use: get)
        usersRoute.put(":userID", use: update)
        usersRoute.delete(":userID", use: delete)
        let tokenProtected = usersRoute.grouped(JWTMiddleware())
        tokenProtected.post(":userID", "photo", use: uploadPhoto)
        tokenProtected.delete("photo", ":publicId", use: deletePhoto)
    }
    
    func create(req: Request) throws -> EventLoopFuture<User> {
        let user = try req.content.decode(User.self)
        return user.save(on: req.db).map { user }
    }
    
    func get(req: Request) throws -> EventLoopFuture<User> {
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
    }
    
    func update(req: Request) throws -> EventLoopFuture<User> {
        let updatedUserData = try req.content.decode(User.self)
        return User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                user.email = updatedUserData.email
                user.name = updatedUserData.name
                user.surname = updatedUserData.surname
                user.description = updatedUserData.description
                user.userPhoto = updatedUserData.userPhoto
                user.cover = updatedUserData.cover
                user.searchable = updatedUserData.searchable
                user.experience = updatedUserData.experience
                return user.save(on: req.db).map { user }
            }
    }
    
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        User.find(req.parameters.get("userID"), on: req.db)
            .unwrap(or: Abort(.notFound)).flatMap { user in
                user.delete(on: req.db)
            }.transform(to: .noContent)
    }
    
    func uploadPhoto(req: Request) throws -> EventLoopFuture<User.Public> {
        let userID = try req.parameters.require("userID", as: UUID.self)
        
        let input = try req.content.decode(FileUpload.self)
        
        return try self.uploadImageToCloudinary(file: input.file, on: req).flatMap { imageUrl in
            return User.find(userID, on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
                user.userPhoto = imageUrl
                return user.save(on: req.db).map { user.asPublic() }
            }
        }
    }
    
    func deletePhoto(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let publicId = req.parameters.get("publicId") else {
            throw Abort(.badRequest, reason: "Missing publicId")
        }
        let userID = try req.auth.require(User.self).requireID()
        return try deleteImageFromCloudinary(publicId: publicId, on: req).flatMap { status in
            // После успешного удаления изображения, ищем пользователя и обновляем его запись
            User.find(userID, on: req.db).flatMap { user in
                guard let user = user else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound, reason: "User not found"))
                }
                // Здесь вы можете решить, удалять ли запись пользователя, или обновлять поле userPhoto
                // Например, для обновления userPhoto:
                user.userPhoto = ""
                return user.save(on: req.db).transform(to: .ok)
            }
        }
    }
    
    func uploadImageToCloudinary(file: File, on req: Request) throws -> EventLoopFuture<String> {
        let cloudName = "dwkprbrad"
        let apiKey = "571257446453121"
        let apiSecret = "tgoQJ4AKmlCihUe3t_oImnXTGDM"
        let timestamp = "\(Int(Date().timeIntervalSince1970))"
        
        let paramsToSign = [
            "timestamp": "\(timestamp)"
        ]
        
        // Генерация подписи
        let signature = try generateSignature(params: paramsToSign, apiSecret: apiSecret)
        
        // URL для загрузки
        let url = URI(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload")
        
        // Создание границы и заголовков
        let boundary = "Boundary-\(UUID().uuidString)"
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")
        
        // Создание тела запроса
        var body = ByteBufferAllocator().buffer(capacity: 0)
        appendPart(name: "file", filename: file.filename, fileData: file.data, boundary: boundary, to: &body)
        appendPart(name: "api_key", value: apiKey, boundary: boundary, to: &body)
        appendPart(name: "timestamp", value: "\(timestamp)", boundary: boundary, to: &body)
        appendPart(name: "signature", value: signature, boundary: boundary, to: &body)
        body.writeString("--\(boundary)--\r\n")
        
        // Отправка запроса
        return req.client.post(url, headers: headers) { req in
            req.body = .init(buffer: body)
        }.flatMapThrowing { res in
            guard let body = res.body else {
                throw Abort(.internalServerError, reason: "Invalid response from Cloudinary")
            }
            let data = Data(buffer: body)
            //                // Попытка преобразования Data в String для логирования
            if let bodyString = String(data: data, encoding: .utf8) {
                print("Cloudinary response: \(bodyString)")
            }
            let cloudinaryResponse = try JSONDecoder().decode(CloudinaryUploadResponse.self, from: body)
            return cloudinaryResponse.url
        }
    }
    
    func deleteImageFromCloudinary(publicId: String, on req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let cloudName = "dwkprbrad"
        let apiKey = "571257446453121"
        let apiSecret = "tgoQJ4AKmlCihUe3t_oImnXTGDM"
        
        let url = URI(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/destroy")
        
        let paramsToSign = [
            "public_id": publicId,
            "timestamp": "\(Int(Date().timeIntervalSince1970))"
        ]
        
        let signature = try generateSignature(params: paramsToSign, apiSecret: apiSecret)
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/x-www-form-urlencoded")
        
        let body: [String: String] = [
            "public_id": publicId,
            "timestamp": paramsToSign["timestamp"]!,
            "api_key": apiKey,
            "signature": signature
        ]
        
        let bodyString = body.map { "\($0)=\($1)" }.joined(separator: "&")
        
        return req.client.post(url, headers: headers) { req in
            req.body = .init(string: bodyString)
        }.flatMapThrowing { res in
            guard res.status == .ok else {
                throw Abort(.internalServerError, reason: "Failed to delete image from Cloudinary")
            }
            return res.status
        }
    }
    
    func appendPart(name: String, filename: String? = nil, fileData: ByteBuffer, boundary: String, to body: inout ByteBuffer) {
        let disposition = filename != nil ? "form-data; name=\"\(name)\"; filename=\"\(filename!)\"" : "form-data; name=\"\(name)\""
        let partHeader = "--\(boundary)\r\nContent-Disposition: \(disposition)\r\n\r\n"
        body.writeString(partHeader)
        var fileData = fileData // Создаем копию, так как writeBuffer принимает inout параметр
        body.writeBuffer(&fileData)
        body.writeString("\r\n")
    }
    
    func appendPart(name: String, value: String, boundary: String, to body: inout ByteBuffer) {
        let partHeader = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        body.writeString(partHeader)
        body.writeString(value)
        body.writeString("\r\n")
    }
    
    // Функция для генерации подписи
    func generateSignature(params: [String: String], apiSecret: String) throws -> String {
        let sortedParams = params.sorted { $0.0 < $1.0 }
        let paramString = sortedParams.map { "\($0)=\($1)" }.joined(separator: "&")
        let signString = paramString + apiSecret
        
        guard let data = signString.data(using: .utf8) else {
            throw  Abort(.badRequest, reason: "Invalid response from Cloudinar")// Замените SomeError на фактическую ошибку, которую вы хотите использовать
        }
        
        let digest = SHA256.hash(data: data)
        let signature = digest.compactMap { String(format: "%02x", $0) }.joined()
        
        return signature
    }
    
}

struct FileUpload: Codable {
    var file: File
}

struct CloudinaryUploadResponse: Codable {
    let url: String
}
