import Foundation

protocol SessionService {
    func start(languageCode: String) async throws -> SessionStart
    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary
}

struct MockSessionService: SessionService {
    let backend: MockLanguageBackend

    func start(languageCode: String) async throws -> SessionStart {
        try await backend.start(languageCode: languageCode)
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        try await backend.end(sessionID: sessionID, stats: stats)
    }
}
