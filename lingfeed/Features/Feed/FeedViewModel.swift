import Combine
import Foundation

enum FeedPhase: Equatable {
    case idle
    case loading
    case ready
    case answering
    case failed(String)
}

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var phase: FeedPhase = .idle
    @Published private(set) var cards: [LearningCard] = []
    @Published private(set) var stats = SessionStats()
    @Published private(set) var profile = UserProfile.empty
    @Published private(set) var currentCardID: LearningCard.ID?
    @Published var summary: SessionSummary?
    @Published private var feedbackByCardID: [LearningCard.ID: FeedbackState] = [:]

    let languageCode: String
    let nativeLanguageCode: String
    let learningGoals: [LearningGoal]

    private let authService: AuthService
    private let cardService: CardService
    private let sessionService: SessionService
    private var sessionID: String?
    private var committedCardID: LearningCard.ID?
    private let summaryInterval = 8
    private let prefetchThreshold = 3
    private let successAdvanceDelayNanoseconds: UInt64
    private let now: () -> Date
    private var completedCardIDs: Set<LearningCard.ID> = []
    private var answeredCardIDs: Set<LearningCard.ID> = []
    private var pagingSkippedCardIDs: Set<LearningCard.ID> = []
    private var skippingCardIDs: Set<LearningCard.ID> = []
    private var tooEasyCardIDs: Set<LearningCard.ID> = []
    private var viewedCardIDs: Set<LearningCard.ID> = []
    private var cardActivatedAt: [LearningCard.ID: Date] = [:]
    private var isPrefetching = false
    #if DEBUG
    private var hasRunSmokeAnswer = false
    #endif

    var currentCard: LearningCard? {
        guard let currentCardID else { return cards.first }
        return cards.first { $0.id == currentCardID } ?? cards.first
    }

    var feedback: FeedbackState? {
        guard let currentCardID else { return nil }
        return feedbackByCardID[currentCardID]
    }

    var isBusy: Bool {
        phase == .loading || phase == .answering
    }

    init(
        languageCode: String,
        nativeLanguageCode: String = LanguageOption.fallbackNativeCode,
        learningGoals: [LearningGoal] = LearningGoal.defaultGoals,
        authService: AuthService,
        cardService: CardService,
        sessionService: SessionService,
        successAdvanceDelayNanoseconds: UInt64 = 1_200_000_000,
        now: @escaping () -> Date = Date.init
    ) {
        self.languageCode = languageCode
        self.nativeLanguageCode = nativeLanguageCode
        self.learningGoals = learningGoals
        self.authService = authService
        self.cardService = cardService
        self.sessionService = sessionService
        self.successAdvanceDelayNanoseconds = successAdvanceDelayNanoseconds
        self.now = now
    }

    func start() async {
        guard sessionID == nil else { return }
        phase = .loading
        do {
            LearningDiagnostics.info("Feed start begin for \(languageCode)")
            let start = try await withTimeout(seconds: 18) {
                _ = try await self.authService.signInAnonymously()
                return try await self.sessionService.start(
                    languageCode: self.languageCode,
                    nativeLanguageCode: self.nativeLanguageCode,
                    learningGoals: self.learningGoals
                )
            }
            guard !start.cards.isEmpty else {
                throw EmptyFeedError()
            }
            sessionID = start.sessionID
            cards = start.cards
            currentCardID = start.cards.first?.id
            committedCardID = start.cards.first?.id
            markActivated(start.cards.first?.id)
            await recordCommittedExposure(start.cards.first?.id)
            profile = start.profile
            phase = .ready
            LearningDiagnostics.info("Feed start ready with \(start.cards.count) cards")
            #if DEBUG
            await runSmokeAnswerIfRequested()
            #endif
        } catch {
            LearningDiagnostics.error("Feed start failed: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        sessionID = nil
        committedCardID = nil
        cards = []
        currentCardID = nil
        feedbackByCardID = [:]
        stats = SessionStats()
        summary = nil
        completedCardIDs = []
        answeredCardIDs = []
        pagingSkippedCardIDs = []
        skippingCardIDs = []
        tooEasyCardIDs = []
        viewedCardIDs = []
        cardActivatedAt = [:]
        isPrefetching = false
        await start()
    }

    func submit(_ response: String) async {
        guard let sessionID, let card = currentCard, phase != .answering else { return }
        let answeredAt = now()
        let responseDuration = cardActivatedAt[card.id].map { max(0, answeredAt.timeIntervalSince($0)) }
        phase = .answering
        do {
            let result = try await cardService.answer(
                sessionID: sessionID,
                answer: CardAnswer(
                    cardID: card.id,
                    response: response,
                    responseDuration: responseDuration,
                    answeredAt: answeredAt
                )
            )
            if let nextCard = result.nextCard {
                appendIfNeeded(nextCard)
            }
            completedCardIDs.insert(card.id)
            answeredCardIDs.insert(card.id)
            if pagingSkippedCardIDs.remove(card.id) != nil {
                stats.replaceSkipWithAnswer(isCorrect: result.isCorrect)
            } else {
                stats.registerAnswer(isCorrect: result.isCorrect)
            }
            feedbackByCardID[card.id] = result.isCorrect
                ? .success
                : .error(userAnswer: response, correctAnswer: card.correctAnswer, explanation: card.explanation)
            phase = .ready

            if result.isCorrect {
                if successAdvanceDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: successAdvanceDelayNanoseconds)
                }
                advanceToNextCard(after: card.id)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func skipCurrentCard() async {
        guard let sessionID, let card = currentCard, phase != .answering else { return }
        phase = .answering
        do {
            let nextCard = try await cardService.skip(sessionID: sessionID, cardID: card.id)
            registerSkip(for: card.id, isPagingSkip: false)
            if let nextCard {
                appendIfNeeded(nextCard)
            }
            feedbackByCardID[card.id] = nil
            phase = .ready
            advanceToNextCard(after: card.id)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func markCurrentCardTooEasy() async {
        guard let sessionID, let card = currentCard, phase != .answering else { return }
        phase = .answering
        do {
            let nextCard = try await cardService.markTooEasy(sessionID: sessionID, cardID: card.id)
            tooEasyCardIDs.insert(card.id)
            completedCardIDs.insert(card.id)
            feedbackByCardID[card.id] = nil
            if let nextCard {
                appendIfNeeded(nextCard)
            }
            phase = .ready
            advanceToNextCard(after: card.id)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func isMarkedTooEasy(_ cardID: LearningCard.ID) -> Bool {
        tooEasyCardIDs.contains(cardID)
    }

    func continueAfterFeedback() {
        guard let cardID = currentCard?.id else { return }
        advanceToNextCard(after: cardID)
    }

    func activateCard(_ id: LearningCard.ID) {
        guard cards.contains(where: { $0.id == id }), currentCardID != id else { return }
        currentCardID = id
        markActivated(id)
    }

    func previewCard(_ id: LearningCard.ID) {
        activateCard(id)
    }

    func pageToCard(_ id: LearningCard.ID) async {
        guard cards.contains(where: { $0.id == id }) else { return }
        let previousCardID = committedCardID ?? currentCardID
        activateCard(id)

        if shouldCountForwardSkip(from: previousCardID, to: id), let previousCardID {
            await skipUnansweredCard(previousCardID)
        }

        await prefetchIfNeeded(around: id)
        committedCardID = id
        await recordCommittedExposure(id)
    }

    func dismissSummary() {
        summary = nil
    }

    private func advanceToNextCard(after cardID: LearningCard.ID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        currentCardID = cards[safe: cards.index(after: index)]?.id ?? cards.first?.id
        committedCardID = currentCardID
        markActivated(currentCardID)
        let exposedCardID = currentCardID
        Task { [weak self] in
            await self?.recordCommittedExposure(exposedCardID)
        }

        if stats.answered > 0, stats.answered.isMultiple(of: summaryInterval), let sessionID {
            Task {
                summary = try? await sessionService.end(sessionID: sessionID, stats: stats)
            }
        }
    }

    private func appendIfNeeded(_ card: LearningCard) {
        guard !cards.contains(where: { $0.id == card.id }) else { return }
        cards.append(card)
    }

    private func markActivated(_ cardID: LearningCard.ID?) {
        guard let cardID, cardActivatedAt[cardID] == nil else { return }
        cardActivatedAt[cardID] = now()
    }

    private func recordCommittedExposure(_ cardID: LearningCard.ID?) async {
        guard let sessionID, let cardID else { return }
        do {
            if viewedCardIDs.contains(cardID) {
                try await cardService.recordReturned(sessionID: sessionID, cardID: cardID)
            } else {
                viewedCardIDs.insert(cardID)
                try await cardService.recordViewed(sessionID: sessionID, cardID: cardID)
            }
        } catch {
            LearningDiagnostics.error("Card exposure event failed: \(error.localizedDescription)")
        }
    }

    private func shouldCountForwardSkip(from previousCardID: LearningCard.ID?, to nextCardID: LearningCard.ID) -> Bool {
        guard
            let previousCardID,
            previousCardID != nextCardID,
            !completedCardIDs.contains(previousCardID),
            !answeredCardIDs.contains(previousCardID),
            !skippingCardIDs.contains(previousCardID),
            let previousIndex = cards.firstIndex(where: { $0.id == previousCardID }),
            let nextIndex = cards.firstIndex(where: { $0.id == nextCardID })
        else {
            return false
        }

        return nextIndex > previousIndex
    }

    private func skipUnansweredCard(_ cardID: LearningCard.ID) async {
        guard let sessionID, !completedCardIDs.contains(cardID), !skippingCardIDs.contains(cardID) else { return }
        skippingCardIDs.insert(cardID)
        do {
            let nextCard = try await cardService.deferCard(sessionID: sessionID, cardID: cardID)
            registerSkip(for: cardID, isPagingSkip: true)
            if let nextCard {
                appendIfNeeded(nextCard)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        skippingCardIDs.remove(cardID)
    }

    private func registerSkip(for cardID: LearningCard.ID, isPagingSkip: Bool) {
        guard !completedCardIDs.contains(cardID) else { return }
        completedCardIDs.insert(cardID)
        if isPagingSkip {
            pagingSkippedCardIDs.insert(cardID)
        }
        stats.registerSkip()
    }

    #if DEBUG
    private func runSmokeAnswerIfRequested() async {
        guard
            !hasRunSmokeAnswer,
            ProcessInfo.processInfo.arguments.contains("--smoke-answer-first-card"),
            let card = currentCard
        else {
            return
        }

        hasRunSmokeAnswer = true
        LearningDiagnostics.info("Smoke answering first card \(card.id)")
        await submit(card.correctAnswer)
    }
    #endif

    private func prefetchIfNeeded(around cardID: LearningCard.ID) async {
        guard let sessionID, !isPrefetching else { return }
        isPrefetching = true
        defer { isPrefetching = false }

        while remainingCards(after: cardID) < prefetchThreshold {
            guard let nextCard = try? await cardService.nextCard(sessionID: sessionID) else { break }
            appendIfNeeded(nextCard)
        }
    }

    private func remainingCards(after cardID: LearningCard.ID) -> Int {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return 0 }
        return cards.distance(from: cards.index(after: index), to: cards.endIndex)
    }
}

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        guard let value = try await group.next() else {
            throw TimeoutError()
        }
        group.cancelAll()
        return value
    }
}

private struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        "The learning feed took too long to load. Check your connection and try again."
    }
}

private struct EmptyFeedError: LocalizedError {
    var errorDescription: String? {
        "No learning cards are available yet. Try again in a moment."
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
