import Foundation

actor MockLanguageBackend {
    private var cursor = 0
    private var activeSessionID = ""
    private let deck: [LearningCard]

    init(deck: [LearningCard] = MockLanguageBackend.defaultDeck) {
        self.deck = deck
    }

    func start(
        languageCode: String,
        nativeLanguageCode: String = LanguageOption.fallbackNativeCode,
        learningGoals: [LearningGoal] = LearningGoal.defaultGoals
    ) async throws -> SessionStart {
        try await Task.sleep(nanoseconds: 180_000_000)
        cursor = 5
        activeSessionID = "session-\(languageCode)-\(UUID().uuidString.prefix(8))"
        return SessionStart(
            sessionID: activeSessionID,
            cards: Array(deck.prefix(5)),
            profile: UserProfile(
                streak: 4,
                totalLearned: 128,
                weakTopics: ["Past tense", "Food", "Quick replies"]
            )
        )
    }

    func answer(sessionID: String, answer: CardAnswer) async throws -> CardAnswerResult {
        try await Task.sleep(nanoseconds: 160_000_000)
        let card = deck.first { answer.cardID.hasPrefix($0.id) }
        let isCorrect = Self.normalize(answer.response) == Self.normalize(card?.correctAnswer ?? "")
        return CardAnswerResult(isCorrect: isCorrect, nextCard: nextCard())
    }

    func skip(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await Task.sleep(nanoseconds: 90_000_000)
        return nextCard()
    }

    func deferCard(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await Task.sleep(nanoseconds: 60_000_000)
        return nextCard()
    }

    func markTooEasy(sessionID: String, cardID: String) async throws -> LearningCard? {
        try await Task.sleep(nanoseconds: 90_000_000)
        return nextCard()
    }

    func nextCard(sessionID: String) async throws -> LearningCard? {
        try await Task.sleep(nanoseconds: 80_000_000)
        return nextCard()
    }

    func end(sessionID: String, stats: SessionStats) async throws -> SessionSummary {
        SessionSummary(
            stats: stats,
            profile: UserProfile(
                streak: stats.correct >= 5 ? 5 : 4,
                totalLearned: 128 + stats.correct,
                weakTopics: ["Past tense", "Word order", "Everyday chat"]
            )
        )
    }

    private func nextCard() -> LearningCard? {
        guard !deck.isEmpty else { return nil }
        let baseCard = deck[cursor % deck.count]
        let card = LearningCard(
            id: "\(baseCard.id)-gen-\(cursor)",
            type: baseCard.type,
            context: baseCard.context,
            situation: baseCard.situation,
            prompt: baseCard.prompt,
            options: baseCard.options,
            correctAnswer: baseCard.correctAnswer,
            explanation: baseCard.explanation,
            chatMessages: baseCard.chatMessages,
            targetItemIDs: baseCard.targetItemIDs,
            skillTags: baseCard.skillTags,
            difficulty: baseCard.difficulty,
            missionID: baseCard.missionID
        )
        cursor += 1
        return card
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static let defaultDeck: [LearningCard] = [
        LearningCard(
            id: "translate-hello",
            type: .translate,
            context: "A1 / greetings",
            prompt: "Translate: Good morning",
            correctAnswer: "Buenos dias",
            explanation: "Buenos dias is the everyday greeting before noon."
        ),
        LearningCard(
            id: "choice-coffee",
            type: .multipleChoice,
            context: "A1 / cafe",
            prompt: "Which phrase means I want coffee?",
            options: ["Quiero cafe", "Tengo cafe", "Soy cafe", "Voy cafe"],
            correctAnswer: "Quiero cafe",
            explanation: "Quiero means I want."
        ),
        LearningCard(
            id: "gap-water",
            type: .fillGap,
            context: "A1 / travel",
            prompt: "Necesito ___, por favor.",
            options: ["agua", "azul", "ayer", "alto"],
            correctAnswer: "agua",
            explanation: "Agua completes the request: I need water, please."
        ),
        LearningCard(
            id: "reorder-market",
            type: .reorder,
            context: "A2 / market",
            prompt: "Build the sentence: I buy apples today.",
            options: ["Compro", "manzanas", "hoy"],
            correctAnswer: "Compro manzanas hoy",
            explanation: "Spanish often keeps the verb first in a simple statement."
        ),
        LearningCard(
            id: "fix-ser",
            type: .fixMistake,
            context: "A1 / introductions",
            prompt: "Fix the sentence: Yo es estudiante.",
            correctAnswer: "Yo soy estudiante",
            explanation: "Use soy with yo for identity or profession."
        ),
        LearningCard(
            id: "chat-thanks",
            type: .chat,
            context: "A1 / chat",
            prompt: "Reply naturally to the barista.",
            options: ["Gracias", "Buenas noches", "Tengo dos", "Hasta ayer"],
            correctAnswer: "Gracias",
            explanation: "Gracias is the direct, natural reply after receiving something.",
            chatMessages: [
                ChatMessage(text: "Aqui tienes tu cafe.", isUser: false)
            ]
        ),
        LearningCard(
            id: "choice-bathroom",
            type: .multipleChoice,
            context: "A1 / directions",
            prompt: "How do you ask where the bathroom is?",
            options: ["Donde esta el bano?", "Cuanto cuesta?", "Que hora es?", "Como te llamas?"],
            correctAnswer: "Donde esta el bano?",
            explanation: "Donde esta asks where something is."
        ),
        LearningCard(
            id: "translate-see-you",
            type: .translate,
            context: "A1 / goodbyes",
            prompt: "Translate: See you tomorrow",
            correctAnswer: "Hasta manana",
            explanation: "Hasta manana means until tomorrow."
        ),
        LearningCard(
            id: "gap-name",
            type: .fillGap,
            context: "A1 / introductions",
            prompt: "Me ___ Alex.",
            options: ["llamo", "llama", "llamas", "llaman"],
            correctAnswer: "llamo",
            explanation: "Me llamo is the standard way to say my name is."
        ),
        LearningCard(
            id: "reorder-train",
            type: .reorder,
            context: "A2 / travel",
            prompt: "Build the sentence: The train arrives late.",
            options: ["El tren", "llega", "tarde"],
            correctAnswer: "El tren llega tarde",
            explanation: "The neutral order is subject, verb, adverb."
        ),
        LearningCard(
            id: "fix-have",
            type: .fixMistake,
            context: "A1 / needs",
            prompt: "Fix the sentence: Yo tiene hambre.",
            correctAnswer: "Yo tengo hambre",
            explanation: "Tengo is the yo form of tener."
        ),
        LearningCard(
            id: "chat-how-are-you",
            type: .chat,
            context: "A1 / small talk",
            prompt: "Reply to the message.",
            options: ["Estoy bien", "Soy bien", "Tengo bien", "Voy bien"],
            correctAnswer: "Estoy bien",
            explanation: "Estoy bien is the common answer to how are you.",
            chatMessages: [
                ChatMessage(text: "Como estas?", isUser: false)
            ]
        )
    ]
}
