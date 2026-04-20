import Foundation

struct CardScorer: Sendable {
    func score(card: LearningCard, userState: UserLearningState, now: Date) -> Double {
        var score = 0.0

        if card.targetItemIDs.contains(where: { itemID in
            guard let state = userState.itemStates[itemID] else { return false }
            return state.nextReviewAt <= now
        }) {
            score += 40
        }

        if card.targetItemIDs.contains(where: { itemID in
            guard let state = userState.itemStates[itemID] else { return false }
            return state.strength < 0.45
        }) {
            score += 14
        }

        if !card.skillTags.isEmpty {
            let interestMatches = Set(card.skillTags).intersection(userState.preferences.interests)
            score += Double(interestMatches.count) * 5
        }

        if let missionID = card.missionID {
            if userState.preferences.goals.contains(where: { $0.rawValue == missionID }) {
                score += 45
            } else {
                score -= 20
            }
        }

        if userState.seenCardIDs.contains(card.id) {
            score -= 8
        } else {
            score += 4
        }

        if userState.answeredCardIDs.contains(card.id) {
            score -= 20
        }

        if userState.tooEasyCardIDs.contains(card.id) {
            score -= 50
        }

        score -= abs(Double(card.difficulty) - desiredDifficulty(for: userState)) * 2
        return score
    }

    private func desiredDifficulty(for userState: UserLearningState) -> Double {
        switch userState.preferences.level {
        case .a1: 1
        case .a2: 2
        case .b1: 3
        case .b2: 4
        case .c1, .c2: 5
        }
    }
}

struct FeedComposer: Sendable {
    let scorer: CardScorer

    nonisolated init(scorer: CardScorer) {
        self.scorer = scorer
    }

    func compose(
        candidates: [LearningCard],
        userState: UserLearningState,
        now: Date,
        limit: Int
    ) -> [LearningCard] {
        candidates
            .map { card in
                (card: card, score: scorer.score(card: card, userState: userState, now: now))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.card.id < rhs.card.id
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map(\.card)
    }
}
