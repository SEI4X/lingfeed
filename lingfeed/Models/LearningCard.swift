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
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let explanation: String
    let chatMessages: [ChatMessage]

    nonisolated init(
        id: String,
        type: CardType,
        context: String,
        prompt: String,
        options: [String] = [],
        correctAnswer: String,
        explanation: String,
        chatMessages: [ChatMessage] = []
    ) {
        self.id = id
        self.type = type
        self.context = context
        self.prompt = prompt
        self.options = options
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.chatMessages = chatMessages
    }
}

struct CardAnswer: Codable, Equatable, Sendable {
    let cardID: String
    let response: String
    let isSkipped: Bool
    let answeredAt: Date

    nonisolated init(cardID: String, response: String, isSkipped: Bool = false, answeredAt: Date = Date()) {
        self.cardID = cardID
        self.response = response
        self.isSkipped = isSkipped
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
