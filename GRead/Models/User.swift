struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let link: String?
    let userLogin: String?
    let memberTypes: [String]?
    let registeredDate: String?
    let avatarUrls: AvatarUrls?
    
    struct AvatarUrls: Codable {
        let full: String?
        let thumb: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, link
        case userLogin = "user_login"
        case memberTypes = "member_types"
        case registeredDate = "registered_date"
        case avatarUrls = "avatar_urls"
    }
}
