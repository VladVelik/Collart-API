// CloudinaryService.swift

import Vapor
import CryptoKit
import Foundation

struct CloudinaryService {
    let cloudName: String
    let apiKey: String
    let apiSecret: String

    func upload(file: File, on req: Request) throws -> EventLoopFuture<String> {
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
                            // Попытка преобразования Data в String для логирования
            if let bodyString = String(data: data, encoding: .utf8) {
                print("Cloudinary response: \(bodyString)")
            }
            let cloudinaryResponse = try JSONDecoder().decode(CloudinaryUploadResponse.self, from: body)
            return cloudinaryResponse.url
        }
    }
    
    func delete(publicId: String, on req: Request) throws -> EventLoopFuture<Void> {
        let url = URI(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/destroy")
        let timestamp = "\(Int(Date().timeIntervalSince1970))"
        let signature = try generateSignature(params: ["timestamp": timestamp, "public_id": publicId], apiSecret: apiSecret)
        
        let body: [String: String] = [
            "public_id": publicId,
            "timestamp": timestamp,
            "api_key": apiKey,
            "signature": signature
        ]
        
        let bodyString = body.map { "\($0)=\($1)" }.joined(separator: "&")
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/x-www-form-urlencoded")
        
        return req.client.post(url, headers: headers) { req in
            req.body = .init(string: bodyString)
        }.flatMapThrowing { res in
            guard res.status == .ok else {
                throw Abort(.internalServerError, reason: "Failed to delete image from Cloudinary")
            }
        }
    }

    private func appendPart(name: String, filename: String? = nil, fileData: ByteBuffer, boundary: String, to body: inout ByteBuffer) {
        let disposition = filename != nil ? "form-data; name=\"\(name)\"; filename=\"\(filename!)\"" : "form-data; name=\"\(name)\""
        let partHeader = "--\(boundary)\r\nContent-Disposition: \(disposition)\r\n\r\n"
        body.writeString(partHeader)
        var fileData = fileData // Создаем копию, так как writeBuffer принимает inout параметр
        body.writeBuffer(&fileData)
        body.writeString("\r\n")
    }
    
    private func appendPart(name: String, value: String, boundary: String, to body: inout ByteBuffer) {
        let partHeader = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        body.writeString(partHeader)
        body.writeString(value)
        body.writeString("\r\n")
    }
    
    // Функция для генерации подписи
    private func generateSignature(params: [String: String], apiSecret: String) throws -> String {
        let sortedParams = params.sorted { $0.0 < $1.0 }
        let paramString = sortedParams.map { "\($0)=\($1)" }.joined(separator: "&")
        let signString = paramString + apiSecret
        
        guard let data = signString.data(using: .utf8) else {
            throw  Abort(.badRequest, reason: "Invalid response from Cloudinary")
        }
        
        let digest = SHA256.hash(data: data)
        let signature = digest.compactMap { String(format: "%02x", $0) }.joined()
        
        return signature
    }
}
