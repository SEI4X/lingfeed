import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseFirestore)
final class FirestoreLearningContentStore: LearningContentStore, @unchecked Sendable {
    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func seedIfNeeded(languageCode: String, cards: [LearningCard], items: [LearningItem]) async throws {
        // Global content is seeded by the backend/admin script. The app only reads it.
        LearningDiagnostics.info("Firestore seedIfNeeded skipped for \(languageCode)")
    }

    func loadActiveCards(languageCode: String) async throws -> [LearningCard] {
        LearningDiagnostics.info("Firestore loading active cards for \(languageCode)")
        let snapshot = try await documents(
            for: database.collection("cards")
                .whereField("languageCode", isEqualTo: languageCode)
                .whereField("status", isEqualTo: "active")
        )

        LearningDiagnostics.info("Firestore active cards snapshot \(snapshot.documents.count)")
        return try snapshot.documents.map { document in
            try FirestoreLearningMapper.card(id: document.documentID, data: document.data())
        }
    }

    func loadLearningItems(languageCode: String) async throws -> [LearningItem] {
        LearningDiagnostics.info("Firestore loading learning items for \(languageCode)")
        let snapshot = try await documents(
            for: database.collection("learning_items")
                .whereField("languageCode", isEqualTo: languageCode)
        )

        LearningDiagnostics.info("Firestore learning items snapshot \(snapshot.documents.count)")
        return try snapshot.documents.map { document in
            try FirestoreLearningMapper.item(id: document.documentID, data: document.data())
        }
    }

    func saveGeneratedCards(languageCode: String, cards: [LearningCard]) async throws {
        // Generated global content is written by Cloud Functions with Admin SDK.
    }
}

final class FirestoreUserLearningStateStore: UserLearningStateStore, @unchecked Sendable {
    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func loadState(userID: String, preferences fallbackPreferences: LearningPreferences) async throws -> UserLearningState {
        LearningDiagnostics.info("Firestore loading user state for \(userID)")
        let profileDocument = userLearningDocument(userID: userID)
        let profileSnapshot = try await getDocument(profileDocument)
        let profileData = profileSnapshot.data() ?? [:]
        let preferencesData = profileData["preferences"] as? [String: Any] ?? [:]
        let preferences = FirestoreLearningMapper.preferences(from: preferencesData, fallback: fallbackPreferences)

        let itemStatesSnapshot = try await documents(for: userItemStatesCollection(userID: userID))
        LearningDiagnostics.info("Firestore user item states snapshot \(itemStatesSnapshot.documents.count)")
        let itemStates = Dictionary(
            uniqueKeysWithValues: try itemStatesSnapshot.documents.map { document in
                (
                    document.documentID,
                    try FirestoreLearningMapper.srsState(itemID: document.documentID, data: document.data())
                )
            }
        )

        return UserLearningState(
            seenCardIDs: Set(profileData["seenCardIDs"] as? [String] ?? []),
            answeredCardIDs: Set(profileData["answeredCardIDs"] as? [String] ?? []),
            tooEasyCardIDs: Set(profileData["tooEasyCardIDs"] as? [String] ?? []),
            itemStates: itemStates,
            preferences: preferences
        )
    }

    func saveState(_ state: UserLearningState, userID: String) async throws {
        LearningDiagnostics.info("Firestore saving state for \(userID): seen \(state.seenCardIDs.count), answered \(state.answeredCardIDs.count), itemStates \(state.itemStates.count)")
        let batch = database.batch()
        batch.setData(
            [
                "seenCardIDs": Array(state.seenCardIDs),
                "answeredCardIDs": Array(state.answeredCardIDs),
                "tooEasyCardIDs": Array(state.tooEasyCardIDs),
                "preferences": FirestoreLearningMapper.dictionary(from: state.preferences),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            forDocument: userLearningDocument(userID: userID),
            merge: true
        )

        let itemStatesCollection = userItemStatesCollection(userID: userID)
        for state in state.itemStates.values {
            batch.setData(
                FirestoreLearningMapper.dictionary(from: state),
                forDocument: itemStatesCollection.document(state.itemID),
                merge: true
            )
        }

        try await commit(batch)
        LearningDiagnostics.info("Firestore saved state for \(userID)")
    }

    private func userLearningDocument(userID: String) -> DocumentReference {
        database.collection("users").document(userID).collection("learning").document("state")
    }

    private func userItemStatesCollection(userID: String) -> CollectionReference {
        database.collection("users").document(userID).collection("learning_item_states")
    }
}

private func getDocument(_ reference: DocumentReference) async throws -> DocumentSnapshot {
    try await withCheckedThrowingContinuation { continuation in
        reference.getDocument { snapshot, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let snapshot {
                continuation.resume(returning: snapshot)
            } else {
                continuation.resume(throwing: LearningBackendError.missingSession)
            }
        }
    }
}

private func documents(for query: Query) async throws -> QuerySnapshot {
    try await withCheckedThrowingContinuation { continuation in
        query.getDocuments { snapshot, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let snapshot {
                continuation.resume(returning: snapshot)
            } else {
                continuation.resume(throwing: LearningBackendError.missingSession)
            }
        }
    }
}

private func commit(_ batch: WriteBatch) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        batch.commit { error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}
#endif
