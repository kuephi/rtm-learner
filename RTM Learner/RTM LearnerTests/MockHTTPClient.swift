import Foundation
@testable import RTM_Learner

final class MockHTTPClient: HTTPClient {
    /// Map from URL string to (Data, HTTPStatus). First match wins.
    var responses: [String: (Data, Int)] = [:]
    var requestsMade: [URLRequest] = []
    var defaultResponse: (Data, Int) = (Data(), 200)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestsMade.append(request)
        let key = request.url?.absoluteString ?? ""
        let (data, status) = responses[key] ?? defaultResponse
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: nil
        )!
        return (data, response)
    }
}
