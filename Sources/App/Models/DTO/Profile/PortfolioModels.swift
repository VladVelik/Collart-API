//
//  PortfolioModels.swift
//
//
//  Created by Vladislav Sosin on 20.04.2024.
//

import Foundation
import Vapor

// MARK: - Models for portfolio tab

struct PortfolioProjectCreateRequest: Content {
    var name: String
    var image: File
    var description: String
    var files: [File]?
}


struct PortfolioProjectUpdateRequest: Content {
    var name: String?
    var image: File?
    var description: String?
    var files: [File]?
}
