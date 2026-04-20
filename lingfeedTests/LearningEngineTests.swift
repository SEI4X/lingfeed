import XCTest
@testable import lingfeed

final class LearningEngineTests: XCTestCase {
    func testSRSReviewSchedulePromotesGoodAnswer() {
        let now = Date(timeIntervalSince1970: 1_000)
        let item = LearningItem(
            id: "es_phrase_para_llevar",
            kind: .phrase,
            languageCode: "es",
            value: "para llevar",
            translation: "to go",
            explanation: "Used for takeaway orders.",
            tags: ["coffee"],
            level: .a1
        )
        var state = SRSItemState.new(item: item, now: now)

        state.applyReview(.good, now: now)

        XCTAssertEqual(state.repetitions, 1)
        XCTAssertEqual(state.lapses, 0)
        XCTAssertGreaterThan(state.strength, 0.25)
        XCTAssertEqual(state.nextReviewAt, now.addingTimeInterval(3 * 24 * 60 * 60))
    }

    func testSRSReviewScheduleBringsWrongAnswerBackSoon() {
        let now = Date(timeIntervalSince1970: 1_000)
        var state = SRSItemState(
            itemID: "ser-yo-soy",
            kind: .grammarPattern,
            strength: 0.72,
            difficulty: 0.4,
            repetitions: 3,
            lapses: 0,
            lastReviewedAt: now.addingTimeInterval(-1_000),
            nextReviewAt: now
        )

        state.applyReview(.again, now: now)

        XCTAssertEqual(state.repetitions, 3)
        XCTAssertEqual(state.lapses, 1)
        XCTAssertLessThan(state.strength, 0.72)
        XCTAssertEqual(state.nextReviewAt, now.addingTimeInterval(10 * 60))
    }

    func testFeedComposerPrioritizesDueReviewOverNewCard() {
        let now = Date(timeIntervalSince1970: 1_000)
        let dueCard = Self.card(id: "review-card", targetItemIDs: ["review-item"], skillTags: ["coffee"])
        let newCard = Self.card(id: "new-card", targetItemIDs: ["new-item"], skillTags: ["coffee"])
        let composer = FeedComposer(scorer: CardScorer())
        let userState = UserLearningState(
            seenCardIDs: [],
            answeredCardIDs: [],
            tooEasyCardIDs: [],
            itemStates: [
                "review-item": SRSItemState(
                    itemID: "review-item",
                    kind: .phrase,
                    strength: 0.2,
                    difficulty: 0.5,
                    repetitions: 1,
                    lapses: 0,
                    lastReviewedAt: now.addingTimeInterval(-86_400),
                    nextReviewAt: now.addingTimeInterval(-60)
                )
            ],
            preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
        )

        let cards = composer.compose(
            candidates: [newCard, dueCard],
            userState: userState,
            now: now,
            limit: 2
        )

        XCTAssertEqual(cards.map(\.id), ["review-card", "new-card"])
    }

    func testFeedComposerPenalizesTooEasyCards() {
        let now = Date(timeIntervalSince1970: 1_000)
        let tooEasy = Self.card(id: "easy-card", targetItemIDs: ["easy-item"], skillTags: ["coffee"])
        let regular = Self.card(id: "regular-card", targetItemIDs: ["regular-item"], skillTags: ["coffee"])
        let composer = FeedComposer(scorer: CardScorer())
        let userState = UserLearningState(
            seenCardIDs: [],
            answeredCardIDs: [],
            tooEasyCardIDs: ["easy-card"],
            itemStates: [:],
            preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
        )

        let cards = composer.compose(
            candidates: [tooEasy, regular],
            userState: userState,
            now: now,
            limit: 2
        )

        XCTAssertEqual(cards.map(\.id), ["regular-card", "easy-card"])
    }

    func testFeedComposerPrioritizesSelectedGoalsButKeepsExplorationCards() {
        let now = Date(timeIntervalSince1970: 1_000)
        let workCard = Self.card(id: "work-card", targetItemIDs: ["work-item"], skillTags: ["career"], missionID: "work")
        let travelCard = Self.card(id: "travel-card", targetItemIDs: ["travel-item"], skillTags: ["airport"], missionID: "travel")
        let composer = FeedComposer(scorer: CardScorer())
        let userState = UserLearningState(
            preferences: LearningPreferences(
                targetLanguageCode: "en",
                nativeLanguageCode: "ru",
                goal: .work,
                goals: [.work],
                interests: ["career"]
            )
        )

        let cards = composer.compose(
            candidates: [travelCard, workCard],
            userState: userState,
            now: now,
            limit: 2
        )

        XCTAssertEqual(cards.map(\.id), ["work-card", "travel-card"])
    }

