import SwiftUI

struct ContentView: View {
    let container: AppContainer

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("targetLanguageCode") private var targetLanguageCode = LanguageOption.default.code
    @AppStorage("nativeLanguageCode") private var nativeLanguageCode = LanguageOption.supportedCode()
    @AppStorage("learningGoalCodes") private var learningGoalCodes = LearningGoal.defaultGoals.map(\.rawValue).joined(separator: ",")
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                FeedView(
                    viewModel: container.makeFeedViewModel(
                        targetLanguageCode: targetLanguageCode,
                        nativeLanguageCode: nativeLanguageCode,
                        learningGoals: selectedLearningGoals
                    ),
                    targetLanguageCode: $targetLanguageCode,
                    nativeLanguageCode: $nativeLanguageCode,
                    learningGoalCodes: $learningGoalCodes,
                    notificationsEnabled: $notificationsEnabled,
                    onChangeLanguage: {
                        hasCompletedOnboarding = false
                    }
                )
                .id("\(targetLanguageCode)-\(nativeLanguageCode)-\(learningGoalCodes)")
            } else {
                OnboardingView(
                    selectedNativeLanguageCode: nativeLanguageCode,
                    selectedTargetLanguageCode: targetLanguageCode,
                    selectedLearningGoals: selectedLearningGoals
                ) { nativeLanguage, targetLanguage, learningGoals in
                    nativeLanguageCode = nativeLanguage.code
                    targetLanguageCode = targetLanguage.code
                    learningGoalCodes = LearningGoal.rawValues(from: learningGoals).joined(separator: ",")
                    hasCompletedOnboarding = true
                }
            }
        }
        .environment(\.locale, Locale(identifier: nativeLanguageCode))
    }

    private var selectedLearningGoals: [LearningGoal] {
        LearningGoal.goals(from: learningGoalCodes.split(separator: ",").map(String.init))
    }
}

#Preview {
    ContentView(container: .preview)
}
