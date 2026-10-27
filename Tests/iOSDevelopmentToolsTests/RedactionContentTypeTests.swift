import Foundation
import Testing
@testable import iOSDevelopmentTools

/// The `type/subtype` of a content type is written in the note of an omitted body and in a part's
/// `Content-Type` line. 2.1.1 wrote it as the media type parser read it, without the reading its
/// header copy gets, so `application/4111111111111111` was `application/[REDACTED]` in the
/// request headers and in full in the note beside it, in the console and in a HAR file.
@Suite("Redaction: the content type in a note and a part line")
struct RedactionContentTypeTests {
    let policy = RedactionPolicy.default
    let redacted = RedactionPolicy.replacement
    static let body = Data("hello".utf8)

    /// The types whose header copy hides something, and a piece of each that is never written.
    static let secretTypes: [(type: String, secret: String)] = [
        ("application/4111111111111111", "4111111111111111"),
        ("application/4111111111111111; charset=utf-8", "4111111111111111"),
        ("wJalrXUtnFEMIK7MDENG/bPxRfiCYEXAMPLEKEY", "wjalrxutnfemik7mdeng"),
        ("eyJhbGciOiJIUzI1NiJ9/eyJzdWIiOiIxMjM0NTY3ODkwIn0", "eyjzdwiioiixmjm0nty3odkwin0"),
        ("text/x-pin-4831", "4831"),
    ]

    private func headerCopy(_ type: String) -> String {
        policy.redact(headers: [HTTPHeader(name: "Content-Type", value: type)])[0].value
    }

    @Test("A type that its header copy hides something in is written as [REDACTED] in the note", arguments: secretTypes)
    func noteHidesType(type: String, secret: String) {
        #expect(headerCopy(type) != type, "the header copy hides something")
        let (data, outcome) = policy.redact(body: Self.body, contentType: type)
        let note = String(decoding: data, as: UTF8.self)
        #expect(outcome == .omitted)
        #expect(note == "[body omitted: 5 bytes, \(redacted)]")
        #expect(!note.lowercased().contains(secret))
    }

    @Test("A type that its header copy keeps is written in lowercase, without its parameters", arguments: [
        ("application/xml", "application/xml"), ("Application/XML; charset=utf-8", "application/xml"), ("image/png", "image/png"),
        ("application/octet-stream", "application/octet-stream"), ("application/vnd.api+json", "application/vnd.api+json"),
        ("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
        ("application/x-protobuf", "application/x-protobuf"), ("text/html; charset=utf-8", "text/html"), ("application/pdf", "application/pdf"),
    ])
    func noteKeepsType(type: String, essence: String) {
        let (data, _) = policy.redact(body: Self.body, contentType: type)
        #expect(String(decoding: data, as: UTF8.self) == "[body omitted: 5 bytes, \(essence)]")
    }

    @Test("A type the parser cannot read and a missing type keep their notes")
    func unreadableAndMissingTypes() {
        #expect(String(decoding: policy.redact(body: Self.body, contentType: "application/json, text/plain").body, as: UTF8.self)
            == "[body omitted: 5 bytes, unreadable content type]")
        #expect(String(decoding: policy.redact(body: Self.body, contentType: nil).body, as: UTF8.self) == "[body omitted: 5 bytes, no content type]")
    }

    private func multipart(_ parts: [(headers: String, content: String)]) -> Data {
        var text = ""
        for part in parts {
            text += "--XyZ\r\n\(part.headers)\r\n\r\n\(part.content)\r\n"
        }
        return Data((text + "--XyZ--").utf8)
    }

    @Test("A part's type that its header copy hides something in is [REDACTED] in its line and its note", arguments: secretTypes)
    func partHidesType(type: String, secret: String) {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"note\"\r\nContent-Type: \(type)", "data"),
            ("Content-Disposition: form-data; name=\"file\"; filename=\"a.bin\"\r\nContent-Type: \(type)", "data"),
            ("Content-Disposition: form-data; name=\"size\"\r\nContent-Length: 4111111111111111", "ok"),
        ])
        let (data, _) = policy.redact(body: body, contentType: "multipart/form-data; boundary=XyZ")
        let text = String(decoding: data, as: UTF8.self)
        #expect(data == multipart([
            ("Content-Disposition: form-data; name=\"note\"\r\nContent-Type: \(redacted)", "[body omitted: 4 bytes, \(redacted)]"),
            ("Content-Disposition: form-data; name=\"file\"\r\nContent-Type: \(redacted)", "[body omitted: 4 bytes, \(redacted)]"),
            ("Content-Disposition: form-data; name=\"size\"\r\nContent-Length: \(redacted)", "ok"),
        ]))
        #expect(!text.lowercased().contains(secret))
    }

    @Test("A part's type that its header copy keeps is written, and the part is read by it")
    func partKeepsType() {
        let body = multipart([
            ("Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: Application/JSON", #"{"token":"t"}"#),
            ("Content-Disposition: form-data; name=\"page\"\r\nContent-Type: text/html", "<b>"),
        ])
        let (data, _) = policy.redact(body: body, contentType: "multipart/form-data; boundary=XyZ")
        #expect(data == multipart([
            ("Content-Disposition: form-data; name=\"meta\"\r\nContent-Type: application/json", #"{"token":"[REDACTED]"}"#),
            ("Content-Disposition: form-data; name=\"page\"\r\nContent-Type: text/html", "[body omitted: 3 bytes, text/html]"),
        ]))
    }

    @Test("A secret sent as the content type stays out of the entry and the HAR file, request and response")
    func loggerAndArchive() throws {
        let logger = NetworkLogger()
        let url = try #require(URL(string: "https://api.example.com/upload"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("wJalrXUtnFEMIK7MDENG/bPxRfiCYEXAMPLEKEY", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.body
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/4111111111111111"]))
        let id = try #require(logger.record(request: request, response: response, body: Self.body, startDate: Date()))
        let entry = try #require(logger.entry(id: id))
        #expect(entry.requestBody?.text == "[body omitted: 5 bytes, \(redacted)]")
        #expect(entry.responseBody?.text == "[body omitted: 5 bytes, \(redacted)]")
        let archive = String(decoding: try HTTPArchive(entries: [entry]).jsonData(), as: UTF8.self).lowercased()
        #expect(!archive.contains("wjalrxutnfemik7mdeng"))
        #expect(!archive.contains("4111111111111111"))
    }

    @Test("A request body that turns out longer than what was checked keeps a hidden type hidden")
    func longerRequestBody() throws {
        let logger = NetworkLogger()
        let url = try #require(URL(string: "https://api.example.com/upload"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/4111111111111111", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.body
        let id = try #require(logger.record(request: request, response: nil, body: nil, startDate: Date()))
        logger.updateRequestBodySize(id, byteCount: 9)
        let note = try #require(logger.entry(id: id)?.requestBody?.text)
        #expect(note.hasPrefix("[body omitted: 9 bytes, "))
        #expect(!note.contains("4111111111111111"))
    }
}
