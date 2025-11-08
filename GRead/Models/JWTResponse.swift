//
//  JWTResponse.swift
//  GRead
//
//  Created by apple on 11/6/25.
//


struct JWTResponse: Codable {
    let token: String
    let userNicename: String?
    let userDisplayName: String?

    enum CodingKeys: String, CodingKey {
        case token
        case userNicename = "user_nicename"
        case userDisplayName = "user_display_name"
    }
}

struct JWTErrorResponse: Codable {
    let code: String?
    let message: String?
    let data: ErrorData?
    
    struct ErrorData: Codable {
        let status: Int?
    }
}