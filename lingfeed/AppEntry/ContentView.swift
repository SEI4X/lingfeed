import SwiftUI

struct ContentView: View {
    let container: AppContainer

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("targetLanguageCode") private var targetLanguageCode = LanguageOption.default.code
    @AppStorage("nativeLanguageCode") private var nativeLanguageCode = Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "en"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                FeedView(
                    viewModel: container.makeFeedViewModel(languageCode: targetLanguageCode),
                    targetLanguageCode: targetLanguageCode,
                    nativeLanguageCode: $nativeLanguageCode,
                    notificationsEnabled: $notificationsEnabled,
                    onChangeLanguage: {
                        hasCompletedOnboarding = false
                    }
                )
                .id(targetLanguageCode)
            } else {
                OnboardingView(selectedLanguageCode: targetLanguageCode) { language in
                    targetLanguageCode = language.code
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    ContentView(container: .preview)
}
