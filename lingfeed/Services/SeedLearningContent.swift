import Foundation

struct SeedLearningContent: Sendable {
    let cards: [LearningCard]
    let items: [LearningItem]

    static func content(languageCode: String) -> SeedLearningContent {
        if languageCode == "en" {
            return withGoalStarterContent(englishContent(), languageCode: languageCode)
        }
        if languageCode == "es" {
            return withGoalStarterContent(spanishContent(languageCode: languageCode), languageCode: languageCode)
        }
        if let seed = BasicSeed.seed(for: languageCode) {
            return withGoalStarterContent(basicContent(seed), languageCode: languageCode)
        }

        return withGoalStarterContent(englishContent(), languageCode: "en")
    }

    private static func spanishContent(languageCode: String) -> SeedLearningContent {
        let items = [
            LearningItem(id: "\(languageCode)_lexeme_quiero", kind: .lexeme, languageCode: languageCode, value: "quiero", translation: "I want", tags: ["coffee", "ordering"], level: .a1),
            LearningItem(id: "\(languageCode)_lexeme_cafe", kind: .lexeme, languageCode: languageCode, value: "cafe", translation: "coffee", tags: ["coffee"], level: .a1),
            LearningItem(id: "\(languageCode)_phrase_para_llevar", kind: .phrase, languageCode: languageCode, value: "para llevar", translation: "to go", tags: ["coffee", "restaurant"], level: .a1),
            LearningItem(id: "\(languageCode)_grammar_yo_soy", kind: .grammarPattern, languageCode: languageCode, value: "Yo soy estudiante", translation: "I am", tags: ["introductions"], level: .a1),
            LearningItem(id: "\(languageCode)_phrase_gracias", kind: .phrase, languageCode: languageCode, value: "gracias", translation: "thank you", tags: ["chat"], level: .a1)
        ]

        let cards = [
            LearningCard(
                id: "\(languageCode)_coffee_translate_quiero_cafe",
                type: .translate,
                context: "A1 / coffee run",
                situation: "You are ordering at a small cafe.",
                prompt: "I want coffee.",
                correctAnswer: "Quiero cafe",
                explanation: "Quiero means I want.",
                targetItemIDs: ["\(languageCode)_lexeme_quiero", "\(languageCode)_lexeme_cafe"],
                skillTags: ["coffee", "ordering"],
                difficulty: 1,
                missionID: "\(languageCode)_mission_coffee"
            ),
            LearningCard(
                id: "\(languageCode)_coffee_gap_para_llevar",
                type: .fillGap,
                context: "A1 / coffee run",
                situation: "You want the coffee to go.",
                prompt: "Un cafe ___, por favor.",
                options: ["para llevar", "ayer", "azul", "alto"],
                correctAnswer: "para llevar",
                explanation: "Para llevar means to go or takeaway.",
                targetItemIDs: ["\(languageCode)_phrase_para_llevar"],
                skillTags: ["coffee", "restaurant"],
                difficulty: 1,
                missionID: "\(languageCode)_mission_coffee"
            ),
            LearningCard(
                id: "\(languageCode)_intro_fix_yo_soy",
                type: .fixMistake,
                context: "A1 / introductions",
                situation: "You are introducing yourself.",
                prompt: "Исправьте ошибку: Yo es estudiante.",
                correctAnswer: "Yo soy estudiante",
                explanation: "Use soy with yo for identity or profession.",
                targetItemIDs: ["\(languageCode)_grammar_yo_soy"],
                skillTags: ["introductions", "grammar"],
                difficulty: 1,
                missionID: "\(languageCode)_mission_intro"
            ),
            LearningCard(
                id: "\(languageCode)_chat_gracias",
                type: .chat,
                context: "A1 / chat",
                situation: "The barista gives you your coffee.",
                prompt: "Choose the natural reply.",
                options: ["Gracias", "Buenas noches", "Tengo dos", "Hasta ayer"],
                correctAnswer: "Gracias",
                explanation: "Gracias is the direct, natural reply after receiving something.",
                chatMessages: [ChatMessage(text: "Aqui tienes tu cafe.", isUser: false)],
                targetItemIDs: ["\(languageCode)_phrase_gracias"],
                skillTags: ["chat", "coffee"],
                difficulty: 1,
                missionID: "\(languageCode)_mission_coffee"
            )
        ]

        return SeedLearningContent(cards: cards, items: items)
    }

