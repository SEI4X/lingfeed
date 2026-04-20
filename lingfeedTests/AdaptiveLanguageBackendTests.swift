import XCTest
@testable import lingfeed

final class AdaptiveLanguageBackendTests: XCTestCase {
    func testStartComposesCardsFromStoredUserState() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let review = Self.card(id: "review", targetItemIDs: ["phrase"])
        let fresh = Self.card(id: "fresh", targetItemIDs: ["new"], prompt: "coffee", correctAnswer: "cafe")
        let stores = TestLearningStores(
            cards: [fresh, review],
            items: [
                LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar"),
                LearningItem(id: "new", kind: .lexeme, languageCode: "es", value: "cafe")
            ],
            state: UserLearningState(
                itemStates: [
                    "phrase": SRSItemState(
                        itemID: "phrase",
                        kind: .phrase,
                        strength: 0.2,
                        difficulty: 0.5,
                        repetitions: 1,
                        lapses: 0,
                        lastReviewedAt: now.addingTimeInterval(-3_600),
                        nextReviewAt: now.addingTimeInterval(-60)
                    )
                ],
                preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
            )
        )
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            now: { now }
        )

        let start = try await backend.start(languageCode: "es", nativeLanguageCode: "ru")

        XCTAssertEqual(start.cards.map(\.id), ["review", "fresh"])
        let requestedPreferences = await stores.lastLoadStatePreferences
        XCTAssertEqual(requestedPreferences?.targetLanguageCode, "es")
        XCTAssertEqual(requestedPreferences?.nativeLanguageCode, "ru")
    }

    func testAnswerUpdatesSRSStateAndPersistsEvent() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(
                preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
            )
        )
        let analytics = TestAnalyticsService()
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: analytics,
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        let result = try await backend.answer(
            sessionID: start.sessionID,
            answer: CardAnswer(cardID: "card", response: "para llevar")
        )

        let savedState = try await stores.loadState(
            userID: "user-1",
            preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
        )
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(savedState.answeredCardIDs, ["card"])
        XCTAssertEqual(savedState.itemStates["phrase"]?.repetitions, 1)
        XCTAssertEqual(savedState.itemStates["phrase"]?.nextReviewAt, now.addingTimeInterval(3 * 24 * 60 * 60))
        let answeredEvent = analytics.recordedEvents.first { $0.name == "card_answered" }
        XCTAssertEqual(answeredEvent?.parameters["language"], .string("es"))
        XCTAssertEqual(answeredEvent?.parameters["session_id"], .string(start.sessionID))
        XCTAssertEqual(answeredEvent?.parameters["target_item_ids"], .stringArray(["phrase"]))
        XCTAssertEqual(answeredEvent?.parameters["target_item_count"], .int(1))
    }

    func testFastCorrectAnswerSchedulesReviewAsEasy() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        )
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        _ = try await backend.answer(
            sessionID: start.sessionID,
            answer: CardAnswer(cardID: "card", response: "para llevar", responseDuration: 3)
        )

        let savedState = try await stores.loadState(userID: "user-1", preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        XCTAssertEqual(savedState.itemStates["phrase"]?.nextReviewAt, now.addingTimeInterval(7 * 24 * 60 * 60))
        XCTAssertEqual(savedState.itemStates["phrase"]?.repetitions, 1)
    }

    func testSlowCorrectAnswerSchedulesReviewAsHard() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        )
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        _ = try await backend.answer(
            sessionID: start.sessionID,
            answer: CardAnswer(cardID: "card", response: "para llevar", responseDuration: 30)
        )

        let savedState = try await stores.loadState(userID: "user-1", preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        XCTAssertEqual(savedState.itemStates["phrase"]?.nextReviewAt, now.addingTimeInterval(24 * 60 * 60))
        XCTAssertEqual(savedState.itemStates["phrase"]?.repetitions, 1)
    }

    func testSkipBringsTargetItemsBackSoon() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        )
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        _ = try await backend.skip(sessionID: start.sessionID, cardID: "card")

        let savedState = try await stores.loadState(userID: "user-1", preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        XCTAssertEqual(savedState.itemStates["phrase"]?.lapses, 1)
        XCTAssertEqual(savedState.itemStates["phrase"]?.nextReviewAt, now.addingTimeInterval(10 * 60))
    }

    func testDeferMarksSeenWithoutReviewingTargetItems() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        )
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        _ = try await backend.deferCard(sessionID: start.sessionID, cardID: "card")

        let savedState = try await stores.loadState(userID: "user-1", preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en"))
        XCTAssertEqual(savedState.seenCardIDs, ["card"])
        XCTAssertTrue(savedState.answeredCardIDs.isEmpty)
        XCTAssertNil(savedState.itemStates["phrase"])
    }

    func testTooEasyMarksCardWithoutCountingAsAnswered() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(
                preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
            )
        )
        let analytics = TestAnalyticsService()
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: analytics,
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        _ = try await backend.markTooEasy(sessionID: start.sessionID, cardID: "card")

        let savedState = try await stores.loadState(
            userID: "user-1",
            preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
        )
        XCTAssertEqual(savedState.tooEasyCardIDs, ["card"])
        XCTAssertTrue(savedState.answeredCardIDs.isEmpty)
        XCTAssertEqual(savedState.itemStates["phrase"]?.nextReviewAt, now.addingTimeInterval(7 * 24 * 60 * 60))
        XCTAssertTrue(analytics.eventNames.contains("card_too_easy"))
    }

    func testExhaustedFeedGeneratesAndPersistsMoreCards() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [
                LearningItem(
                    id: "phrase",
                    kind: .phrase,
                    languageCode: "es",
                    value: "para llevar",
                    translation: "to go",
                    tags: ["coffee"]
                )
            ],
            state: UserLearningState(
                preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
            )
        )
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        let result = try await backend.answer(
            sessionID: start.sessionID,
            answer: CardAnswer(cardID: "card", response: "para llevar")
        )

        let generated = await stores.generatedCards
        XCTAssertNotNil(result.nextCard)
        XCTAssertEqual(generated.first?.targetItemIDs, ["phrase"])
        XCTAssertTrue(generated.allSatisfy { $0.id.hasPrefix("gen-es-phrase-") })
    }

    func testExhaustedFeedUsesInjectedGenerationService() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let card = Self.card(id: "card", targetItemIDs: ["phrase"])
        let generatedCard = Self.card(id: "remote-card", targetItemIDs: ["phrase"])
        let stores = TestLearningStores(
            cards: [card],
            items: [LearningItem(id: "phrase", kind: .phrase, languageCode: "es", value: "para llevar")],
            state: UserLearningState(
                preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
            )
        )
        let generationService = TestExerciseGenerationService(cards: [generatedCard])
        let backend = AdaptiveLanguageBackend(
            userIDProvider: { "user-1" },
            contentStore: stores,
            learningStateStore: stores,
            analytics: TestAnalyticsService(),
            generationService: generationService,
            now: { now }
        )

        let start = try await backend.start(languageCode: "es")
        let result = try await backend.answer(
            sessionID: start.sessionID,
            answer: CardAnswer(cardID: "card", response: "para llevar")
        )

        let requestedLanguageCode = await generationService.requestedLanguageCode
        let locallyGeneratedCards = await stores.generatedCards
        XCTAssertEqual(result.nextCard?.id, "remote-card")
        XCTAssertEqual(requestedLanguageCode, "es")
        XCTAssertEqual(locallyGeneratedCards, [])
    }

    func testAnalyticsEventBuildsFirestoreData() {
        let event = AnalyticsEvent(name: "card_answered", parameters: [
            "session_id": .string("session-1"),
            "target_item_ids": .stringArray(["phrase", "lexeme"]),
            "is_correct": .bool(true),
            "target_item_count": .int(2),
            "score": .double(0.75)
        ])

        let data = event.data(createdAt: "SERVER_TIME")
        let parameters = data["parameters"] as? [String: Any]

        XCTAssertEqual(data["name"] as? String, "card_answered")
        XCTAssertEqual(data["source"] as? String, "ios")
        XCTAssertEqual(data["createdAt"] as? String, "SERVER_TIME")
        XCTAssertEqual(parameters?["session_id"] as? String, "session-1")
        XCTAssertEqual(parameters?["target_item_ids"] as? [String], ["phrase", "lexeme"])
        XCTAssertEqual(parameters?["is_correct"] as? Bool, true)
        XCTAssertEqual(parameters?["target_item_count"] as? Int, 2)
        XCTAssertEqual(parameters?["score"] as? Double, 0.75)
    }

    private static func card(
        id: String,
        targetItemIDs: [String],
        prompt: String = "coffee to go",
        correctAnswer: String = "para llevar"
    ) -> LearningCard {
        LearningCard(
            id: id,
            type: .translate,
            context: "A1 / coffee",
            situation: "You are ordering coffee.",
            prompt: prompt,
            correctAnswer: correctAnswer,
            explanation: "Para llevar means to go.",
            targetItemIDs: targetItemIDs,
            skillTags: ["coffee"],
            difficulty: 1,
            missionID: "coffee"
        )
    }
}

