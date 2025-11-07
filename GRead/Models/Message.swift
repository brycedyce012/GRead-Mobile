struct Message: Codable, Identifiable {
    let id: Int
    let subject: MessageSubject?
    let message: MessageContent?
    let dateSent: String?
    let unreadCount: Int?
    let senderIds: [Int]?
    let recipients: [Recipient]?
    
    struct MessageSubject: Codable {
        let rendered: String?
        let raw: String?
    }
    
    struct MessageContent: Codable {
        let rendered: String?
        let raw: String?
    }
    
    struct Recipient: Codable {
        let userId: Int?
        let userName: String?
        let isDeleted: Bool?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case userName = "user_name"
            case isDeleted = "is_deleted"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, subject, message, recipients
        case dateSent = "date_sent"
        case unreadCount = "unread_count"
        case senderIds = "sender_ids"
    }
}
