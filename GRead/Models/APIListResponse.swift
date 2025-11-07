//
//  APIListResponse.swift
//  GRead
//
//  Created by apple on 11/6/25.
//


struct APIListResponse<T: Codable>: Codable {
    let items: [T]?
    let total: Int?
    let totalPages: Int?
    
    enum CodingKeys: String, CodingKey {
        case items
        case total
        case totalPages = "total_pages"
    }
}