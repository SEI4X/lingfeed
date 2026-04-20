import Foundation

protocol LearningContentStore: Sendable {
    func seedIfNeeded(languageCode: String, cards: [LearningCard], items: [LearningItem]) async throws
    func loadActiveCards(languageCode: String) async throws -> [LearningCard]
    func loadLearningItems(languageCode: String) async throws -> [LearningItem]
    func saveGeneratedCards(languageCode: String, cards: [LearningCard]) async throws
}

protocol UserLearningStateStore: Sendable {
    func loadState(userID: String, preferences: LearningPreferences) async throws -> UserLearningState
    func saveState(_ state: UserLearningState, userID: String) async throws
}

struct AnalyticsEvent: Sendable {
    let name: String
    let parameters: [String: SendableValue]

    nonisolated init(name: String, parameters: [String: SendableValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }

    func data(createdAt: Any) -> [String: Any] {
        [
            "name": name,
            "parameters": parameters.mapValues(\.firestoreValue),
            "createdAt": createdAt,
            "source": "ios"
        ]
    }
}

enum SendableValue: Sendable, Equatable {
    case string(String)
    case stringArray([String])
    case int(Int)
    case double(Double)
    case bool(Bool)

    var firebaseValue: Any {
        switch self {
        case .string(let value): value
        case .stringArray(let value): value.joined(separator: ",")
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        }
    }

    var firestoreValue: Any {
        switch self {
        case .stringArray(let value): value
        default: firebaseValue
        }
    }
}

protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}

struct NoopAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
}

enum LearningBackendError: Error {
    case missingUser
    case missingSession
    case missingCard
}