private actor TestLearningStores: LearningContentStore, UserLearningStateStore {
    var cards: [LearningCard]
    let items: [LearningItem]
    var state: UserLearningState
    private(set) var generatedCards: [LearningCard] = []
    private(set) var lastLoadStatePreferences: LearningPreferences?

    init(cards: [LearningCard], items: [LearningItem], state: UserLearningState) {
        self.cards = cards
        self.items = items
        self.state = state
    }

    func seedIfNeeded(languageCode: String, cards: [LearningCard], items: [LearningItem]) async throws {}

    func loadActiveCards(languageCode: String) async throws -> [LearningCard] {
        cards
    }

    func loadLearningItems(languageCode: String) async throws -> [LearningItem] {
        items
    }

    func saveGeneratedCards(languageCode: String, cards: [LearningCard]) async throws {
        generatedCards.append(contentsOf: cards)
        self.cards.append(contentsOf: cards)
    }

    func loadState(userID: String, preferences: LearningPreferences) async throws -> UserLearningState {
        lastLoadStatePreferences = preferences
        return state
    }

    func saveState(_ state: UserLearningState, userID: String) async throws {
        self.state = state
    }
}

private final class TestAnalyticsService: AnalyticsService, @unchecked Sendable {
    private(set) var recordedEvents: [AnalyticsEvent] = []

    var eventNames: [String] {
        recordedEvents.map(\.name)
    }

    func track(_ event: AnalyticsEvent) {
        recordedEvents.append(event)
    }
}

private actor TestExerciseGenerationService: ExerciseGenerationService {
    private let cards: [LearningCard]
    private(set) var requestedLanguageCode: String?

    init(cards: [LearningCard]) {
        self.cards = cards
    }

    func generateCards(
        languageCode: String,
        userID: String,
        userState: UserLearningState,
        items: [LearningItem],
        existingCardIDs: Set<String>,
        limit: Int
    ) async throws -> ExerciseGenerationResult {
        requestedLanguageCode = languageCode
        return ExerciseGenerationResult(cards: cards, isPersisted: true)
    }
}