    func testRuleBasedExerciseGeneratorCreatesOccasionalExplorationCards() {
        let generator = RuleBasedExerciseGenerator()
        let cards = generator.generateCards(
            languageCode: "es",
            items: [
                LearningItem(
                    id: "long",
                    kind: .phrase,
                    languageCode: "es",
                    value: "quiero cafe ahora",
                    translation: "I want coffee now",
                    tags: ["coffee"],
                    level: .a1
                )
            ],
            userState: UserLearningState(
                preferences: LearningPreferences(
                    targetLanguageCode: "es",
                    nativeLanguageCode: "en",
                    goal: .work,
                    goals: [.work],
                    interests: ["career"]
                )
            ),
            existingCardIDs: [],
            limit: 6
        )

        XCTAssertTrue(cards.contains { $0.missionID == "work" })
        XCTAssertTrue(cards.contains { $0.missionID != "work" })
    }

    func testCardInteractionModesCoverSupportedLessonTypes() {
        XCTAssertEqual(Self.card(id: "translate", type: .translate).interactionMode, .textEntry(prefillsPrompt: false))
        XCTAssertEqual(Self.card(id: "choice", type: .multipleChoice, options: ["A", "B"]).interactionMode, .options)
        XCTAssertEqual(Self.card(id: "gap-choice", type: .fillGap, options: ["A", "B"]).interactionMode, .options)
        XCTAssertEqual(Self.card(id: "gap-text", type: .fillGap).interactionMode, .textEntry(prefillsPrompt: false))
        XCTAssertEqual(Self.card(id: "reorder", type: .reorder, options: ["Yo", "soy"]).interactionMode, .reorder)
        XCTAssertEqual(Self.card(id: "fix", type: .fixMistake).interactionMode, .textEntry(prefillsPrompt: true))
        XCTAssertEqual(Self.card(id: "chat", type: .chat, options: ["Gracias"]).interactionMode, .options)
        XCTAssertEqual(Self.card(id: "chat-text", type: .chat).interactionMode, .textEntry(prefillsPrompt: false))
    }

