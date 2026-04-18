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

    private let authService: AuthService
    private let cardService: CardService
    private let sessionService: SessionService
    private var sessionID: String?
    private var committedCardID: LearningCard.ID?
    private let summaryInterval = 8
    private let prefetchThreshold = 3
    private let successAdvanceDelayNanoseconds: UInt64
    private var completedCardIDs: Set<LearningCard.ID> = []
    private var answeredCardIDs: Set<LearningCard.ID> = []
    private var pagingSkippedCardIDs: Set<LearningCard.ID> = []
    private var skippingCardIDs: Set<LearningCard.ID> = []
    private var tooEasyCardIDs: Set<LearningCard.ID> = []
    private var isPrefetching = false

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
        authService: AuthService,
        cardService: CardService,
        sessionService: SessionService,
        successAdvanceDelayNanoseconds: UInt64 = 1_200_000_000
    ) {
        self.languageCode = languageCode
        self.authService = authService
        self.cardService = cardService
        self.sessionService = sessionService
        self.successAdvanceDelayNanoseconds = successAdvanceDelayNanoseconds
    }

    func start() async {
        guard sessionID == nil else { return }
        phase = .loading
        do {
            _ = try await authService.signInAnonymously()
            let start = try await sessionService.start(languageCode: languageCode)
            sessionID = start.sessionID
            cards = start.cards
            currentCardID = start.cards.first?.id
            committedCardID = start.cards.first?.id
            profile = start.profile
            phase = .ready
        } catch {
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
        isPrefetching = false
        await start()
    }

    func submit(_ response: String) async {
        guard let sessionID, let card = currentCard, phase != .answering else { return }
        phase = .answering
        do {
            let result = try await cardService.answer(
                sessionID: sessionID,
                answer: CardAnswer(cardID: card.id, response: response)
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

    func markCurrentCardTooEasy() {
        guard let card = currentCard, phase != .answering else { return }
        tooEasyCardIDs.insert(card.id)
        completedCardIDs.insert(card.id)
        feedbackByCardID[card.id] = nil
        advanceToNextCard(after: card.id)
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
    }

    func dismissSummary() {
        summary = nil
    }

    private func advanceToNextCard(after cardID: LearningCard.ID) {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        currentCardID = cards[safe: cards.index(after: index)]?.id ?? cards.first?.id
        committedCardID = currentCardID

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
            let nextCard = try await cardService.skip(sessionID: sessionID, cardID: cardID)
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
