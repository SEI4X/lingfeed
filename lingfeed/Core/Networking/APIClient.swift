import Foundation

protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: AppLocalization.string("error.invalidURL")
        case .invalidResponse: AppLocalization.string("error.invalidResponse")
        case .statusCode(let code): AppLocalization.formatted("error.statusCode", code)
        case .decodingFailed: AppLocalization.string("error.decoding")
        }
    }
}

final class APIClient: Sendable {
    private let baseURL: URL
    private let session: NetworkSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, session: NetworkSession = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func send<Response>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.statusCode(httpResponse.statusCode)
        }

        do {
            if Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
