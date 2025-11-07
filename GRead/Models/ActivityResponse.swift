//
//  ActivityResponse.swift
//  GRead
//
//  Created by apple on 11/7/25.
//


struct ActivityResponse: Codable {
    let activities: [Activity]
    let total: Int?
    let hasMoreItems: Bool?
    
    enum CodingKeys: String, CodingKey {
        case activities, total
        case hasMoreItems = "has_more_items"
    }
}