    func testRuleBasedExerciseGeneratorCanProduceEverySupportedCardType() {
        let generator = RuleBasedExerciseGenerator()
        let cards = generator.generateCards(
            languageCode: "es",
            items: [
                LearningItem(
                    id: "identity",
                    kind: .grammarPattern,
                    languageCode: "es",
                    value: "Yo soy estudiante",
                    translation: "I am a student",
                    explanation: "Use soy with yo for identity.",
                    tags: ["introductions"],
                    level: .a1
                ),
                LearningItem(
                    id: "thanks",
                    kind: .phrase,
                    languageCode: "es",
                    value: "gracias",
                    translation: "thank you",
                    tags: ["chat"],
                    level: .a1
                ),
                LearningItem(
                    id: "coffee",
                    kind: .lexeme,
                    languageCode: "es",
                    value: "cafe",
                    translation: "coffee",
                    tags: ["coffee"],
                    level: .a1
                )
            ],
            userState: UserLearningState(preferences: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")),
            existingCardIDs: [],
            limit: 12
        )

        XCTAssertEqual(Set(cards.map(\.type)), Set(CardType.allCases))
        XCTAssertTrue(cards.first(where: { $0.type == .multipleChoice })?.options.contains("Yo soy estudiante") == true)
        XCTAssertFalse(cards.first(where: { $0.type == .reorder })?.options.isEmpty ?? true)
        XCTAssertTrue(cards.first(where: { $0.type == .fixMistake })?.prompt.contains("Yo es estudiante") == true)
    }

    func testLearningCardQualityRejectsBrokenGeneratedCards() {
        let itemsByID = [
            "es_grammar_yo_soy": LearningItem(
                id: "es_grammar_yo_soy",
                kind: .grammarPattern,
                languageCode: "es",
                value: "yo + soy",
                translation: "I am",
                tags: ["introductions"],
                level: .a1
            ),
            "es_phrase_gracias": LearningItem(
                id: "es_phrase_gracias",
                kind: .phrase,
                languageCode: "es",
                value: "gracias",
                translation: "thank you",
                tags: ["introductions"],
                level: .a1
            ),
            "es_phrase_para_llevar": LearningItem(
                id: "es_phrase_para_llevar",
                kind: .phrase,
                languageCode: "es",
                value: "para llevar",
                translation: "to go",
                tags: ["coffee"],
                level: .a1
            )
        ]

        let multiBlank = LearningCard(
            id: "broken-gap",
            type: .fillGap,
            context: "A1 / introductions",
            prompt: "Yo ___ ___. ____",
            correctAnswer: "soy, Gracias",
            explanation: "Soy means I am and gracias means thank you.",
            targetItemIDs: ["es_grammar_yo_soy", "es_phrase_gracias"]
        )
        let speaking = LearningCard(
            id: "broken-speaking",
            type: .translate,
            context: "A1 / coffee",
            prompt: "Say: to go",
            correctAnswer: "para llevar",
            explanation: "Say the phrase naturally.",
            targetItemIDs: ["es_phrase_para_llevar"]
        )
        let validGap = LearningCard(
            id: "valid-gap",
            type: .fillGap,
            context: "A1 / coffee",
            prompt: "Quiero cafe ___.",
            options: ["para llevar", "ayer"],
            correctAnswer: "para llevar",
            explanation: "Use para llevar for takeaway orders.",
            targetItemIDs: ["es_phrase_para_llevar"]
        )
        let brokenChat = LearningCard(
            id: "broken-chat",
            type: .chat,
            context: "A1 / coffee",
            situation: "You are at a cafe.",
            prompt: "Reply naturally.",
            correctAnswer: "para llevar",
            explanation: "Use para llevar for takeaway orders.",
            targetItemIDs: ["es_phrase_para_llevar"]
        )

        XCTAssertFalse(LearningCardQuality.isValid(multiBlank, itemsByID: itemsByID))
        XCTAssertFalse(LearningCardQuality.isValid(speaking, itemsByID: itemsByID))
        XCTAssertFalse(LearningCardQuality.isValid(brokenChat, itemsByID: itemsByID))
        XCTAssertTrue(LearningCardQuality.isValid(validGap, itemsByID: itemsByID))
    }

    func testSeedContentCoversEverySupportedTargetLanguageWithoutSpanishLeak() {
        let spanishLeakPattern = try! NSRegularExpression(
            pattern: "quiero|gracias|para llevar|buenas noches|tengo dos|hasta ayer|aqui tienes|un cafe",
            options: [.caseInsensitive]
        )

        for language in LanguageOption.learningChoices {
            let seed = SeedLearningContent.content(languageCode: language.code)
            let itemsByID = Dictionary(uniqueKeysWithValues: seed.items.map { ($0.id, $0) })

            XCTAssertFalse(seed.items.isEmpty, "\(language.code) has no seed items")
            XCTAssertFalse(seed.cards.isEmpty, "\(language.code) has no seed cards")
            XCTAssertTrue(seed.items.allSatisfy { $0.languageCode == language.code }, "\(language.code) has item language mismatch")
            XCTAssertTrue(seed.cards.allSatisfy { LearningCardQuality.isValid($0, itemsByID: itemsByID) }, "\(language.code) has invalid seed cards")

            for goal in LearningGoal.allCases {
                XCTAssertTrue(seed.cards.contains { $0.missionID == goal.rawValue }, "\(language.code) missing starter cards for \(goal.rawValue)")
            }

            if language.code != "es" {
                let text = String(describing: seed)
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                XCTAssertNil(spanishLeakPattern.firstMatch(in: text, range: range), "\(language.code) leaked Spanish starter content")
            }
        }
    }

    private static func card(
        id: String,
        targetItemIDs: [String],
        skillTags: [String],
        missionID: String = "coffee-run"
    ) -> LearningCard {
        LearningCard(
            id: id,
            type: .fillGap,
            context: "A1 / coffee",
            situation: "You are ordering coffee.",
            prompt: "Un cafe ___, por favor.",
            options: ["para llevar", "ayer", "azul"],
            correctAnswer: "para llevar",
            explanation: "Para llevar means to go.",
            targetItemIDs: targetItemIDs,
            skillTags: skillTags,
            difficulty: 1,
            missionID: missionID
        )
    }

    private static func card(id: String, type: CardType, options: [String] = []) -> LearningCard {
        LearningCard(
            id: id,
            type: type,
            context: "A1 / test",
            prompt: "Prompt",
            options: options,
            correctAnswer: "Answer",
            explanation: "Explanation"
        )
    }
}
