struct Activity: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let component: String?
    let type: String?
    let action: String?
    let content: String?
    let primaryLink: String?
    let itemId: Int?
    let secondaryItemId: Int?
    let dateRecorded: String?
    let hideSitewide: Int?
    let isSpam: Int?
    let userEmail: String?
    let userNicename: String?
    let userLogin: String?
    let displayName: String?
    let userFullname: String?
    
    enum CodingKeys: String, CodingKey {
        case id, component, type, action, content
        case userId = "user_id"
        case primaryLink = "primary_link"
        case itemId = "item_id"
        case secondaryItemId = "secondary_item_id"
        case dateRecorded = "date_recorded"
        case hideSitewide = "hide_sitewide"
        case isSpam = "is_spam"
        case userEmail = "user_email"
        case userNicename = "user_nicename"
        case userLogin = "user_login"
        case displayName = "display_name"
        case userFullname = "user_fullname"
    }
}
