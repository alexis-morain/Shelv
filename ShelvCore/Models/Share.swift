import Foundation

nonisolated struct Share: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let url: String
    let description: String?
    let username: String?
    let created: Date?
    let expires: Date?

    enum CodingKeys: String, CodingKey {
        case id, url, description, username, created, expires
    }
}

extension Share {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        url = try c.decode(String.self, forKey: .url)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        created = FlexibleDate.decode(c, .created)
        expires = FlexibleDate.decode(c, .expires)
    }
}
