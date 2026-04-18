import Foundation

protocol CardService {
    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult
    func skip(sessionID: String, cardID: String) async throws -> LearningCard?
    func nextCard(sessionID: String) async throws -> LearningCard?
}

struct MockCardService: CardService {
    let backend: MockLanguageBackend

    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult {
        try await backend.answer(sessionID: sessionID, answer: answer)
    }

    func skip(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await backend.skip(sessionID: sessionID, cardID: cardID)
    }

    func nextCard(sessionID: String) async throws -> LearningCard? {
        try await backend.nextCard(sessionID: sessionID)
    }
}
