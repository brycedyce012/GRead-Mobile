import Foundation

struct UserStats: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let displayName: String
    let avatarUrl: String
    let points: Int
    let booksCompleted: Int
    let pagesRead: Int
    let booksAdded: Int
    let approvedReports: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case points = "points"
        case booksCompleted = "books_completed"
        case pagesRead = "pages_read"
        case booksAdded = "books_added"
        case approvedReports = "approved_reports"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // userId is optional now (API no longer returns it)
        userId = try? container.decode(Int.self, forKey: .userId)

        // For the Identifiable id, use userId if available, otherwise create a hash from displayName
        displayName = try container.decode(String.self, forKey: .displayName)
        if let userId = userId {
            id = userId
        } else {
            // Create a deterministic ID from the displayName hash
            id = displayName.hashValue
        }

        avatarUrl = try container.decode(String.self, forKey: .avatarUrl)
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
        booksCompleted = try container.decodeIfPresent(Int.self, forKey: .booksCompleted) ?? 0
        pagesRead = try container.decodeIfPresent(Int.self, forKey: .pagesRead) ?? 0
        booksAdded = try container.decodeIfPresent(Int.self, forKey: .booksAdded) ?? 0
        approvedReports = try container.decodeIfPresent(Int.self, forKey: .approvedReports) ?? 0
    }
}
