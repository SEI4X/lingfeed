import Foundation

enum CardType: String, CaseIterable, Codable, Identifiable, Sendable {
    case translate
    case multipleChoice
    case fillGap
    case reorder
    case fixMistake
    case chat

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .translate: "card.type.translate"
        case .multipleChoice: "card.type.multipleChoice"
        case .fillGap: "card.type.fillGap"
        case .reorder: "card.type.reorder"
        case .fixMistake: "card.type.fixMistake"
        case .chat: "card.type.chat"
        }
    }
}

enum CardInteractionMode: Equatable, Sendable {
    case textEntry(prefillsPrompt: Bool)
    case options
    case reorder
}

struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let text: String
    let isUser: Bool

    nonisolated init(id: String = UUID().uuidString, text: String, isUser: Bool) {
        self.id = id
        self.text = text
        self.isUser = isUser
    }
}

struct LearningCard: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let type: CardType
    let context: String
    let situation: String?
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let explanation: String
    let chatMessages: [ChatMessage]
    let targetItemIDs: [String]
    let skillTags: [String]
    let difficulty: Int
    let missionID: String?

    nonisolated init(
        id: String,
        type: CardType,
        context: String,
        situation: String? = nil,
        prompt: String,
        options: [String] = [],
        correctAnswer: String,
        explanation: String,
        chatMessages: [ChatMessage] = [],
        targetItemIDs: [String] = [],
        skillTags: [String] = [],
        difficulty: Int = 1,
        missionID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.context = context
        self.situation = situation
        self.prompt = prompt
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.chatMessages = chatMessages
        self.targetItemIDs = targetItemIDs
        self.skillTags = skillTags
        self.difficulty = difficulty
        self.missionID = missionID
    }

    var interactionMode: CardInteractionMode {
        switch type {
        case .translate:
            .textEntry(prefillsPrompt: false)
        case .multipleChoice:
            .options
        case .fillGap:
            options.isEmpty ? .textEntry(prefillsPrompt: false) : .options
        case .reorder:
            .reorder
        case .fixMistake:
            .textEntry(prefillsPrompt: true)
        case .chat:
            options.isEmpty ? .textEntry(prefillsPrompt: false) : .options
        }
    }
}

enum LearningCardQuality {
    static func isValid(_ card: LearningCard, itemsByID: [String: LearningItem]) -> Bool {
        let targetItems = card.targetItemIDs.compactMap { itemsByID[$0] }
        guard !targetItems.isEmpty, targetItems.count == card.targetItemIDs.count else { return false }
        guard (1...5).contains(card.difficulty) else { return false }
        guard !containsUnsupportedInstruction(card) else { return false }

        switch card.type {
        case .translate:
            return answerMatchesTargets(card.correctAnswer, targetItems: targetItems)
        case .multipleChoice:
            return card.options.contains(card.correctAnswer) && answerMatchesTargets(card.correctAnswer, targetItems: targetItems)
        case .fillGap:
            return blankMarkerCount(in: card.prompt) == 1
                && !card.options.isEmpty
                && !isCompositeFillAnswer(card.correctAnswer)
                && answerAppearsInTargets(card.correctAnswer, targetItems: targetItems)
        case .reorder:
            return !card.options.isEmpty && sameTokens(card.options.joined(separator: " "), card.correctAnswer)
        case .fixMistake:
            return isFocusedFixMistake(prompt: card.prompt, correctAnswer: card.correctAnswer)
                && answerAppearsInTargets(card.correctAnswer, targetItems: targetItems)
        case .chat:
            return !isAmbiguousChatPrompt(card.prompt)
                && !card.options.isEmpty
                && card.options.contains(card.correctAnswer)
                && !card.chatMessages.isEmpty
                && !targetItems.contains { $0.kind == .lexeme }
                && answerAppearsInTargets(card.correctAnswer, targetItems: targetItems)
        }
    }

