import XCTest
@testable import lingfeed

@MainActor
final class FeedViewModelTests: XCTestCase {
    func testStartLoadsInitialCardsAndProfile() async {
        let harness = FeedHarness()
        let viewModel = harness.makeViewModel()

        await viewModel.start()

        XCTAssertEqual(viewModel.cards.count, 5)
        XCTAssertEqual(viewModel.currentCard?.id, "card-1")
        XCTAssertEqual(viewModel.profile.streak, 3)
        XCTAssertEqual(viewModel.phase, .ready)
    }

    func testCorrectAnswerAdvancesAndAppendsNextCard() async {
        let harness = FeedHarness(
            answerResult: CardAnswerResult(isCorrect: true, nextCard: FeedHarness.card(id: "card-6"))
        )
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.submit("answer")

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.correct, 1)
        XCTAssertNil(viewModel.feedback)
        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
        XCTAssertTrue(viewModel.cards.contains { $0.id == "card-6" })
    }

    func testWrongAnswerKeepsFeedbackUntilContinue() async {
        let harness = FeedHarness(
            answerResult: CardAnswerResult(isCorrect: false, nextCard: FeedHarness.card(id: "card-6"))
        )
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.submit("wrong")

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.correct, 0)
        XCTAssertEqual(viewModel.currentCard?.id, "card-1")
        XCTAssertEqual(
            viewModel.feedback,
            .error(userAnswer: "wrong", correctAnswer: "answer", explanation: "Because it matches.")
        )

        viewModel.continueAfterFeedback()

        XCTAssertNil(viewModel.feedback)
        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
        XCTAssertTrue(viewModel.cards.contains { $0.id == "card-6" })
    }

    func testWrongAnswerFeedbackPersistsAfterPagingAwayAndBack() async {
        let harness = FeedHarness(
            answerResult: CardAnswerResult(isCorrect: false, nextCard: FeedHarness.card(id: "card-6"))
        )
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.submit("wrong")
        await viewModel.pageToCard("card-2")
        await viewModel.pageToCard("card-1")

        XCTAssertEqual(viewModel.currentCard?.id, "card-1")
        XCTAssertEqual(
            viewModel.feedback,
            .error(userAnswer: "wrong", correctAnswer: "answer", explanation: "Because it matches.")
        )
    }

    func testCorrectAnswerFeedbackPersistsAfterAutoAdvanceAndReturn() async {
        let harness = FeedHarness(
            answerResult: CardAnswerResult(isCorrect: true, nextCard: FeedHarness.card(id: "card-6"))
        )
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.submit("answer")
        await viewModel.pageToCard("card-1")

        XCTAssertEqual(viewModel.currentCard?.id, "card-1")
        XCTAssertEqual(viewModel.feedback, .success)
    }

    func testSkipAdvancesAndCountsSkippedCard() async {
        let harness = FeedHarness(skipCard: FeedHarness.card(id: "card-6"))
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.skipCurrentCard()

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.skipped, 1)
        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
        XCTAssertTrue(viewModel.cards.contains { $0.id == "card-6" })
    }

    func testTooEasyMarksCardAndAdvancesWithoutCountingSkip() async {
        let harness = FeedHarness()
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        viewModel.markCurrentCardTooEasy()

        XCTAssertTrue(viewModel.isMarkedTooEasy("card-1"))
        XCTAssertEqual(viewModel.stats.answered, 0)
        XCTAssertEqual(viewModel.stats.skipped, 0)
        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
    }

    func testPagingForwardFromUnansweredCardCountsAsSkipOnce() async {
        let harness = FeedHarness(skipCard: FeedHarness.card(id: "card-6"))
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.pageToCard("card-2")
        await viewModel.pageToCard("card-1")
        await viewModel.pageToCard("card-2")

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.skipped, 1)
        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
        XCTAssertTrue(viewModel.cards.contains { $0.id == "card-6" })
    }

    func testPreviewingCardDoesNotCountSkipUntilPageCommit() async {
        let harness = FeedHarness(skipCard: FeedHarness.card(id: "card-6"))
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        viewModel.previewCard("card-2")

        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
        XCTAssertEqual(viewModel.stats.answered, 0)
        XCTAssertEqual(viewModel.stats.skipped, 0)

        await viewModel.pageToCard("card-2")

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.skipped, 1)
    }

    func testAnsweringCardAfterPagingSkipReplacesSkipWithAnswer() async {
        let harness = FeedHarness(skipCard: FeedHarness.card(id: "card-6"))
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.pageToCard("card-2")
        await viewModel.pageToCard("card-1")
        await viewModel.submit("answer")

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.correct, 1)
        XCTAssertEqual(viewModel.stats.skipped, 0)
        XCTAssertEqual(viewModel.currentCard?.id, "card-2")
    }

    func testAnsweredCardDoesNotBecomeSkipWhenPagingAwayAgain() async {
        let harness = FeedHarness(skipCard: FeedHarness.card(id: "card-6"))
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.submit("answer")
        await viewModel.pageToCard("card-1")
        await viewModel.pageToCard("card-2")

        XCTAssertEqual(viewModel.stats.answered, 1)
        XCTAssertEqual(viewModel.stats.correct, 1)
        XCTAssertEqual(viewModel.stats.skipped, 0)
    }

    func testPagingNearEndPrefetchesMoreCards() async {
        let harness = FeedHarness(prefetchCards: [FeedHarness.card(id: "card-6"), FeedHarness.card(id: "card-7")])
        let viewModel = harness.makeViewModel()

        await viewModel.start()
        await viewModel.pageToCard("card-4")
        await viewModel.pageToCard("card-5")

        XCTAssertTrue(viewModel.cards.contains { $0.id == "card-6" })
        XCTAssertTrue(viewModel.cards.contains { $0.id == "card-7" })
    }
}

