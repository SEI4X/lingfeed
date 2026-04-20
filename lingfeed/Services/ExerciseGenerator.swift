import Foundation

protocol ExerciseGenerator: Sendable {
    func generateCards(
        languageCode: String,
        items: [LearningItem],
        userState: UserLearningState,
        existingCardIDs: Set<String>,
        limit: Int
    ) -> [LearningCard]
}

struct RuleBasedExerciseGenerator: ExerciseGenerator {
    func generateCards(
        languageCode: String,
        items: [LearningItem],
        userState: UserLearningState,
        existingCardIDs: Set<String>,
        limit: Int
    ) -> [LearningCard] {
        guard limit > 0 else { return [] }

        var generated: [LearningCard] = []
        let rankedItems = items
            .filter { $0.languageCode == languageCode }
            .sorted { lhs, rhs in
                let lhsScore = score(item: lhs, userState: userState)
                let rhsScore = score(item: rhs, userState: userState)
                if lhsScore == rhsScore { return lhs.id < rhs.id }
                return lhsScore > rhsScore
            }

        for item in rankedItems {
            for card in templates(for: item, userState: userState, existingCardIDs: existingCardIDs.union(generated.map(\.id)), allItems: rankedItems) {
                generated.append(card)
                if generated.count == limit { return generated }
            }
        }

        return generated
    }

    private func score(item: LearningItem, userState: UserLearningState) -> Double {
        let state = userState.itemStates[item.id]
        var score = 10.0
        if state == nil { score += 20 }
        if let state, state.nextReviewAt <= Date() { score += 40 }
        if let state { score += (1 - state.strength) * 20 }
        score += Double(item.tags.filter { userState.preferences.interests.contains($0) }.count) * 5
        return score
    }

    private func templates(
        for item: LearningItem,
        userState: UserLearningState,
        existingCardIDs: Set<String>,
        allItems: [LearningItem]
    ) -> [LearningCard] {
        let variant = nextVariant(for: item.id, existingCardIDs: existingCardIDs)
        let context = "\(item.level.rawValue) / \(item.tags.first ?? item.kind.rawValue)"
        let primaryGoal = userState.preferences.goals.first ?? userState.preferences.goal
        let explorationGoal = LearningGoal.allCases.first { !userState.preferences.goals.contains($0) } ?? primaryGoal
        let primarySituation = situation(for: item, goal: primaryGoal)
        let explorationSituation = situation(for: item, goal: explorationGoal)
        let explanation = item.explanation ?? explanationFallback(for: item)
        let difficulty = max(1, min(5, item.levelDifficulty + Int((userState.itemStates[item.id]?.difficulty ?? 0.5) * 2)))

        var cards: [LearningCard] = [
            LearningCard(
                id: "gen-\(item.languageCode)-\(item.id)-translate-\(variant)",
                type: .translate,
                context: context,
                situation: primarySituation,
                prompt: translatePrompt(for: item),
                correctAnswer: item.value,
                explanation: explanation,
                targetItemIDs: [item.id],
                skillTags: item.tags,
                difficulty: difficulty,
                missionID: primaryGoal.rawValue
            )
        ]

        if let chat = chatCard(
            for: item,
            context: context,
            situation: primarySituation,
            explanation: explanation,
            options: choiceOptions(for: item, allItems: allItems),
            difficulty: difficulty,
            missionID: primaryGoal.rawValue,
            variant: variant
        ) {
            cards.append(chat)
        }

        cards.append(
            LearningCard(
                id: "gen-\(item.languageCode)-\(item.id)-choice-\(variant)",
                type: .multipleChoice,
                context: context,
                situation: primarySituation,
                prompt: multipleChoicePrompt(for: item),
                options: choiceOptions(for: item, allItems: allItems),
                correctAnswer: item.value,
                explanation: explanation,
                targetItemIDs: [item.id],
                skillTags: item.tags,
                difficulty: difficulty,
                missionID: primaryGoal.rawValue
            )
        )

        if let gap = gapPrompt(for: item.value, allItems: allItems) {
            cards.append(
                LearningCard(
                    id: "gen-\(item.languageCode)-\(item.id)-fill-\(variant)",
                    type: .fillGap,
                    context: context,
                    situation: primarySituation,
                    prompt: gap.prompt,
                    options: gap.options,
                    correctAnswer: gap.answer,
                    explanation: explanation,
                    targetItemIDs: [item.id],
                    skillTags: item.tags,
                    difficulty: difficulty,
                    missionID: primaryGoal.rawValue
                )
            )
        }

        if let reorder = reorderOptions(for: item.value) {
            cards.append(
                LearningCard(
                    id: "gen-\(item.languageCode)-\(item.id)-reorder-\(variant)",
                    type: .reorder,
                    context: context,
                    situation: explorationSituation,
                    prompt: "Build the sentence: \(item.translation ?? item.value)",
                    options: reorder,
                    correctAnswer: item.value,
                    explanation: explanation,
                    targetItemIDs: [item.id],
                    skillTags: item.tags,
                    difficulty: difficulty,
                    missionID: explorationGoal.rawValue
                )
            )
        }

        if let mistake = mistakePrompt(for: item.value) {
            cards.append(
                LearningCard(
                    id: "gen-\(item.languageCode)-\(item.id)-fix-\(variant)",
                    type: .fixMistake,
                    context: context,
                    situation: primarySituation,
                    prompt: "Fix the sentence: \(mistake)",
                    correctAnswer: item.value,
                    explanation: explanation,
                    targetItemIDs: [item.id],
                    skillTags: item.tags,
                    difficulty: difficulty,
                    missionID: primaryGoal.rawValue
                )
            )
        }

        return cards.filter { !existingCardIDs.contains($0.id) }
    }

