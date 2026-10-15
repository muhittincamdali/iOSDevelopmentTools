import Foundation

/// Answers requests to `https://stub.test/…` without a network. The tests install it in the
/// session that ``NetworkCapture`` forwards requests through, so a request goes app session →
/// capture → forwarding session → this stub, exactly as it would reach a real server.
///
/// Routes:
/// - `/echo`: 200 with the request body and its content type.
/// - `/login`: 200 with a JSON token and a `Set-Cookie` header.
/// - `/status/<code>`: that status with an empty body.
/// - `/bytes/<count>`: 200 with `count` bytes of `x`.
/// - `/redirect`: 302 to `/final` with the body `moved`, which a client that refuses the redirect
///   receives, as from an HTTP server; `/final`: 200 with `done`.
/// - `/offline`: fails with `URLError(.notConnectedToInternet)`.
/// - `/hang`: never answers.
final class StubServer: URLProtocol, @unchecked Sendable {
    static let host = "stub.test"

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host() == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let client, let url = request.url else { return }
        let path = url.path()
        let parts = path.split(separator: "/")

        switch parts.first {
        case "echo":
            let body = Self.body(of: request)
            let type = request.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
            respond(200, headers: ["Content-Type": type, "X-Received-Bytes": "\(body.count)"], body: body)
        case "login":
            let body = Data(#"{"access_token":"tok-123","user":"ada"}"#.utf8)
            respond(200, headers: ["Content-Type": "application/json", "Set-Cookie": "sid=abc; HttpOnly"], body: body)
        case "status":
            respond(Int(parts.last ?? "") ?? 500, headers: [:], body: Data())
        case "bytes":
            let count = Int(parts.last ?? "") ?? 0
            respond(200, headers: ["Content-Type": "text/plain"], body: Data(repeating: UInt8(ascii: "x"), count: count))
        case "redirect":
            let target = URL(string: "https://\(Self.host)/final")!
            let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString])!
            var next = URLRequest(url: target)
            next.httpMethod = "GET"
            client.urlProtocol(self, wasRedirectedTo: next, redirectResponse: response)
            // URLSession holds these back until its delegate decides, and drops them when the
            // redirect is followed.
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: Data("moved".utf8))
            client.urlProtocolDidFinishLoading(self)
        case "final":
            respond(200, headers: ["Content-Type": "text/plain"], body: Data("done".utf8))
        case "offline":
            client.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case "hang":
            break
        default:
            respond(404, headers: [:], body: Data())
        }
    }

    override func stopLoading() {}

    private func respond(_ status: Int, headers: [String: String], body: Data) {
        guard let client, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)
        else { return }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Deliver in chunks, as a network would.
        var offset = 0
        while offset < body.count {
            let end = min(offset + 64 * 1024, body.count)
            client.urlProtocol(self, didLoad: body.subdata(in: offset..<end))
            offset = end
        }
        client.urlProtocolDidFinishLoading(self)
    }

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
