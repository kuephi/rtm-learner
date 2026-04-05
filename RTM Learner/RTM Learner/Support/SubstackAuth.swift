import Foundation

enum SubstackAuthError: Error {
    case blocked
    case invalidCredentials
    case noCookieReturned
}

struct SubstackAuth {
    static func login(
        email: String,
        password: String,
        http: HTTPClient = URLSession.shared
    ) async throws -> String {
        var request = URLRequest(url: URL(string: "https://substack.com/api/v1/login")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://substack.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        let body: [String: Any?] = ["email": email, "password": password, "captcha_response": nil]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        let (_, response) = try await http.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubstackAuthError.noCookieReturned
        }
        if httpResponse.statusCode == 401 { throw SubstackAuthError.invalidCredentials }
        if httpResponse.statusCode == 403 { throw SubstackAuthError.blocked }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SubstackAuthError.blocked
        }
        // Extract substack.sid from Set-Cookie header
        let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
        if let cookie = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url!)
            .first(where: { $0.name == "substack.sid" }) {
            return cookie.value
        }
        throw SubstackAuthError.noCookieReturned
    }
}