    private func nextVariant(for itemID: String, existingCardIDs: Set<String>) -> Int {
        let prefix = "gen-"
        let variants = existingCardIDs.compactMap { id -> Int? in
            guard id.hasPrefix(prefix), id.contains("-\(itemID)-") else { return nil }
            return Int(id.split(separator: "-").last ?? "")
        }
        return (variants.max() ?? 0) + 1
    }

    private func translatePrompt(for item: LearningItem) -> String {
        guard let translation = item.translation, !translation.isEmpty else {
            return "Use: \(item.value)"
        }
        return translation
    }

    private func multipleChoicePrompt(for item: LearningItem) -> String {
        guard let translation = item.translation, !translation.isEmpty else {
            return "Choose the phrase: \(item.value)"
        }
        return "Which phrase means: \(translation)?"
    }

    private func choiceOptions(for item: LearningItem, allItems: [LearningItem]) -> [String] {
        var options = [item.value]
        options.append(contentsOf: allItems.filter { $0.id != item.id && $0.languageCode == item.languageCode }.map(\.value))
        return Array(NSOrderedSet(array: options).compactMap { $0 as? String }.prefix(4))
    }

    private func chatCard(
        for item: LearningItem,
        context: String,
        situation: String,
        explanation: String,
        options: [String],
        difficulty: Int,
        missionID: String,
        variant: Int
    ) -> LearningCard? {
        guard item.kind != .lexeme else { return nil }
        guard item.tags.contains("chat") || item.tags.contains("small_talk") else { return nil }
        guard options.count >= 2, options.contains(item.value) else { return nil }

        return LearningCard(
            id: "gen-\(item.languageCode)-\(item.id)-chat-\(variant)",
            type: .chat,
            context: context,
            situation: situation,
            prompt: "Choose the natural reply.",
            options: options,
            correctAnswer: item.value,
            explanation: explanation,
            chatMessages: [
                ChatMessage(text: chatPrompt(for: item), isUser: false)
            ],
            targetItemIDs: [item.id],
            skillTags: item.tags,
            difficulty: difficulty,
            missionID: missionID
        )
    }

    private func gapPrompt(for value: String, allItems: [LearningItem]) -> (prompt: String, answer: String, options: [String])? {
        let parts = value.split(separator: " ").map(String.init)
        guard parts.count > 1, let last = parts.last else { return nil }
        let options = gapOptions(answer: last, allItems: allItems)
        guard options.count >= 2 else { return nil }
        let stem = parts.dropLast().joined(separator: " ")
        return ("\(stem) ____", last, options)
    }

    private func gapOptions(answer: String, allItems: [LearningItem]) -> [String] {
        var options = [answer]
        options.append(contentsOf: allItems.compactMap { item in
            item.value.split(separator: " ").last.map(String.init)
        }.filter { normalizedToken($0) != normalizedToken(answer) && !normalizedToken($0).isEmpty })
        return Array(NSOrderedSet(array: options).compactMap { $0 as? String }.prefix(4))
    }

    private func reorderOptions(for value: String) -> [String]? {
        let parts = value.split(separator: " ").map(String.init)
        guard parts.count > 1 else { return nil }
        return parts.sorted(by: >)
    }

    private func mistakePrompt(for value: String) -> String? {
        let replacements = [
            ("soy", "es"),
            ("tengo", "tiene"),
            ("estoy", "es"),
            ("quiero", "quiere")
        ]

        for (source, replacement) in replacements where value.localizedCaseInsensitiveContains(source) {
            return value.replacingOccurrences(of: source, with: replacement, options: [.caseInsensitive])
        }

        return nil
    }

    private func chatPrompt(for item: LearningItem) -> String {
        if item.tags.contains("coffee") { return "Para tomar aqui o para llevar?" }
        if item.tags.contains("small_talk") { return "Hola, como estas?" }
        if item.tags.contains("chat") { return "Nice to meet you." }
        return item.translation ?? item.value
    }

    private func situation(for item: LearningItem, goal: LearningGoal) -> String {
        if item.tags.contains("coffee") { return "You are ordering coffee." }
        if item.tags.contains("restaurant") { return "You are speaking with a waiter." }
        switch goal {
        case .travel: return "You are traveling and need a quick phrase."
        case .work: return "You are speaking at work."
        case .dating: return "You are keeping a conversation warm."
        case .relocation: return "You are handling daily life."
        case .study: return "You are practicing for class."
        case .everyday: return "You are in a normal daily conversation."
        }
    }

    private func explanationFallback(for item: LearningItem) -> String {
        if let translation = item.translation {
            return "\(item.value) means \(translation)."
        }
        return "Use this phrase as a natural answer in context."
    }

    private func normalizedToken(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension LearningItem {
    var levelDifficulty: Int {
        switch level {
        case .a1: 1
        case .a2: 2
        case .b1: 3
        case .b2: 4
        case .c1, .c2: 5
        }
    }
}
