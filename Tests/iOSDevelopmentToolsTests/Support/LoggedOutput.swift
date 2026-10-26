import Foundation
@testable import iOSDevelopmentTools

/// What the network inspector stores and exports for a request or a response: the entry's method,
/// URL, host, path, headers and body, its cURL command and its HTTP archive. The shared redaction
/// test corpus checks these where it checks the logged output of the other libraries that share
/// the rules.
enum LoggedOutput {
    /// What the inspector records for `request`, one line per place: `→ GET <url>`, the host, the
    /// path, each header as `name: value`, the body, the HTTP archive and, last, the cURL command.
    static func request(_ request: URLRequest, redactor: RedactionPolicy = .default) -> String {
        let entry = NetworkEntry(startDate: Date(), request: request, body: capturedBody(of: request, policy: redactor), policy: redactor)
        return lines(of: entry).joined(separator: "\n")
    }

    /// The body as the inspector stores it for a response with this body and content type.
    static func responseBody(_ body: Data, contentType: String, redactor: RedactionPolicy = .default) -> String {
        let captured = CapturedBody.capture(prefix: body, byteCount: body.count, contentType: contentType, policy: redactor)
        return String(decoding: captured.data, as: UTF8.self)
    }

    /// A plain-text response body as the inspector stores it.
    static func plainTextBody(_ text: String, redactor: RedactionPolicy = .default) -> String {
        responseBody(Data(text.utf8), contentType: "text/plain; charset=utf-8", redactor: redactor)
    }

    private static func capturedBody(of request: URLRequest, policy: RedactionPolicy) -> CapturedBody? {
        guard let body = request.httpBody, !body.isEmpty else { return nil }
        return CapturedBody.capture(prefix: body, byteCount: body.count, contentType: request.value(forHTTPHeaderField: "Content-Type"), policy: policy)
    }

    private static func lines(of entry: NetworkEntry) -> [String] {
        var lines = ["→ \(entry.method) \(entry.url)", entry.host ?? "", entry.path]
        lines += entry.requestHeaders.map { "\($0.name): \($0.value)" }
        if let body = entry.requestBody { lines.append(String(decoding: body.data, as: UTF8.self)) }
        lines.append((try? HTTPArchive(entries: [entry]).jsonData()).map { String(decoding: $0, as: UTF8.self) } ?? "")
        lines.append(entry.curlCommand())
        return lines
    }
}
