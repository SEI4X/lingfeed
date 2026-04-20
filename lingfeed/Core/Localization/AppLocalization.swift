import Foundation

struct AppLocalization: Sendable {
    let languageCode: String

    init(languageCode: String = UserDefaults.standard.string(forKey: "nativeLanguageCode") ?? LanguageOption.supportedCode()) {
        self.languageCode = LanguageOption.option(for: languageCode).code
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        formatted(key, arguments: arguments)
    }

    func formatted(_ key: String, arguments: [CVarArg]) -> String {
        String(format: string(key), arguments: arguments)
    }

    static func string(_ key: String) -> String {
        AppLocalization().string(key)
    }

    static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization().formatted(key, arguments: arguments)
    }

    private var bundle: Bundle {
        guard
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}
