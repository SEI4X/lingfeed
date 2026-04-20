import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

struct ExerciseGenerationResult: Sendable {
    let cards: [LearningCard]
    let isPersisted: Bool
}

protocol ExerciseGenerationService: Sendable {
    func generateCards(
        languageCode: String,
        userID: String,
        userState: UserLearningState,
        items: [LearningItem],
        existingCardIDs: Set<String>,
        limit: Int
    ) async throws -> ExerciseGenerationResult
}

struct LocalExerciseGenerationService: ExerciseGenerationService {
    let generator: ExerciseGenerator

    init(generator: ExerciseGenerator = RuleBasedExerciseGenerator()) {
        self.generator = generator
    }

    func generateCards(
        languageCode: String,
        userID: String,
        userState: UserLearningState,
        items: [LearningItem],
        existingCardIDs: Set<String>,
        limit: Int
    ) async throws -> ExerciseGenerationResult {
        ExerciseGenerationResult(
            cards: generator.generateCards(
                languageCode: languageCode,
                items: items,
                userState: userState,
                existingCardIDs: existingCardIDs,
                limit: limit
            ),
            isPersisted: false
        )
    }
}

struct RemoteFirstExerciseGenerationService: ExerciseGenerationService {
    let remote: ExerciseGenerationService
    let fallback: ExerciseGenerationService

    func generateCards(
        languageCode: String,
        userID: String,
        userState: UserLearningState,
        items: [LearningItem],
        existingCardIDs: Set<String>,
        limit: Int
    ) async throws -> ExerciseGenerationResult {
        do {
            return try await remote.generateCards(
                languageCode: languageCode,
                userID: userID,
                userState: userState,
                items: items,
                existingCardIDs: existingCardIDs,
                limit: limit
            )
        } catch {
            let fallbackResult = try await fallback.generateCards(
                languageCode: languageCode,
                userID: userID,
                userState: userState,
                items: items,
                existingCardIDs: existingCardIDs,
                limit: limit
            )
            return ExerciseGenerationResult(cards: fallbackResult.cards, isPersisted: true)
        }
    }
}

#if canImport(FirebaseFunctions)
final class CloudExerciseGenerationService: ExerciseGenerationService, @unchecked Sendable {
    private let callable: HTTPSCallable

    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.callable = functions.httpsCallable("generateExercises")
    }

    func generateCards(
        languageCode: String,
        userID: String,
        userState: UserLearningState,
        items: [LearningItem],
        existingCardIDs: Set<String>,
        limit: Int
    ) async throws -> ExerciseGenerationResult {
        let result = try await call([
            "languageCode": languageCode,
            "existingCardIDs": Array(existingCardIDs),
            "limit": limit
        ])

        guard let response = result.data as? [String: Any],
              let cardDictionaries = response["cards"] as? [[String: Any]] else {
            throw LearningBackendError.missingCard
        }

        let cards = try cardDictionaries.map { data in
            guard let id = data["id"] as? String else { throw FirestoreLearningMapperError.missingField("id") }
            return try FirestoreLearningMapper.card(id: id, data: data)
        }

        return ExerciseGenerationResult(cards: cards, isPersisted: true)
    }

    private func call(_ data: [String: Any]) async throws -> HTTPSCallableResult {
        try await withCheckedThrowingContinuation { continuation in
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