    private struct BasicSeed {
        let code: String
        let coffeeRequest: String
        let coffeeRequestPrompt: String
        let toGo: String
        let toGoPrompt: String
        let toGoOptions: [String]
        let student: String
        let studentMistake: String
        let thankYou: String
        let chatMessage: String

        static func seed(for code: String) -> BasicSeed? {
            seeds[code]
        }

        private static let seeds: [String: BasicSeed] = [
            "de": BasicSeed(code: "de", coffeeRequest: "Ich mochte Kaffee", coffeeRequestPrompt: "Я хочу кофе.", toGo: "zum Mitnehmen", toGoPrompt: "Kaffee ___, bitte.", toGoOptions: ["zum Mitnehmen", "gestern", "blau", "hoch"], student: "Ich bin Student", studentMistake: "Ich ist Student.", thankYou: "Danke", chatMessage: "Hier ist Ihr Kaffee."),
            "fr": BasicSeed(code: "fr", coffeeRequest: "Je veux du cafe", coffeeRequestPrompt: "Я хочу кофе.", toGo: "a emporter", toGoPrompt: "Cafe ___, s'il vous plait.", toGoOptions: ["a emporter", "hier", "bleu", "grand"], student: "Je suis etudiant", studentMistake: "Je est etudiant.", thankYou: "Merci", chatMessage: "Voici votre cafe."),
            "it": BasicSeed(code: "it", coffeeRequest: "Voglio un caffe", coffeeRequestPrompt: "Я хочу кофе.", toGo: "da portare via", toGoPrompt: "Caffe ___, per favore.", toGoOptions: ["da portare via", "ieri", "blu", "alto"], student: "Io sono studente", studentMistake: "Io e studente.", thankYou: "Grazie", chatMessage: "Ecco il tuo caffe."),
            "pt": BasicSeed(code: "pt", coffeeRequest: "Eu quero cafe", coffeeRequestPrompt: "Я хочу кофе.", toGo: "para viagem", toGoPrompt: "Cafe ___, por favor.", toGoOptions: ["para viagem", "ontem", "azul", "alto"], student: "Eu sou estudante", studentMistake: "Eu e estudante.", thankYou: "Obrigado", chatMessage: "Aqui esta o seu cafe."),
            "ja": BasicSeed(code: "ja", coffeeRequest: "コーヒーが欲しいです", coffeeRequestPrompt: "Я хочу кофе.", toGo: "持ち帰り", toGoPrompt: "コーヒーを___でお願いします。", toGoOptions: ["持ち帰り", "昨日", "青い", "高い"], student: "私は学生です", studentMistake: "私は学生ある。", thankYou: "ありがとうございます", chatMessage: "こちらがコーヒーです。"),
            "ko": BasicSeed(code: "ko", coffeeRequest: "커피를 원해요", coffeeRequestPrompt: "Я хочу кофе.", toGo: "테이크아웃", toGoPrompt: "커피 ___ 부탁해요.", toGoOptions: ["테이크아웃", "어제", "파란색", "높은"], student: "저는 학생이에요", studentMistake: "저는 학생이다요.", thankYou: "감사합니다", chatMessage: "여기 커피입니다."),
            "zh-Hans": BasicSeed(code: "zh-Hans", coffeeRequest: "我想要咖啡", coffeeRequestPrompt: "Я хочу кофе.", toGo: "带走", toGoPrompt: "咖啡___，谢谢。", toGoOptions: ["带走", "昨天", "蓝色", "高"], student: "我是学生", studentMistake: "我是一个学生吗。", thankYou: "谢谢", chatMessage: "这是你的咖啡。"),
            "ru": BasicSeed(code: "ru", coffeeRequest: "Я хочу кофе", coffeeRequestPrompt: "I want coffee.", toGo: "с собой", toGoPrompt: "Кофе ___, пожалуйста.", toGoOptions: ["с собой", "вчера", "синий", "высокий"], student: "Я студент", studentMistake: "Я студентом.", thankYou: "Спасибо", chatMessage: "Вот ваш кофе.")
        ]
    }

