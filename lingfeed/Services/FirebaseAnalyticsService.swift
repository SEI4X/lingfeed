import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

struct CompositeAnalyticsService: AnalyticsService {
    private let services: [any AnalyticsService]

    init(_ services: [any AnalyticsService]) {
        self.services = services
    }

    func track(_ event: AnalyticsEvent) {
        for service in services {
            service.track(event)
        }
    }
}

#if canImport(FirebaseAnalytics)
struct FirebaseAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters.mapValues(\.firebaseValue))
    }
}
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore

final class FirestoreAnalyticsService: AnalyticsService, @unchecked Sendable {
    private let userIDProvider: @Sendable () -> String?
    private let database: Firestore

    init(userIDProvider: @escaping @Sendable () -> String?, database: Firestore = Firestore.firestore()) {
        self.userIDProvider = userIDProvider
        self.database = database
    }

    func track(_ event: AnalyticsEvent) {
        guard let userID = userIDProvider() else { return }
        let data = event.data(createdAt: FieldValue.serverTimestamp())

        Task {
            do {
                try await addDocument(
                    data,
                    to: self.database
                        .collection("users")
                        .document(userID)
                        .collection("events")
                )
                LearningDiagnostics.info("Firestore analytics saved \(event.name) for \(userID)")
            } catch {
                LearningDiagnostics.error("Firestore analytics failed \(event.name): \(error.localizedDescription)")
            }
        }
    }
}

private func addDocument(_ data: [String: Any], to collection: CollectionReference) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        collection.addDocument(data: data) { error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}
#endif
