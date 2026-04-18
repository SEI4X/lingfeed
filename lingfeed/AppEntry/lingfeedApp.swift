import SwiftUI

@main
struct lingfeedApp: App {
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
