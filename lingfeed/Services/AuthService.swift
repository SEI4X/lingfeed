import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

protocol AuthService {
    func signInAnonymously() async throws -> UserIdentity
}

struct MockAuthService: AuthService {
    func signInAnonymously() async throws -> UserIdentity {
        UserIdentity(id: "anon-\(UUID().uuidString.prefix(8))", isAnonymous: true)
    }
}

#if canImport(FirebaseAuth)
struct FirebaseAuthService: AuthService {
    func signInAnonymously() async throws -> UserIdentity {
        if let user = Auth.auth().currentUser {
            LearningDiagnostics.info("Auth reused anonymous user \(user.uid)")
            return UserIdentity(id: user.uid, isAnonymous: user.isAnonymous)
        }

        LearningDiagnostics.info("Auth signing in anonymously")
        let result = try await Auth.auth().signInAnonymously()
        LearningDiagnostics.info("Auth signed in anonymous user \(result.user.uid)")
        return UserIdentity(id: result.user.uid, isAnonymous: result.user.isAnonymous)
    }
}
#endif
