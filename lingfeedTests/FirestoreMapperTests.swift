import XCTest
@testable import lingfeed

final class FirestoreMapperTests: XCTestCase {
    func testLearningCardRoundTripsThroughDictionary() throws {
        let card = LearningCard(
            id: "card-1",
            type: .fillGap,
            context: "A1 / coffee",
            situation: "You are in a cafe.",
            prompt: "Un cafe ___",
            options: ["para llevar", "ayer"],
            correctAnswer: "para llevar",
            explanation: "Means to go.",
            chatMessages: [ChatMessage(id: "m1", text: "Hola", isUser: false)],
            targetItemIDs: ["item-1"],
            skillTags: ["coffee"],
            difficulty: 2,
            missionID: "mission-1"
        )

        let data = FirestoreLearningMapper.dictionary(from: card)
        let decoded = try FirestoreLearningMapper.card(id: "card-1", data: data)

        XCTAssertEqual(decoded, card)
    }

    func testSRSItemStateRoundTripsThroughDictionary() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let state = SRSItemState(
            itemID: "item-1",
            kind: .phrase,
            strength: 0.4,
            difficulty: 0.6,
            repetitions: 2,
            lapses: 1,
            lastReviewedAt: date,
            nextReviewAt: date.addingTimeInterval(600)
        )

        let data = FirestoreLearningMapper.dictionary(from: state)
        let decoded = try FirestoreLearningMapper.srsState(itemID: "item-1", data: data)

        XCTAssertEqual(decoded, state)
    }

    func testCloudInteractionResponseDecodesAnswerResultAndNextCard() throws {
        let response: [String: Any] = [
            "isCorrect": true,
            "nextCard": [
                "id": "next-card",
                "type": "translate",
                "context": "A1 / coffee",
                "prompt": "to go",
                "options": [],
                "correctAnswer": "para llevar",
                "explanation": "Use para llevar.",
                "targetItemIDs": ["phrase"],
                "skillTags": ["coffee"],
                "difficulty": 1
            ]
        ]

        let result = try CloudCardInteractionResponseMapper.answerResult(from: response)

        XCTAssertEqual(result.isCorrect, true)
        XCTAssertEqual(result.nextCard?.id, "next-card")
        XCTAssertEqual(result.nextCard?.correctAnswer, "para llevar")
    }

    func testCloudSessionResponseDecodesSessionStart() throws {
        let response: [String: Any] = [
            "sessionID": "session-es-123",
            "profile": [
                "streak": 2,
                "totalLearned": 4,
                "weakTopics": ["word_order"]
            ],
            "cards": [
                [
                    "id": "card-1",
                    "type": "translate",
                    "context": "A1 / coffee",
                    "prompt": "to go",
                    "options": [],
                    "correctAnswer": "para llevar",
                    "explanation": "Use para llevar.",
                    "targetItemIDs": ["phrase"],
                    "skillTags": ["coffee"],
                    "difficulty": 1
                ]
            ]
        ]

        let start = try CloudSessionResponseMapper.sessionStart(from: response)

        XCTAssertEqual(start.sessionID, "session-es-123")
        XCTAssertEqual(start.profile.totalLearned, 4)
        XCTAssertEqual(start.cards.map(\.id), ["card-1"])
    }

    func testCloudSessionResponseDecodesSessionSummary() throws {
        let response: [String: Any] = [
            "stats": [
                "answered": 8,
                "correct": 5,
                "skipped": 1
            ],
            "profile": [
                "streak": 3,
                "totalLearned": 9,
                "weakTopics": ["grammar", "word_order"]
            ],
            "accuracy": 0.63
        ]

        let summary = try CloudSessionResponseMapper.sessionSummary(from: response)

        XCTAssertEqual(summary.stats.answered, 8)
        XCTAssertEqual(summary.stats.correct, 5)
        XCTAssertEqual(summary.stats.skipped, 1)
        XCTAssertEqual(summary.profile.streak, 3)
        XCTAssertEqual(summary.profile.weakTopics, ["grammar", "word_order"])
    }

    func testLearningPreferencesRoundTripsMultipleGoals() throws {
        let preferences = LearningPreferences(
            targetLanguageCode: "en",
            nativeLanguageCode: "ru",
            level: .a1,
            goal: .work,
            goals: [.work, .study, .travel],
            interests: ["career", "coffee"],
            dailyMinutes: 8
        )

        let data = FirestoreLearningMapper.dictionary(from: preferences)
        let decoded = FirestoreLearningMapper.preferences(
            from: data,
            fallback: LearningPreferences(targetLanguageCode: "es", nativeLanguageCode: "en")
        )

        XCTAssertEqual(decoded.goal, .work)
        XCTAssertEqual(decoded.goals, [.work, .study, .travel])
        XCTAssertEqual(data["goals"] as? [String], ["work", "study", "travel"])
    }
}