private struct FeedHarness {
    var answerResult: CardAnswerResult = CardAnswerResult(isCorrect: true, nextCard: nil)
    var skipCard: LearningCard? = nil
    var prefetchCards: [LearningCard] = []

    @MainActor
    func makeViewModel() -> FeedViewModel {
        FeedViewModel(
            languageCode: "es",
            authService: TestAuthService(),
            cardService: TestCardService(answerResult: answerResult, skipCard: skipCard, prefetchCards: prefetchCards),
            sessionService: TestSessionService(cards: Self.initialCards),
            successAdvanceDelayNanoseconds: 0
        )
    }

    static let initialCards: [LearningCard] = (1...5).map { card(id: "card-\($0)") }

    static func card(id: String) -> LearningCard {
        LearningCard(
            id: id,
            type: .translate,
            context: "Test",
            prompt: "Prompt",
            correctAnswer: "answer",
            explanation: "Because it matches."
        )
    }
}

private struct TestAuthService: AuthService {
    func signInAnonymously() async throws -> UserIdentity {
        UserIdentity(id: "test-user", isAnonymous: true)
    }
}

private final class TestCardService: CardService {
    let answerResult: CardAnswerResult
    let skipCard: LearningCard?
    private var prefetchCards: [LearningCard]

    init(answerResult: CardAnswerResult, skipCard: LearningCard?, prefetchCards: [LearningCard]) {
        self.answerResult = answerResult
        self.skipCard = skipCard
        self.prefetchCards = prefetchCards
    }

    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult {
        answerResult
    }

    func skip(sessionID: String, cardID: String) async throws -> LearningCard? {
        skipCard
    }

    func nextCard(sessionID: String) async throws -> LearningCard? {
        guard !prefetchCards.isEmpty else { return nil }
        return prefetchCards.removeFirst()
    }
}

private struct TestSessionService: SessionService {
    let cards: [LearningCard]

    func start(languageCode: String) async throws -> SessionStart {
        SessionStart(
            sessionID: "test-session",
            cards: cards,
            profile: UserProfile(streak: 3, totalLearned: 42, weakTopics: ["Word order"])
        )
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        SessionSummary(stats: stats, profile: UserProfile(streak: 3, totalLearned: 42, weakTopics: []))
    }
}
