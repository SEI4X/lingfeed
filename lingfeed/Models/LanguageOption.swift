import Foundation

struct LanguageOption: Identifiable, Equatable, Sendable {
    let code: String
    let titleKey: String
    let sample: String

    var id: String { code }

    nonisolated init(code: String, titleKey: String, sample: String) {
        self.code = code
        self.titleKey = titleKey
        self.sample = sample
    }

    static let all: [LanguageOption] = [
        .init(code: "es", titleKey: "language.spanish", sample: "Hola"),
        .init(code: "fr", titleKey: "language.french", sample: "Salut"),
        .init(code: "de", titleKey: "language.german", sample: "Hallo"),
        .init(code: "it", titleKey: "language.italian", sample: "Ciao"),
        .init(code: "pt", titleKey: "language.portuguese", sample: "Ola"),
        .init(code: "ja", titleKey: "language.japanese", sample: "Konnichiwa"),
        .init(code: "ko", titleKey: "language.korean", sample: "Annyeong"),
        .init(code: "zh-Hans", titleKey: "language.chinese", sample: "Ni hao"),
        .init(code: "ru", titleKey: "language.russian", sample: "Privet"),
        .init(code: "en", titleKey: "language.english", sample: "Hello")
    ]

    static let `default` = LanguageOption.all[0]

    static func option(for code: String) -> LanguageOption {
        all.first { $0.code == code } ?? .default
    }
}
