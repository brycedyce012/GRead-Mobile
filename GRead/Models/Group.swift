struct BPGroup: Codable, Identifiable {
    let id: Int
    let creatorId: Int?
    let name: String
    let link: String?
    let description: GroupDescription?
    let slug: String?
    let status: String?
    let dateCreated: String?
    let totalMemberCount: Int?
    let avatarUrls: AvatarUrls?
    
    struct GroupDescription: Codable {
        let rendered: String?
        let raw: String?
    }
    
    struct AvatarUrls: Codable {
        let full: String?
        let thumb: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, link, description, slug, status
        case creatorId = "creator_id"
        case dateCreated = "date_created"
        case totalMemberCount = "total_member_count"
        case avatarUrls = "avatar_urls"
    }
}
