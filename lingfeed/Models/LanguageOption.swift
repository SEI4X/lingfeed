import Foundation

struct LanguageOption: Identifiable, Equatable, Sendable {
    let code: String
    let titleKey: String
    let nativeName: String
    let sample: String

    var id: String { code }

    nonisolated init(code: String, titleKey: String, nativeName: String, sample: String) {
        self.code = code
        self.titleKey = titleKey
        self.nativeName = nativeName
        self.sample = sample
    }

    static let all: [LanguageOption] = [
        .init(code: "es", titleKey: "language.spanish", nativeName: "Español", sample: "Hola"),
        .init(code: "fr", titleKey: "language.french", nativeName: "Français", sample: "Salut"),
        .init(code: "de", titleKey: "language.german", nativeName: "Deutsch", sample: "Hallo"),
        .init(code: "it", titleKey: "language.italian", nativeName: "Italiano", sample: "Ciao"),
        .init(code: "pt", titleKey: "language.portuguese", nativeName: "Português", sample: "Ola"),
        .init(code: "ja", titleKey: "language.japanese", nativeName: "日本語", sample: "Konnichiwa"),
        .init(code: "ko", titleKey: "language.korean", nativeName: "한국어", sample: "Annyeong"),
        .init(code: "zh-Hans", titleKey: "language.chinese", nativeName: "中文", sample: "Ni hao"),
        .init(code: "ru", titleKey: "language.russian", nativeName: "Русский", sample: "Privet"),
        .init(code: "en", titleKey: "language.english", nativeName: "English", sample: "Hello")
    ]

    static let nativeChoices = all
    static let learningChoices = all
    static let `default` = LanguageOption.all[0]
    static let fallbackNativeCode = "en"

    static func option(for code: String) -> LanguageOption {
        all.first { $0.code == code } ?? all.first { $0.code == fallbackNativeCode } ?? .default
    }

    static func supportedCode(forPreferredLanguages preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        for preferredLanguage in preferredLanguages {
            let normalized = preferredLanguage.replacingOccurrences(of: "_", with: "-")
            if all.contains(where: { $0.code == normalized }) {
                return normalized
            }

            if normalized.hasPrefix("zh-Hans") {
                return "zh-Hans"
            }

            if let baseCode = normalized.split(separator: "-").first.map(String.init),
               all.contains(where: { $0.code == baseCode }) {
                return baseCode
            }
        }

        return fallbackNativeCode
    }
}
