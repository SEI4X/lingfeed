import Foundation

enum CEFRLevel: String, Codable, CaseIterable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
}

enum SRSItemKind: String, Codable, CaseIterable, Sendable {
    case lexeme
    case phrase
    case grammarPattern
    case mistakePattern
}

struct LearningItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let kind: SRSItemKind
    let languageCode: String
    let value: String
    let translation: String?
    let explanation: String?
    let tags: [String]
    let level: CEFRLevel

    nonisolated init(
        id: String,
        kind: SRSItemKind,
        languageCode: String,
        value: String,
        translation: String? = nil,
        explanation: String? = nil,
        tags: [String] = [],
        level: CEFRLevel = .a1
    ) {
        self.id = id
        self.kind = kind
        self.languageCode = languageCode
        self.value = value
        self.translation = translation
        self.explanation = explanation
        self.tags = tags
        self.level = level
    }
}

enum LearningGoal: String, Codable, CaseIterable, Sendable {
    case travel
    case work
    case dating
    case relocation
    case study
    case everyday

    var titleKey: String {
        "goal.\(rawValue)"
    }

    var subtitleKey: String {
        "goal.\(rawValue).subtitle"
    }

    static let defaultGoals: [LearningGoal] = [.travel]

    static func decoded(from rawValue: String) -> LearningGoal? {
        LearningGoal(rawValue: rawValue)
    }

    static func rawValues(from goals: [LearningGoal]) -> [String] {
        goals.map(\.rawValue)
    }

    static func goals(from rawValues: [String]) -> [LearningGoal] {
        let unique = rawValues.reduce(into: [LearningGoal]()) { result, rawValue in
            guard let goal = LearningGoal(rawValue: rawValue), !result.contains(goal) else { return }
            result.append(goal)
        }
        return unique.isEmpty ? defaultGoals : unique
    }

    static func defaultInterests(for goals: [LearningGoal]) -> [String] {
        let byGoal: [LearningGoal: [String]] = [
            .travel: ["airport", "hotel", "restaurant", "directions"],
            .work: ["career", "meetings", "email", "small_talk"],
            .dating: ["small_talk", "feelings", "compliments", "plans"],
            .relocation: ["housing", "documents", "healthcare", "banking"],
            .study: ["campus", "classroom", "exams", "friends"],
            .everyday: ["shopping", "coffee", "transport", "home"]
        ]
        let values = goals.flatMap { byGoal[$0] ?? [] }
        return Array(NSOrderedSet(array: values)) as? [String] ?? values
    }
}

struct LearningPreferences: Codable, Equatable, Sendable {
    var targetLanguageCode: String
    var nativeLanguageCode: String
    var level: CEFRLevel
    var goal: LearningGoal
    var goals: [LearningGoal]
    var interests: [String]
    var dailyMinutes: Int

    nonisolated init(
        targetLanguageCode: String,
        nativeLanguageCode: String,
        level: CEFRLevel = .a1,
        goal: LearningGoal = .travel,
        goals: [LearningGoal]? = nil,
        interests: [String] = ["coffee", "restaurant", "small_talk"],
        dailyMinutes: Int = 5
    ) {
        self.targetLanguageCode = targetLanguageCode
        self.nativeLanguageCode = nativeLanguageCode
        self.level = level
        self.goal = goal
        self.goals = goals?.isEmpty == false ? goals! : [goal]
        self.interests = interests
        self.dailyMinutes = dailyMinutes
    }
}

enum ReviewQuality: String, Codable, Sendable {
    case again
    case hard
    case good
    case easy
}

struct SRSItemState: Codable, Equatable, Sendable {
    let itemID: String
    let kind: SRSItemKind
    var strength: Double
    var difficulty: Double
    var repetitions: Int
    var lapses: Int
    var lastReviewedAt: Date?
    var nextReviewAt: Date

    nonisolated init(
        itemID: String,
        kind: SRSItemKind,
        strength: Double,
        difficulty: Double,
        repetitions: Int,
        lapses: Int,
        lastReviewedAt: Date?,
        nextReviewAt: Date
    ) {
        self.itemID = itemID
        self.kind = kind
        self.strength = strength
        self.difficulty = difficulty
        self.repetitions = repetitions
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
    }

    static func new(item: LearningItem, now: Date) -> SRSItemState {
        SRSItemState(
            itemID: item.id,
            kind: item.kind,
            strength: 0.25,
            difficulty: 0.5,
            repetitions: 0,
            lapses: 0,
            lastReviewedAt: nil,
            nextReviewAt: now
        )
    }

    mutating func applyReview(_ quality: ReviewQuality, now: Date) {
        lastReviewedAt = now

        switch quality {
        case .again:
            lapses += 1
            strength = max(0.05, strength - 0.25)
            difficulty = min(1, difficulty + 0.08)
            nextReviewAt = now.addingTimeInterval(10 * 60)
        case .hard:
            repetitions += 1
            strength = min(1, strength + 0.08)
            difficulty = min(1, difficulty + 0.03)
            nextReviewAt = now.addingTimeInterval(24 * 60 * 60)
        case .good:
            repetitions += 1
            strength = min(1, strength + 0.18)
            difficulty = max(0, difficulty - 0.02)
            nextReviewAt = now.addingTimeInterval(3 * 24 * 60 * 60)
        case .easy:
            repetitions += 1
            strength = min(1, strength + 0.32)
            difficulty = max(0, difficulty - 0.06)
            nextReviewAt = now.addingTimeInterval(7 * 24 * 60 * 60)
        }
    }
}

struct UserLearningState: Codable, Equatable, Sendable {
    var seenCardIDs: Set<String>
    var answeredCardIDs: Set<String>
    var tooEasyCardIDs: Set<String>
    var itemStates: [String: SRSItemState]
    var preferences: LearningPreferences

    nonisolated init(
        seenCardIDs: Set<String> = [],
        answeredCardIDs: Set<String> = [],
        tooEasyCardIDs: Set<String> = [],
        itemStates: [String: SRSItemState] = [:],
        preferences: LearningPreferences
    ) {
        self.seenCardIDs = seenCardIDs
        self.answeredCardIDs = answeredCardIDs
        self.tooEasyCardIDs = tooEasyCardIDs
        self.itemStates = itemStates
        self.preferences = preferences
    }
}