    private static func basicContent(_ seed: BasicSeed) -> SeedLearningContent {
        let languageCode = seed.code
        let items = [
            LearningItem(id: "\(languageCode)_phrase_coffee_request", kind: .phrase, languageCode: languageCode, value: seed.coffeeRequest, translation: "I want coffee", tags: ["coffee", "ordering"], level: .a1),
            LearningItem(id: "\(languageCode)_phrase_to_go", kind: .phrase, languageCode: languageCode, value: seed.toGo, translation: "to go", tags: ["coffee", "restaurant"], level: .a1),
            LearningItem(id: "\(languageCode)_grammar_i_am_student", kind: .grammarPattern, languageCode: languageCode, value: seed.student, translation: "I am a student", tags: ["introductions", "grammar"], level: .a1),
            LearningItem(id: "\(languageCode)_phrase_thank_you", kind: .phrase, languageCode: languageCode, value: seed.thankYou, translation: "thank you", tags: ["chat"], level: .a1)
        ]

        let cards = [
            LearningCard(id: "\(languageCode)_coffee_translate_i_want_coffee", type: .translate, context: "A1 / coffee run", situation: "Закажите кофе в маленькой кофейне.", prompt: seed.coffeeRequestPrompt, correctAnswer: seed.coffeeRequest, explanation: "\(seed.coffeeRequest) means I want coffee.", targetItemIDs: ["\(languageCode)_phrase_coffee_request"], skillTags: ["coffee", "ordering"], difficulty: 1, missionID: "\(languageCode)_mission_coffee"),
            LearningCard(id: "\(languageCode)_coffee_gap_to_go", type: .fillGap, context: "A1 / coffee run", situation: "Попросите кофе с собой.", prompt: seed.toGoPrompt, options: seed.toGoOptions, correctAnswer: seed.toGo, explanation: "\(seed.toGo) means to go.", targetItemIDs: ["\(languageCode)_phrase_to_go"], skillTags: ["coffee", "restaurant"], difficulty: 1, missionID: "\(languageCode)_mission_coffee"),
            LearningCard(id: "\(languageCode)_intro_fix_i_am", type: .fixMistake, context: "A1 / introductions", situation: "Представьтесь собеседнику.", prompt: "Исправьте ошибку: \(seed.studentMistake)", correctAnswer: seed.student, explanation: "Use the natural pattern: \(seed.student).", targetItemIDs: ["\(languageCode)_grammar_i_am_student"], skillTags: ["introductions", "grammar"], difficulty: 1, missionID: "\(languageCode)_mission_intro"),
            LearningCard(id: "\(languageCode)_chat_thank_you", type: .chat, context: "A1 / chat", situation: "Бариста отдает вам кофе.", prompt: "Choose the natural reply.", options: [seed.thankYou] + Array(seed.toGoOptions.dropFirst().prefix(3)), correctAnswer: seed.thankYou, explanation: "\(seed.thankYou) is the natural reply after receiving something.", chatMessages: [ChatMessage(text: seed.chatMessage, isUser: false)], targetItemIDs: ["\(languageCode)_phrase_thank_you"], skillTags: ["chat", "coffee"], difficulty: 1, missionID: "\(languageCode)_mission_coffee")
        ]

        return SeedLearningContent(cards: cards, items: items)
    }

