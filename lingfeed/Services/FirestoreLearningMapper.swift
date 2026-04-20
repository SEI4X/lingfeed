import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum FirestoreLearningMapperError: Error, Equatable {
    case missingField(String)
    case invalidField(String)
}

enum FirestoreLearningMapper {
    static func dictionary(from card: LearningCard) -> [String: Any] {
        var data: [String: Any] = [
            "type": card.type.rawValue,
            "context": card.context,
            "prompt": card.prompt,
            "options": card.options,
            "correctAnswer": card.correctAnswer,
            "explanation": card.explanation,
            "chatMessages": card.chatMessages.map(dictionary(from:)),
            "targetItemIDs": card.targetItemIDs,
            "skillTags": card.skillTags,
            "difficulty": card.difficulty
        ]

        data["situation"] = card.situation
        data["missionID"] = card.missionID
        return data
    }

    static func card(id: String, data: [String: Any]) throws -> LearningCard {
        guard let typeRaw = data["type"] as? String else { throw FirestoreLearningMapperError.missingField("type") }
        guard let type = CardType(rawValue: typeRaw) else { throw FirestoreLearningMapperError.invalidField("type") }

        return LearningCard(
            id: id,
            type: type,
            context: try string("context", in: data),
            situation: data["situation"] as? String,
            prompt: try string("prompt", in: data),
            options: data["options"] as? [String] ?? [],
            correctAnswer: try string("correctAnswer", in: data),
            explanation: try string("explanation", in: data),
            chatMessages: try chatMessages(from: data["chatMessages"]),
            targetItemIDs: data["targetItemIDs"] as? [String] ?? [],
            skillTags: data["skillTags"] as? [String] ?? [],
            difficulty: data["difficulty"] as? Int ?? 1,
            missionID: data["missionID"] as? String
        )
    }

    static func dictionary(from item: LearningItem) -> [String: Any] {
        var data: [String: Any] = [
            "kind": item.kind.rawValue,
            "languageCode": item.languageCode,
            "value": item.value,
            "tags": item.tags,
            "level": item.level.rawValue
        ]

        data["translation"] = item.translation
        data["explanation"] = item.explanation
        return data
    }

    static func item(id: String, data: [String: Any]) throws -> LearningItem {
        guard let kindRaw = data["kind"] as? String else { throw FirestoreLearningMapperError.missingField("kind") }
        guard let kind = SRSItemKind(rawValue: kindRaw) else { throw FirestoreLearningMapperError.invalidField("kind") }
        guard let levelRaw = data["level"] as? String else { throw FirestoreLearningMapperError.missingField("level") }
        guard let level = CEFRLevel(rawValue: levelRaw) else { throw FirestoreLearningMapperError.invalidField("level") }

        return LearningItem(
            id: id,
            kind: kind,
            languageCode: try string("languageCode", in: data),
            value: try string("value", in: data),
            translation: data["translation"] as? String,
            explanation: data["explanation"] as? String,
            tags: data["tags"] as? [String] ?? [],
            level: level
        )
    }

    static func dictionary(from state: SRSItemState) -> [String: Any] {
        var data: [String: Any] = [
            "kind": state.kind.rawValue,
            "strength": state.strength,
            "difficulty": state.difficulty,
            "repetitions": state.repetitions,
            "lapses": state.lapses,
            "nextReviewAt": state.nextReviewAt
        ]

        data["lastReviewedAt"] = state.lastReviewedAt
        return data
    }

    static func srsState(itemID: String, data: [String: Any]) throws -> SRSItemState {
        guard let kindRaw = data["kind"] as? String else { throw FirestoreLearningMapperError.missingField("kind") }
        guard let kind = SRSItemKind(rawValue: kindRaw) else { throw FirestoreLearningMapperError.invalidField("kind") }

        return SRSItemState(
            itemID: itemID,
            kind: kind,
            strength: try double("strength", in: data),
            difficulty: try double("difficulty", in: data),
            repetitions: try int("repetitions", in: data),
            lapses: try int("lapses", in: data),
            lastReviewedAt: try optionalDate("lastReviewedAt", in: data),
            nextReviewAt: try date("nextReviewAt", in: data)
        )
    }

    static func dictionary(from preferences: LearningPreferences) -> [String: Any] {
        [
            "targetLanguageCode": preferences.targetLanguageCode,
            "nativeLanguageCode": preferences.nativeLanguageCode,
            "level": preferences.level.rawValue,
            "goal": preferences.goal.rawValue,
            "goals": LearningGoal.rawValues(from: preferences.goals),
            "interests": preferences.interests,
            "dailyMinutes": preferences.dailyMinutes
        ]
    }

    static func preferences(from data: [String: Any], fallback: LearningPreferences) -> LearningPreferences {
        let levelRaw = data["level"] as? String
        let goalRaw = data["goal"] as? String
        let goal = goalRaw.flatMap(LearningGoal.init(rawValue:)) ?? fallback.goal
        let goals = LearningGoal.goals(from: data["goals"] as? [String] ?? [goal.rawValue])

        return LearningPreferences(
            targetLanguageCode: data["targetLanguageCode"] as? String ?? fallback.targetLanguageCode,
            nativeLanguageCode: data["nativeLanguageCode"] as? String ?? fallback.nativeLanguageCode,
            level: levelRaw.flatMap(CEFRLevel.init(rawValue:)) ?? fallback.level,
            goal: goals.first ?? goal,
            goals: goals,
            interests: data["interests"] as? [String] ?? fallback.interests,
            dailyMinutes: data["dailyMinutes"] as? Int ?? fallback.dailyMinutes
        )
    }
}

private extension FirestoreLearningMapper {
    static func dictionary(from message: ChatMessage) -> [String: Any] {
        [
            "id": message.id,
            "text": message.text,
            "isUser": message.isUser
        ]
    }

    static func chatMessages(from value: Any?) throws -> [ChatMessage] {
        guard let dictionaries = value as? [[String: Any]] else { return [] }

        return try dictionaries.map { data in
            ChatMessage(
                id: try string("id", in: data),
                text: try string("text", in: data),
                isUser: data["isUser"] as? Bool ?? false
            )
        }
    }

    static func string(_ key: String, in data: [String: Any]) throws -> String {
        guard let value = data[key] as? String else { throw FirestoreLearningMapperError.missingField(key) }
        return value
    }

    static func double(_ key: String, in data: [String: Any]) throws -> Double {
        if let value = data[key] as? Double { return value }
        if let value = data[key] as? Int { return Double(value) }
        if let value = data[key] as? NSNumber { return value.doubleValue }
        throw FirestoreLearningMapperError.missingField(key)
    }

    static func int(_ key: String, in data: [String: Any]) throws -> Int {
        if let value = data[key] as? Int { return value }
        if let value = data[key] as? Double { return Int(value) }
        if let value = data[key] as? NSNumber { return value.intValue }
        throw FirestoreLearningMapperError.missingField(key)
    }

    static func optionalDate(_ key: String, in data: [String: Any]) throws -> Date? {
        guard let value = data[key] else { return nil }
        return try parseDate(value, key: key)
    }

    static func date(_ key: String, in data: [String: Any]) throws -> Date {
        guard let value = data[key] else { throw FirestoreLearningMapperError.missingField(key) }
        return try parseDate(value, key: key)
    }

    static func parseDate(_ value: Any, key: String) throws -> Date {
        if let date = value as? Date { return date }

        #if canImport(FirebaseFirestore)
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        #endif

        throw FirestoreLearningMapperError.invalidField(key)
    }
}
