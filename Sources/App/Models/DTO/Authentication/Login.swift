//
//  Login.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Model for login

struct LoginRequest: Content {
    let email: String
    let password: String
}


// TODO: - Login with providers (Google)

struct ProviderLoginRequest: Content {
    let provider: String
    let accessToken: String
}


struct GoogleUserInfo {
    let email: String
    let name: String
    let picture: String
}