    private static func englishContent() -> SeedLearningContent {
        let languageCode = "en"
        let items = [
            LearningItem(id: "en_lexeme_i", kind: .lexeme, languageCode: languageCode, value: "I", translation: "я", tags: ["introductions", "grammar"], level: .a1),
            LearningItem(id: "en_lexeme_want", kind: .lexeme, languageCode: languageCode, value: "want", translation: "хотеть", tags: ["coffee", "ordering"], level: .a1),
            LearningItem(id: "en_lexeme_coffee", kind: .lexeme, languageCode: languageCode, value: "coffee", translation: "кофе", tags: ["coffee"], level: .a1),
            LearningItem(id: "en_phrase_to_go", kind: .phrase, languageCode: languageCode, value: "to go", translation: "с собой", tags: ["coffee", "restaurant"], level: .a1),
            LearningItem(id: "en_phrase_thank_you", kind: .phrase, languageCode: languageCode, value: "thank you", translation: "спасибо", tags: ["chat"], level: .a1),
            LearningItem(id: "en_lexeme_student", kind: .lexeme, languageCode: languageCode, value: "student", translation: "студент", tags: ["introductions"], level: .a1),
            LearningItem(id: "en_grammar_i_am_student", kind: .grammarPattern, languageCode: languageCode, value: "I am a student", translation: "я студент", tags: ["introductions", "grammar"], level: .a1)
        ]

        let cards = [
            LearningCard(
                id: "en_coffee_translate_i_want_coffee",
                type: .translate,
                context: "A1 / coffee run",
                situation: "Закажите кофе в маленькой кофейне.",
                prompt: "Я хочу кофе.",
                correctAnswer: "I want coffee",
                explanation: "I want means я хочу.",
                targetItemIDs: ["en_lexeme_i", "en_lexeme_want", "en_lexeme_coffee"],
                skillTags: ["coffee", "ordering"],
                difficulty: 1,
                missionID: "en_mission_coffee"
            ),
            LearningCard(
                id: "en_coffee_gap_to_go",
                type: .fillGap,
                context: "A1 / coffee run",
                situation: "Попросите кофе с собой.",
                prompt: "Coffee ___, please.",
                options: ["to go", "yesterday", "blue", "tall"],
                correctAnswer: "to go",
                explanation: "To go means с собой.",
                targetItemIDs: ["en_phrase_to_go"],
                skillTags: ["coffee", "restaurant"],
                difficulty: 1,
                missionID: "en_mission_coffee"
            ),
            LearningCard(
                id: "en_intro_fix_i_am",
                type: .fixMistake,
                context: "A1 / introductions",
                situation: "Представьтесь собеседнику.",
                prompt: "Исправьте ошибку: I is a student.",
                correctAnswer: "I am a student",
                explanation: "Use am with I.",
                targetItemIDs: ["en_grammar_i_am_student"],
                skillTags: ["introductions", "grammar"],
                difficulty: 1,
                missionID: "en_mission_intro"
            ),
            LearningCard(
                id: "en_chat_thank_you",
                type: .chat,
                context: "A1 / chat",
                situation: "Бариста отдает вам кофе.",
                prompt: "Choose the natural reply.",
                options: ["Thank you", "Good night", "I have two", "Until yesterday"],
                correctAnswer: "Thank you",
                explanation: "Thank you is the natural reply after receiving something.",
                chatMessages: [ChatMessage(text: "Here is your coffee.", isUser: false)],
                targetItemIDs: ["en_phrase_thank_you"],
                skillTags: ["chat", "coffee"],
                difficulty: 1,
                missionID: "en_mission_coffee"
            )
        ]

        return SeedLearningContent(cards: cards, items: items)
    }

    private enum GoalStarter: String, CaseIterable {
        case travel
        case work
        case dating
        case relocation
        case study
        case everyday
    }

    private static let goalMeanings: [GoalStarter: String] = [
        .travel: "У меня бронь.",
        .work: "У меня встреча.",
        .dating: "Приятно познакомиться.",
        .relocation: "Мне нужны документы.",
        .study: "У меня занятие.",
        .everyday: "Где магазин?"
    ]

    private static let goalSituations: [GoalStarter: String] = [
        .travel: "В поездке нужна понятная фраза.",
        .work: "На работе нужна понятная фраза.",
        .dating: "При знакомстве нужен естественный ответ.",
        .relocation: "При оформлении документов нужна понятная фраза.",
        .study: "На учебе нужна понятная фраза.",
        .everyday: "В городе нужна понятная фраза."
    ]

    private static let goalChatMessages: [GoalStarter: String] = [
        .travel: "The receptionist asks what you need.",
        .work: "A coworker asks why you are leaving.",
        .dating: "Someone says: Nice to meet you.",
        .relocation: "The clerk asks what you need.",
        .study: "A classmate asks about your schedule.",
        .everyday: "Someone asks what place you need."
    ]

