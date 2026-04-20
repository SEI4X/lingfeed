import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct lingfeedApp: App {
    private let container: AppContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if ProcessInfo.processInfo.environment["LINGFEED_UI_TEST_FEED_READY"] == "1" || arguments.contains("--ui-test-feed-ready") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set("es", forKey: "targetLanguageCode")
            UserDefaults.standard.set("en", forKey: "nativeLanguageCode")
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif

        container = AppContainer.live()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
