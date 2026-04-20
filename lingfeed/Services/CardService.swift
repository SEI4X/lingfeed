import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

protocol CardService {
    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult
    func skip(sessionID: String, cardID: String) async throws -> LearningCard?
    func deferCard(sessionID: String, cardID: String) async throws -> LearningCard?
    func markTooEasy(sessionID: String, cardID: String) async throws -> LearningCard?
    func nextCard(sessionID: String) async throws -> LearningCard?
    func recordViewed(sessionID: String, cardID: String) async throws
    func recordReturned(sessionID: String, cardID: String) async throws
}

struct MockCardService: CardService {
    let backend: MockLanguageBackend

    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult {
        try await backend.answer(sessionID: sessionID, answer: answer)
    }

    func skip(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await backend.skip(sessionID: sessionID, cardID: cardID)
    }

    func deferCard(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await backend.deferCard(sessionID: sessionID, cardID: cardID)
    }

    func markTooEasy(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await backend.markTooEasy(sessionID: sessionID, cardID: cardID)
    }

    func nextCard(sessionID: String) async throws -> LearningCard? {
        try await backend.nextCard(sessionID: sessionID)
    }

    func recordViewed(sessionID: String, cardID: String) async throws {}

    func recordReturned(sessionID: String, cardID: String) async throws {}
}

enum CloudCardInteractionResponseMapper {
    static func answerResult(from data: [String: Any]) throws -> CardAnswerResult {
        guard let isCorrect = data["isCorrect"] as? Bool else {
            throw LearningBackendError.missingCard
        }

        return CardAnswerResult(
            isCorrect: isCorrect,
            nextCard: try nextCard(from: data)
        )
    }

    static func nextCard(from data: [String: Any]) throws -> LearningCard? {
        guard let rawNextCard = data["nextCard"], !(rawNextCard is NSNull) else { return nil }
        guard var cardData = rawNextCard as? [String: Any] else {
            throw LearningBackendError.missingCard
        }
        guard let id = cardData.removeValue(forKey: "id") as? String else {
            throw FirestoreLearningMapperError.missingField("id")
        }
        return try FirestoreLearningMapper.card(id: id, data: cardData)
    }
}

#if canImport(FirebaseFunctions)
final class CloudCardInteractionService: CardService, @unchecked Sendable {
    private let functions: Functions
    private let callable: HTTPSCallable
    private let cache: CloudLearningSessionCache

    init(
        functions: Functions = Functions.functions(region: "us-central1"),
        cache: CloudLearningSessionCache = .shared
    ) {
        self.functions = functions
        self.callable = functions.httpsCallable("recordCardInteraction")
        self.cache = cache
    }

    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult {
        let data = try await record(
            sessionID: sessionID,
            cardID: answer.cardID,
            interactionType: "answer",
            response: answer.response,
            responseDuration: answer.responseDuration
        )
        return try CloudCardInteractionResponseMapper.answerResult(from: data)
    }

    func skip(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await CloudCardInteractionResponseMapper.nextCard(from: record(
            sessionID: sessionID,
            cardID: cardID,
            interactionType: "skip",
            response: "",
            responseDuration: nil
        ))
    }

    func deferCard(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await CloudCardInteractionResponseMapper.nextCard(from: record(
            sessionID: sessionID,
            cardID: cardID,
            interactionType: "defer",
            response: "",
            responseDuration: nil
        ))
    }

    func markTooEasy(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await CloudCardInteractionResponseMapper.nextCard(from: record(
            sessionID: sessionID,
            cardID: cardID,
            interactionType: "tooEasy",
            response: "",
            responseDuration: nil
        ))
    }

    func nextCard(sessionID: String) async throws -> LearningCard? {
        guard let languageCode = await cache.languageCode(for: sessionID) else {
            return nil
        }
        let result = try await call("getNextFeedCards", data: [
            "sessionId": sessionID,
            "languageCode": languageCode,
            "limit": 1
        ])
        guard let response = result.data as? [String: Any],
              let cardDictionaries = response["cards"] as? [[String: Any]] else {
            throw LearningBackendError.missingCard
        }
        return try CloudSessionResponseMapper.cards(from: cardDictionaries).first
    }

    func recordViewed(sessionID: String, cardID: String) async throws {
        _ = try await call("recordCardLifecycleEvent", data: [
            "sessionId": sessionID,
            "cardId": cardID,
            "eventType": "viewed"
        ])
    }

    func recordReturned(sessionID: String, cardID: String) async throws {
        _ = try await call("recordCardLifecycleEvent", data: [
            "sessionId": sessionID,
            "cardId": cardID,
            "eventType": "returned"
        ])
    }

    private func record(
        sessionID: String,
        cardID: String,
        interactionType: String,
        response: String,
        responseDuration: TimeInterval?
    ) async throws -> [String: Any] {
        var payload: [String: Any] = [
            "sessionId": sessionID,
            "cardId": cardID,
            "interactionType": interactionType,
            "response": response
        ]
        if let responseDuration {
            payload["responseDuration"] = responseDuration
        }

        let result = try await call(payload)
        guard let data = result.data as? [String: Any] else {
            throw LearningBackendError.missingCard
        }
        return data
    }

    private func call(_ data: [String: Any]) async throws -> HTTPSCallableResult {
        try await call("recordCardInteraction", data: data)
    }

    private func call(_ name: String, data: [String: Any]) async throws -> HTTPSCallableResult {
        try await withCheckedThrowingContinuation { continuation in
            let callable = name == "recordCardInteraction" ? self.callable : functions.httpsCallable(name)
            callable.call(data) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: LearningBackendError.missingCard)
                }
            }
        }
    }
}
#endif
