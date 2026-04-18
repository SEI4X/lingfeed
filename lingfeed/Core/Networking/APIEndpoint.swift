import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct APIEndpoint<Response: Decodable>: Sendable {
    let method: HTTPMethod
    let path: String
    let body: Encodable?

    init(method: HTTPMethod = .get, path: String, body: Encodable? = nil) {
        self.method = method
        self.path = path
        self.body = body
    }
}

struct EmptyResponse: Decodable, Equatable {}
