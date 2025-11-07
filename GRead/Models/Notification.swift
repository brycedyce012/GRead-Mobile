struct Notification: Codable, Identifiable {
    let id: Int
    let itemId: Int?
    let secondaryItemId: Int?
    let userId: Int?
    let componentName: String?
    let componentAction: String?
    let dateNotified: String?
    let isNew: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case secondaryItemId = "secondary_item_id"
        case userId = "user_id"
        case componentName = "component_name"
        case componentAction = "component_action"
        case dateNotified = "date_notified"
        case isNew = "is_new"
    }
}
