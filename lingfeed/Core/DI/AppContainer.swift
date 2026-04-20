import Foundation

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseAnalytics) && canImport(FirebaseFunctions)
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
#endif

struct AppContainer {
    let authService: AuthService
    let cardService: CardService
    let sessionService: SessionService

    @MainActor
    func makeFeedViewModel(targetLanguageCode: String, nativeLanguageCode: String, learningGoals: [LearningGoal]) -> FeedViewModel {
        FeedViewModel(
            languageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            learningGoals: learningGoals,
            authService: authService,
            cardService: cardService,
            sessionService: sessionService
        )
    }

    static func live() -> AppContainer {
        if ProcessInfo.processInfo.environment["LINGFEED_USE_MOCK_BACKEND"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--use-mock-backend") {
            return preview
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseAnalytics) && canImport(FirebaseFunctions)
        let functions = Functions.functions(region: "us-central1")

        return AppContainer(
            authService: FirebaseAuthService(),
            cardService: CloudCardInteractionService(functions: functions),
            sessionService: CloudSessionService(functions: functions)
        )
        #else
        let backend = MockLanguageBackend()
        return AppContainer(
            authService: MockAuthService(),
            cardService: MockCardService(backend: backend),
            sessionService: MockSessionService(backend: backend)
        )
        #endif
    }

    static let preview: AppContainer = {
        let backend = MockLanguageBackend()
        return AppContainer(
            authService: MockAuthService(),
            cardService: MockCardService(backend: backend),
            sessionService: MockSessionService(backend: backend)
        )
    }()
}
