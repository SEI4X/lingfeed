import Foundation

struct AppContainer {
    let authService: AuthService
    let cardService: CardService
    let sessionService: SessionService

    @MainActor
    func makeFeedViewModel(languageCode: String) -> FeedViewModel {
        FeedViewModel(
            languageCode: languageCode,
            authService: authService,
            cardService: cardService,
            sessionService: sessionService
        )
    }

    static func live() -> AppContainer {
        let backend = MockLanguageBackend()
        return AppContainer(
            authService: MockAuthService(),
            cardService: MockCardService(backend: backend),
            sessionService: MockSessionService(backend: backend)
        )
    }

    static let preview = AppContainer.live()
}
