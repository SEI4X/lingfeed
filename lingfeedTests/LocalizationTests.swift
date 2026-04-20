import XCTest
@testable import lingfeed

final class LocalizationTests: XCTestCase {
    private let languageCodes = ["es", "fr", "de", "it", "pt", "ja", "ko", "zh-Hans", "ru", "en"]

    func testSupportedLanguagesAreTheSingleSourceForNativeAndTargetLanguageChoices() {
        XCTAssertEqual(LanguageOption.all.map(\.code), languageCodes)
        XCTAssertEqual(LanguageOption.nativeChoices.map(\.code), languageCodes)
        XCTAssertEqual(LanguageOption.learningChoices.map(\.code), languageCodes)
        XCTAssertEqual(Set(LanguageOption.all.map(\.code)).count, 10)
    }

    func testPreferredLanguageFallsBackToSupportedBaseLanguage() {
        XCTAssertEqual(LanguageOption.supportedCode(forPreferredLanguages: ["ru-TH", "en-US"]), "ru")
        XCTAssertEqual(LanguageOption.supportedCode(forPreferredLanguages: ["zh-Hans-US", "en-US"]), "zh-Hans")
        XCTAssertEqual(LanguageOption.supportedCode(forPreferredLanguages: ["nl-NL", "en-US"]), "en")
        XCTAssertEqual(LanguageOption.supportedCode(forPreferredLanguages: ["nl-NL"]), "en")
    }

    func testAppLocalizationUsesSelectedNativeLanguage() {
        let localization = AppLocalization(languageCode: "ru")

        XCTAssertEqual(localization.string("feed.streak"), "серия")
        XCTAssertEqual(localization.string("action.check"), "Проверить")
    }

    func testEveryLocalizationFileContainsTheSameKeysAsEnglish() throws {
        let englishKeys = try localizedKeys(for: "en")

        for languageCode in languageCodes {
            XCTAssertEqual(try localizedKeys(for: languageCode), englishKeys, "Mismatched Localizable.strings keys for \(languageCode)")
        }
    }

    func testKnownLocalizationKeysResolveFromLocalizableStrings() throws {
        for key in try localizedKeys(for: "en") {
            let value = NSLocalizedString(key, bundle: .main, comment: "")
            XCTAssertNotEqual(value, key)
            XCTAssertFalse(value.isEmpty)
        }
    }

    private func localizedKeys(for languageCode: String) throws -> Set<String> {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: "\(languageCode).lproj"
            ),
            "Missing Localizable.strings for \(languageCode)"
        )
        let dictionary = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return Set(dictionary.keys)
    }
}
