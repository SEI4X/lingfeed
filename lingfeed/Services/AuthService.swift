import Foundation

protocol AuthService {
    func signInAnonymously() async throws -> UserIdentity
}

struct MockAuthService: AuthService {
    func signInAnonymously() async throws -> UserIdentity {
        UserIdentity(id: "anon-\(UUID().uuidString.prefix(8))", isAnonymous: true)
    }
}
