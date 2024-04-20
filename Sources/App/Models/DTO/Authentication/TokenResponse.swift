//
//  TokenResponse.swift
//  
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Response in case success login

struct TokenResponse: Content {
    let token: String
}