    private static func isAmbiguousChatPrompt(_ prompt: String) -> Bool {
        let prompt = normalize(prompt)
        return prompt == "reply naturally"
            || prompt == "respond naturally"
            || prompt == "answer naturally"
            || prompt == "ответьте естественно"
            || prompt == "ответь естественно"
    }

    private static func containsUnsupportedInstruction(_ card: LearningCard) -> Bool {
        let text = normalize([card.context, card.situation ?? "", card.prompt, card.explanation].joined(separator: " "))
        let prompt = normalize(card.prompt)
        if prompt == "say" || prompt.hasPrefix("say ") { return true }

        return [
            "pronounce",
            "pronunciation",
            "speak",
            "say aloud",
            "read aloud",
            "listen",
            "listening",
            "audio"
        ].contains { text.contains($0) }
    }

    private static func answerMatchesTargets(_ answer: String, targetItems: [LearningItem]) -> Bool {
        let answer = normalize(answer)
        guard !answer.isEmpty else { return false }

        let values = targetItems.map { normalize($0.value) }.filter { !$0.isEmpty }
        if values.contains(answer) { return true }
        if normalize(values.joined(separator: " ")) == answer { return true }

        let answerTokens = Set(answer.split(separator: " ").map(String.init))
        let targetTokens = Set(values.joined(separator: " ").split(separator: " ").map(String.init))
        return answerTokens.isSubset(of: targetTokens)
    }

    private static func answerAppearsInTargets(_ answer: String, targetItems: [LearningItem]) -> Bool {
        let answer = normalize(answer)
        guard !answer.isEmpty else { return false }

        let targetText = normalize(targetItems.map(\.value).joined(separator: " "))
        return targetText.contains(answer) || answerMatchesTargets(answer, targetItems: targetItems)
    }

    private static func blankMarkerCount(in prompt: String) -> Int {
        let pattern = #"_{2,}|\[\s*blank\s*\]|\{\s*blank\s*\}"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        return regex?.numberOfMatches(in: prompt, range: range) ?? 0
    }

    private static func isCompositeFillAnswer(_ answer: String) -> Bool {
        if answer.range(of: #"[,;/\n\r]"#, options: .regularExpression) != nil { return true }
        return normalize(answer).split(separator: " ").count > 4
    }

    private static func isFocusedFixMistake(prompt: String, correctAnswer: String) -> Bool {
        let sentence = mistakeSentence(from: prompt)
        guard !sentence.isEmpty else { return false }

        let incorrectTokens = normalize(sentence).split(separator: " ")
        let correctTokens = normalize(correctAnswer).split(separator: " ")
        guard incorrectTokens.count == correctTokens.count, !incorrectTokens.isEmpty else { return false }

        let differences = zip(incorrectTokens, correctTokens).filter { $0 != $1 }.count
        return differences == 1
    }

    private static func mistakeSentence(from prompt: String) -> String {
        guard let colonIndex = prompt.firstIndex(of: ":") else {
            return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prompt[prompt.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sameTokens(_ left: String, _ right: String) -> Bool {
        normalize(left).split(separator: " ").sorted() == normalize(right).split(separator: " ").sorted()
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

struct CardAnswer: Codable, Equatable, Sendable {
    let cardID: String
    let response: String
    let isSkipped: Bool
    let responseDuration: TimeInterval?
    let answeredAt: Date

    nonisolated init(
        cardID: String,
        response: String,
        isSkipped: Bool = false,
        responseDuration: TimeInterval? = nil,
        answeredAt: Date = Date()
    ) {
        self.cardID = cardID
        self.response = response
        self.isSkipped = isSkipped
        self.responseDuration = responseDuration
        self.answeredAt = answeredAt
    }
}

struct CardAnswerResult: Equatable, Sendable {
    let isCorrect: Bool
    let nextCard: LearningCard?

    nonisolated init(isCorrect: Bool, nextCard: LearningCard?) {
        self.isCorrect = isCorrect
        self.nextCard = nextCard
    }
}

enum FeedbackState: Equatable {
    case success
    case error(userAnswer: String, correctAnswer: String, explanation: String)
}