    private static let goalStarterValues: [String: [GoalStarter: String]] = [
        "en": [.travel: "I have a reservation", .work: "I have a meeting", .dating: "Nice to meet you", .relocation: "I need documents", .study: "I have a class", .everyday: "Where is the store"],
        "es": [.travel: "Tengo una reserva", .work: "Tengo una reunion", .dating: "Encantado de conocerte", .relocation: "Necesito documentos", .study: "Tengo una clase", .everyday: "Donde esta la tienda"],
        "ru": [.travel: "У меня бронь", .work: "У меня встреча", .dating: "Приятно познакомиться", .relocation: "Мне нужны документы", .study: "У меня занятие", .everyday: "Где магазин"],
        "de": [.travel: "Ich habe eine Reservierung", .work: "Ich habe ein Meeting", .dating: "Freut mich", .relocation: "Ich brauche Dokumente", .study: "Ich habe Unterricht", .everyday: "Wo ist der Laden"],
        "fr": [.travel: "J'ai une reservation", .work: "J'ai une reunion", .dating: "Ravi de vous rencontrer", .relocation: "J'ai besoin de documents", .study: "J'ai un cours", .everyday: "Ou est le magasin"],
        "it": [.travel: "Ho una prenotazione", .work: "Ho una riunione", .dating: "Piacere di conoscerti", .relocation: "Ho bisogno di documenti", .study: "Ho una lezione", .everyday: "Dove si trova il negozio"],
        "pt": [.travel: "Tenho uma reserva", .work: "Tenho uma reuniao", .dating: "Prazer em conhecer voce", .relocation: "Preciso de documentos", .study: "Tenho uma aula", .everyday: "Onde fica a loja"],
        "ja": [.travel: "予約があります", .work: "会議があります", .dating: "はじめまして", .relocation: "書類が必要です", .study: "授業があります", .everyday: "店はどこですか"],
        "ko": [.travel: "예약이 있어요", .work: "회의가 있어요", .dating: "만나서 반가워요", .relocation: "서류가 필요해요", .study: "수업이 있어요", .everyday: "가게가 어디예요"],
        "zh-Hans": [.travel: "我有预订", .work: "我有会议", .dating: "很高兴认识你", .relocation: "我需要文件", .study: "我有课", .everyday: "商店在哪里"]
    ]

    private static func withGoalStarterContent(_ content: SeedLearningContent, languageCode: String) -> SeedLearningContent {
        guard let goalValues = goalStarterValues[languageCode] else { return content }

        let goalItems = GoalStarter.allCases.map { goal in
            LearningItem(
                id: "\(languageCode)_goal_\(goal.rawValue)",
                kind: .phrase,
                languageCode: languageCode,
                value: goalValues[goal] ?? "",
                translation: goalMeanings[goal],
                tags: [goal.rawValue, "goal_starter"],
                level: .a1
            )
        }

        let goalCards = GoalStarter.allCases.flatMap { goal -> [LearningCard] in
            let value = goalValues[goal] ?? ""
            let options = Array(unique([value] + GoalStarter.allCases.filter { $0 != goal }.compactMap { goalValues[$0] }).prefix(4))
            let itemID = "\(languageCode)_goal_\(goal.rawValue)"
            return [
                LearningCard(
                    id: "\(languageCode)_goal_\(goal.rawValue)_translate",
                    type: .translate,
                    context: "A1 / \(goal.rawValue)",
                    situation: goalSituations[goal],
                    prompt: goalMeanings[goal] ?? "",
                    correctAnswer: value,
                    explanation: "\(value) = \(goalMeanings[goal] ?? "")",
                    targetItemIDs: [itemID],
                    skillTags: [goal.rawValue, "goal_starter"],
                    difficulty: 1,
                    missionID: goal.rawValue
                ),
                LearningCard(
                    id: "\(languageCode)_goal_\(goal.rawValue)_choice",
                    type: .multipleChoice,
                    context: "A1 / \(goal.rawValue)",
                    situation: goalSituations[goal],
                    prompt: "Выберите фразу: \(goalMeanings[goal] ?? "")",
                    options: options,
                    correctAnswer: value,
                    explanation: "\(value) = \(goalMeanings[goal] ?? "")",
                    targetItemIDs: [itemID],
                    skillTags: [goal.rawValue, "goal_starter"],
                    difficulty: 1,
                    missionID: goal.rawValue
                ),
                LearningCard(
                    id: "\(languageCode)_goal_\(goal.rawValue)_chat",
                    type: .chat,
                    context: "A1 / \(goal.rawValue)",
                    situation: goalSituations[goal],
                    prompt: "Choose the phrase for this situation.",
                    options: options,
                    correctAnswer: value,
                    explanation: "\(value) = \(goalMeanings[goal] ?? "")",
                    chatMessages: [ChatMessage(text: goalChatMessages[goal] ?? "", isUser: false)],
                    targetItemIDs: [itemID],
                    skillTags: [goal.rawValue, "goal_starter"],
                    difficulty: 1,
                    missionID: goal.rawValue
                )
            ]
        }

        return SeedLearningContent(cards: goalCards + content.cards, items: content.items + goalItems)
    }

    private static func unique(_ values: [String]) -> [String] {
        Array(NSOrderedSet(array: values).compactMap { $0 as? String })
    }
}
