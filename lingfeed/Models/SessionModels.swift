import Foundation

struct UserIdentity: Equatable, Sendable {
    let id: String
    let isAnonymous: Bool

    nonisolated init(id: String, isAnonymous: Bool) {
        self.id = id
        self.isAnonymous = isAnonymous
    }
}

struct UserProfile: Equatable, Sendable {
    let streak: Int
    let totalLearned: Int
    let weakTopics: [String]

    nonisolated init(streak: Int, totalLearned: Int, weakTopics: [String]) {
        self.streak = streak
        self.totalLearned = totalLearned
        self.weakTopics = weakTopics
    }

    static let empty = UserProfile(streak: 0, totalLearned: 0, weakTopics: [])
}

struct SessionStart: Equatable, Sendable {
    let sessionID: String
    let cards: [LearningCard]
    let profile: UserProfile

    nonisolated init(sessionID: String, cards: [LearningCard], profile: UserProfile) {
        self.sessionID = sessionID
        self.cards = cards
        self.profile = profile
    }
}

struct SessionStats: Equatable, Sendable {
    var answered = 0
    var correct = 0
    var skipped = 0

    nonisolated init(answered: Int = 0, correct: Int = 0, skipped: Int = 0) {
        self.answered = answered
        self.correct = correct
        self.skipped = skipped
    }

    var fixed: Int { max(0, answered - correct - skipped) }
    var accuracy: Double {
        guard answered > 0 else { return 0 }
        return Double(correct) / Double(answered)
    }

    mutating func registerAnswer(isCorrect: Bool) {
        answered += 1
        if isCorrect {
            correct += 1
        }
    }

    mutating func registerSkip() {
        answered += 1
        skipped += 1
    }

    mutating func replaceSkipWithAnswer(isCorrect: Bool) {
        if skipped > 0 {
            skipped -= 1
        }
        if isCorrect {
            correct += 1
        }
    }
}

struct SessionSummary: Equatable, Sendable {
    let stats: SessionStats
    let profile: UserProfile

    nonisolated init(stats: SessionStats, profile: UserProfile) {
        self.stats = stats
        self.profile = profile
    }
}
