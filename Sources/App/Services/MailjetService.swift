//
//  MailjetService.swift
//
//
//  Created by Vladislav Sosin on 05.05.2024.
//

import Foundation
import Vapor

extension String {
    func base64Encoded() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

struct MailjetService {
    let app: Application

    func sendEmail(to recipient: String, subject: String, text: String) -> EventLoopFuture<Void> {
        let url = URI(string: "https://api.mailjet.com/v3.1/send")
        let apiKey = "api-key"
        let apiSecret = "api-secret"
        
        let credentials = "\(apiKey):\(apiSecret)".base64Encoded()
        let authorizationHeader = "Basic \(credentials)"

        let headers = HTTPHeaders([
            ("Authorization", authorizationHeader),
            ("Content-Type", "application/json")
        ])

        let body: [String: Any] = [
            "Messages": [
                [
                    "From": [
                        "Email": "support@collart.com",
                        "Name": "Collart verification"
                    ],
                    "To": [
                        [
                            "Email": recipient
                        ]
                    ],
                    "Subject": subject,
                    "TextPart": text
                ]
            ]
        ]

        let requestBody = try? JSONSerialization.data(withJSONObject: body)
        
        return app.client.post(url, headers: headers) { req in
            req.body = .init(data: requestBody ?? Data())
        }
        .transform(to: ())
    }
}
