import XCTest
@testable import lingfeed

@MainActor
final class APIClientTests: XCTestCase {
    func testSendDecodesSuccessfulResponse() async throws {
        let payload = TestPayload(message: "ready")
        let data = try JSONEncoder().encode(payload)
        let session = MockNetworkSession(
            data: data,
            response: HTTPURLResponse(
                url: URL(string: "https://example.com/session/start")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let client = APIClient(baseURL: URL(string: "https://example.com")!, session: session)

        let response: TestPayload = try await client.send(APIEndpoint(path: "/session/start"))

        XCTAssertEqual(response, payload)
    }

    func testSendThrowsForHTTPFailure() async throws {
        let session = MockNetworkSession(
            data: Data(),
            response: HTTPURLResponse(
                url: URL(string: "https://example.com/card/answer")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let client = APIClient(baseURL: URL(string: "https://example.com")!, session: session)

        do {
            let _: TestPayload = try await client.send(APIEndpoint(path: "/card/answer"))
            XCTFail("Expected status code failure")
        } catch NetworkError.statusCode(let code) {
            XCTAssertEqual(code, 500)
        }
    }
}

private struct TestPayload: Codable, Equatable {
    let message: String
}

private final class MockNetworkSession: NetworkSession, @unchecked Sendable {
    let data: Data
    let response: URLResponse

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (data, response)
    }
}
