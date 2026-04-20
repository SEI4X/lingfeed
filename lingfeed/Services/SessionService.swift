import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

protocol SessionService {
    func start(languageCode: String, nativeLanguageCode: String, learningGoals: [LearningGoal]) async throws -> SessionStart
    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary
}

struct MockSessionService: SessionService {
    let backend: MockLanguageBackend

    func start(languageCode: String, nativeLanguageCode: String, learningGoals: [LearningGoal]) async throws -> SessionStart {
        try await backend.start(languageCode: languageCode, nativeLanguageCode: nativeLanguageCode, learningGoals: learningGoals)
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        try await backend.end(sessionID: sessionID, stats: stats)
    }
}

actor CloudLearningSessionCache {
    static let shared = CloudLearningSessionCache()

    private var languageCodeBySessionID: [String: String] = [:]

    func remember(languageCode: String, for sessionID: String) {
        languageCodeBySessionID[sessionID] = languageCode
    }

    func languageCode(for sessionID: String) -> String? {
        languageCodeBySessionID[sessionID]
    }
}

enum CloudSessionResponseMapper {
    static func sessionStart(from data: [String: Any]) throws -> SessionStart {
        guard let sessionID = data["sessionID"] as? String,
              let cardDictionaries = data["cards"] as? [[String: Any]] else {
            throw LearningBackendError.missingSession
        }

        return SessionStart(
            sessionID: sessionID,
            cards: try cards(from: cardDictionaries),
            profile: profile(from: data["profile"] as? [String: Any] ?? [:])
        )
    }

    static func sessionSummary(from data: [String: Any]) throws -> SessionSummary {
        guard let statsData = data["stats"] as? [String: Any] else {
            throw LearningBackendError.missingSession
        }

        return SessionSummary(
            stats: sessionStats(from: statsData),
            profile: profile(from: data["profile"] as? [String: Any] ?? [:])
        )
    }

    static func cards(from dictionaries: [[String: Any]]) throws -> [LearningCard] {
        try dictionaries.map { dictionary in
            var data = dictionary
            guard let id = data.removeValue(forKey: "id") as? String else {
                throw FirestoreLearningMapperError.missingField("id")
            }
            return try FirestoreLearningMapper.card(id: id, data: data)
        }
    }

    private static func profile(from data: [String: Any]) -> UserProfile {
        UserProfile(
            streak: int("streak", in: data),
            totalLearned: int("totalLearned", in: data),
            weakTopics: data["weakTopics"] as? [String] ?? []
        )
    }

    private static func sessionStats(from data: [String: Any]) -> SessionStats {
        SessionStats(
            answered: int("answered", in: data),
            correct: int("correct", in: data),
            skipped: int("skipped", in: data)
        )
    }

    private static func int(_ key: String, in data: [String: Any]) -> Int {
        if let value = data[key] as? Int { return value }
        if let value = data[key] as? NSNumber { return value.intValue }
        return 0
    }
}

#if canImport(FirebaseFunctions)
final class CloudSessionService: SessionService, @unchecked Sendable {
    private let functions: Functions
    private let cache: CloudLearningSessionCache

    init(
        functions: Functions = Functions.functions(region: "us-central1"),
        cache: CloudLearningSessionCache = .shared
    ) {
        self.functions = functions
        self.cache = cache
    }

    func start(languageCode: String, nativeLanguageCode: String, learningGoals: [LearningGoal]) async throws -> SessionStart {
        let result = try await call("startLearningSession", data: [
            "languageCode": languageCode,
            "nativeLanguageCode": nativeLanguageCode,
            "goals": LearningGoal.rawValues(from: learningGoals),
            "interests": LearningGoal.defaultInterests(for: learningGoals),
            "limit": 5
        ])
        guard let response = result.data as? [String: Any] else {
            throw LearningBackendError.missingSession
        }

        let start = try CloudSessionResponseMapper.sessionStart(from: response)
        await cache.remember(languageCode: languageCode, for: start.sessionID)
        return start
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        let result = try await call("endLearningSession", data: [
            "sessionId": sessionID
        ])
        guard let response = result.data as? [String: Any] else {
            throw LearningBackendError.missingSession
        }

        return try CloudSessionResponseMapper.sessionSummary(from: response)
    }

    private func call(_ name: String, data: [String: Any]) async throws -> HTTPSCallableResult {
        try await withCheckedThrowingContinuation { continuation in
            functions.httpsCallable(name).call(data) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: LearningBackendError.missingSession)
                }
            }
        }
    }
}
#endif
