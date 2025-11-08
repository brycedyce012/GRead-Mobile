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

    // Custom decoder to handle id being returned as string from API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle id as either Int or String
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = idInt
        } else if let idString = try? container.decode(String.self, forKey: .id),
                  let idInt = Int(idString) {
            id = idInt
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Could not decode id as Int or String")
        }

        name = try container.decode(String.self, forKey: .name)
        link = try? container.decode(String.self, forKey: .link)
        userLogin = try? container.decode(String.self, forKey: .userLogin)
        memberTypes = try? container.decode([String].self, forKey: .memberTypes)
        registeredDate = try? container.decode(String.self, forKey: .registeredDate)
        avatarUrls = try? container.decode(AvatarUrls.self, forKey: .avatarUrls)
    }
}
