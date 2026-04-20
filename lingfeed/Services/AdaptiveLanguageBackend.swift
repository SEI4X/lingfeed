import Foundation

actor AdaptiveLanguageBackend {
    private let userIDProvider: @Sendable () -> String?
    private let contentStore: LearningContentStore
    private let learningStateStore: UserLearningStateStore
    private let analytics: AnalyticsService
    private let composer: FeedComposer
    private let generationService: ExerciseGenerationService
    private let now: @Sendable () -> Date

    private var sessionID = ""
    private var languageCode = ""
    private var userID = ""
    private var cards: [LearningCard] = []
    private var candidateCards: [LearningCard] = []
    private var itemsByID: [String: LearningItem] = [:]
    private var userState: UserLearningState?

    nonisolated init(
        userIDProvider: @escaping @Sendable () -> String?,
        contentStore: LearningContentStore,
        learningStateStore: UserLearningStateStore,
        analytics: AnalyticsService,
        composer: FeedComposer = FeedComposer(scorer: CardScorer()),
        generationService: ExerciseGenerationService = LocalExerciseGenerationService(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.userIDProvider = userIDProvider
        self.contentStore = contentStore
        self.learningStateStore = learningStateStore
        self.analytics = analytics
        self.composer = composer
        self.generationService = generationService
        self.now = now
    }

    func start(
        languageCode: String,
        nativeLanguageCode: String = LanguageOption.fallbackNativeCode,
        learningGoals: [LearningGoal] = LearningGoal.defaultGoals
    ) async throws -> SessionStart {
        guard let userID = userIDProvider() else { throw LearningBackendError.missingUser }
        LearningDiagnostics.info("Backend start for language \(languageCode), user \(userID)")
        self.userID = userID
        self.languageCode = languageCode
        sessionID = "session-\(languageCode)-\(UUID().uuidString.prefix(8))"

        let seed = SeedLearningContent.content(languageCode: languageCode)
        LearningDiagnostics.info("Backend seeding skipped/readied \(seed.cards.count) seed cards")
        try await contentStore.seedIfNeeded(languageCode: languageCode, cards: seed.cards, items: seed.items)

        let loadedItems = try await contentStore.loadLearningItems(languageCode: languageCode)
        LearningDiagnostics.info("Backend loaded \(loadedItems.count) learning items")
        let activeItems = loadedItems.isEmpty ? seed.items : loadedItems
        itemsByID = Dictionary(uniqueKeysWithValues: activeItems.map { ($0.id, $0) })

        let loadedCards = try await contentStore.loadActiveCards(languageCode: languageCode)
        let validLoadedCards = loadedCards.filter { LearningCardQuality.isValid($0, itemsByID: itemsByID) }
        LearningDiagnostics.info("Backend loaded \(loadedCards.count) active cards, accepted \(validLoadedCards.count)")
        candidateCards = loadedCards.isEmpty || validLoadedCards.isEmpty ? seed.cards : validLoadedCards

        let preferences = LearningPreferences(
            targetLanguageCode: languageCode,
            nativeLanguageCode: nativeLanguageCode,
            goal: learningGoals.first ?? .travel,
            goals: learningGoals,
            interests: LearningGoal.defaultInterests(for: learningGoals)
        )
        let loadedState = try await learningStateStore.loadState(userID: userID, preferences: preferences)
        LearningDiagnostics.info("Backend loaded state with \(loadedState.itemStates.count) item states")
        userState = loadedState
        cards = composer.compose(candidates: candidateCards, userState: loadedState, now: now(), limit: 5)
        LearningDiagnostics.info("Backend composed \(cards.count) feed cards")

        analytics.track(AnalyticsEvent(name: "session_started", parameters: [
            "session_id": .string(sessionID),
            "language": .string(languageCode),
            "native_language": .string(nativeLanguageCode),
            "card_count": .int(cards.count)
        ]))

        return SessionStart(sessionID: sessionID, cards: cards, profile: profile(from: loadedState))
    }

    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult {
        guard sessionID == self.sessionID else { throw LearningBackendError.missingSession }
        guard let card = cards.first(where: { $0.id == answer.cardID }) else {
            throw LearningBackendError.missingCard
        }

        let isCorrect = Self.normalize(answer.response) == Self.normalize(card.correctAnswer)
        let reviewQuality = Self.reviewQuality(isCorrect: isCorrect, responseDuration: answer.responseDuration)
        var state = try currentState()
        state.seenCardIDs.insert(card.id)
        state.answeredCardIDs.insert(card.id)
        applyReview(for: card, quality: reviewQuality, state: &state)
        userState = state
        try await learningStateStore.saveState(state, userID: userID)

        var parameters: [String: SendableValue] = [
            "session_id": .string(sessionID),
            "language": .string(languageCode),
            "card_id": .string(card.id),
            "is_correct": .bool(isCorrect),
            "review_quality": .string(reviewQuality.rawValue),
            "target_item_ids": .stringArray(card.targetItemIDs),
            "target_item_count": .int(card.targetItemIDs.count)
        ]
        if let responseDuration = answer.responseDuration {
            parameters["response_duration"] = .double(responseDuration)
        }
        analytics.track(AnalyticsEvent(name: "card_answered", parameters: parameters))

        return CardAnswerResult(isCorrect: isCorrect, nextCard: try await nextCandidate(using: state))
    }

    func skip(sessionID: String, cardID: String) async throws -> LearningCard? {
        guard sessionID == self.sessionID else { throw LearningBackendError.missingSession }
        var state = try currentState()
        let card = cards.first { $0.id == cardID }
        state.seenCardIDs.insert(cardID)
        if let card {
            applyReview(for: card, quality: .again, state: &state)
        }
        userState = state
        try await learningStateStore.saveState(state, userID: userID)
        analytics.track(AnalyticsEvent(name: "card_skipped", parameters: [
            "session_id": .string(sessionID),
            "language": .string(languageCode),
            "card_id": .string(cardID),
            "review_quality": .string(ReviewQuality.again.rawValue),
            "target_item_ids": .stringArray(card?.targetItemIDs ?? [])
        ]))
        return try await nextCandidate(using: state)
    }

    func deferCard(sessionID: String, cardID: String) async throws -> LearningCard? {
        guard sessionID == self.sessionID else { throw LearningBackendError.missingSession }
        var state = try currentState()
        let card = cards.first { $0.id == cardID }
        state.seenCardIDs.insert(cardID)
        userState = state
        try await learningStateStore.saveState(state, userID: userID)
        analytics.track(AnalyticsEvent(name: "card_deferred", parameters: [
            "session_id": .string(sessionID),
            "language": .string(languageCode),
            "card_id": .string(cardID),
            "target_item_ids": .stringArray(card?.targetItemIDs ?? [])
        ]))
        return try await nextCandidate(using: state)
    }

    func markTooEasy(sessionID: String, cardID: String) async throws -> LearningCard? {
        guard sessionID == self.sessionID else { throw LearningBackendError.missingSession }
        var state = try currentState()
        let card = cards.first { $0.id == cardID }
        state.seenCardIDs.insert(cardID)
        state.tooEasyCardIDs.insert(cardID)
        if let card {
            applyReview(for: card, quality: .easy, state: &state)
        }
        userState = state
        try await learningStateStore.saveState(state, userID: userID)
        analytics.track(AnalyticsEvent(name: "card_too_easy", parameters: [
            "session_id": .string(sessionID),
            "language": .string(languageCode),
            "card_id": .string(cardID),
            "review_quality": .string(ReviewQuality.easy.rawValue),
            "target_item_ids": .stringArray(card?.targetItemIDs ?? [])
        ]))
        return try await nextCandidate(using: state)
    }

    func nextCard(sessionID: String) async throws -> LearningCard? {
        guard sessionID == self.sessionID else { throw LearningBackendError.missingSession }
        return try await nextCandidate(using: try currentState())
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        guard sessionID == self.sessionID else { throw LearningBackendError.missingSession }
        let state = try currentState()
        analytics.track(AnalyticsEvent(name: "session_ended", parameters: [
            "session_id": .string(sessionID),
            "language": .string(languageCode),
            "answered": .int(stats.answered),
            "correct": .int(stats.correct),
            "skipped": .int(stats.skipped)
        ]))
        return SessionSummary(stats: stats, profile: profile(from: state))
    }

    private func currentState() throws -> UserLearningState {
        guard let userState else { throw LearningBackendError.missingSession }
        return userState
    }

    private func applyReview(for card: LearningCard, quality: ReviewQuality, state: inout UserLearningState) {
        let reviewTime = now()
        for itemID in card.targetItemIDs {
            let item = itemsByID[itemID]
            var itemState = state.itemStates[itemID] ?? SRSItemState(
                itemID: itemID,
                kind: item?.kind ?? .phrase,
                strength: 0.25,
                difficulty: 0.5,
                repetitions: 0,
                lapses: 0,
                lastReviewedAt: nil,
                nextReviewAt: reviewTime
            )
            itemState.applyReview(quality, now: reviewTime)
            state.itemStates[itemID] = itemState
        }
    }

    private static func reviewQuality(isCorrect: Bool, responseDuration: TimeInterval?) -> ReviewQuality {
        guard isCorrect else { return .again }
        guard let responseDuration else { return .good }
        if responseDuration <= 8 {
            return .easy
        }
        if responseDuration >= 20 {
            return .hard
        }
        return .good
    }

    private func nextCandidate(using state: UserLearningState) async throws -> LearningCard? {
        let selected = composer.compose(candidates: candidateCards, userState: state, now: now(), limit: candidateCards.count)
        if let next = selected.first(where: { !state.answeredCardIDs.contains($0.id) && !state.tooEasyCardIDs.contains($0.id) }) {
            if !cards.contains(where: { $0.id == next.id }) {
                cards.append(next)
            }
            return next
        }

        let existingIDs = Set(candidateCards.map(\.id)).union(state.seenCardIDs).union(state.answeredCardIDs).union(state.tooEasyCardIDs)
        let generationResult = try await generationService.generateCards(
            languageCode: languageCode,
            userID: userID,
            userState: state,
            items: Array(itemsByID.values),
            existingCardIDs: existingIDs,
            limit: 6
        )
        let generatedCards = generationResult.cards.filter { LearningCardQuality.isValid($0, itemsByID: itemsByID) }

        guard let next = generatedCards.first else { return nil }
        candidateCards.append(contentsOf: generatedCards)
        if !generationResult.isPersisted {
            try await contentStore.saveGeneratedCards(languageCode: languageCode, cards: generatedCards)
        }
        if !cards.contains(where: { $0.id == next.id }) {
            cards.append(next)
        }
        return next
    }

    private func profile(from state: UserLearningState) -> UserProfile {
        let learned = state.itemStates.values.filter { $0.strength >= 0.65 }.count
        let weakTopics = state.itemStates.values
            .filter { $0.strength < 0.45 && $0.repetitions > 0 }
            .prefix(3)
            .map(\.itemID)
        return UserProfile(streak: 1, totalLearned: learned, weakTopics: Array(weakTopics))
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

struct AdaptiveSessionService: SessionService {
    let backend: AdaptiveLanguageBackend

    func start(languageCode: String, nativeLanguageCode: String, learningGoals: [LearningGoal]) async throws -> SessionStart {
        try await backend.start(languageCode: languageCode, nativeLanguageCode: nativeLanguageCode, learningGoals: learningGoals)
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        try await backend.end(sessionID: sessionID, stats: stats)
    }
}

struct AdaptiveCardService: CardService {
    let backend: AdaptiveLanguageBackend

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
