import Foundation

struct UserProfile: Codable {
    var name: String
    var language: String
    var tone: String
}

struct LongTermMemory: Codable {
    var userProfile: UserProfile
    var facts: [String]
    var preferences: [String]

    enum CodingKeys: String, CodingKey {
        case userProfile = "user_profile"
        case facts, preferences
    }

    static let `default` = LongTermMemory(
        userProfile: UserProfile(name: "Daniel", language: "english", tone: "direct, practical"),
        facts: [],
        preferences: []
    )
}
