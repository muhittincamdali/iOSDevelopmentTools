import Foundation

/// Network entries as an HTTP Archive (HAR 1.2), the format that browser developer tools,
/// Charles, Proxyman and other HTTP debuggers open.
///
/// The archive is built from the stored values, so it is redacted the same way the entries are.
/// Bodies that are text are included as text and other bodies as Base64. Cut-off and omitted
/// bodies are marked with a `comment`; an omitted body's text is the note that replaced it.
public struct HTTPArchive: Sendable {
    /// The version written to `log.creator.version`.
    public static let creatorVersion = "2.0.0"

    /// The entries in the archive, oldest first.
    public let entries: [NetworkEntry]

    /// Creates an archive of the entries.
    public init(entries: [NetworkEntry]) {
        self.entries = entries.sorted { $0.startDate < $1.startDate }
    }

    /// The archive as JSON, ready to save as a `.har` file.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let log = Log(creator: Creator(name: "iOSDevelopmentTools", version: Self.creatorVersion), entries: entries.map(Entry.init))
        return try encoder.encode(Document(log: log))
    }

    // MARK: HAR 1.2 structure (http://www.softwareishard.com/blog/har-12-spec/)

    struct Document: Encodable {
        let log: Log
    }

    struct Log: Encodable {
        let version = "1.2"
        let creator: Creator
        let entries: [Entry]
    }

    struct Creator: Encodable {
        let name: String
        let version: String
    }

    struct NameValue: Encodable {
        let name: String
        let value: String
    }

    struct Entry: Encodable {
        let startedDateTime: String
        let time: Double
        let request: Request
        let response: Response
        let cache = Cache()
        let timings: Timings
        let comment: String?

        init(_ entry: NetworkEntry) {
            startedDateTime = entry.startDate.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
            let httpVersion = entry.networkProtocol.map(HTTPArchive.httpVersion) ?? "HTTP/1.1"
            request = Request(entry, httpVersion: httpVersion)
            response = Response(entry, httpVersion: httpVersion)
            timings = Timings(entry)
            time = timings.total
            comment = entry.error.map { "Failed: \($0.message) (\($0.domain) \($0.code))" }
        }
    }

    struct Request: Encodable {
        let method: String
        let url: String
        let httpVersion: String
        let cookies: [NameValue] = []
        let headers: [NameValue]
        let queryString: [NameValue]
        let postData: PostData?
        let headersSize = -1
        let bodySize: Int

        init(_ entry: NetworkEntry, httpVersion: String) {
            method = entry.method
            url = entry.url
            self.httpVersion = httpVersion
            headers = entry.requestHeaders.map { NameValue(name: $0.name, value: $0.value) }
            queryString = HTTPArchive.queryItems(in: entry.url)
            postData = entry.requestBody.map { PostData($0, mimeType: entry.requestContentType ?? "") }
            bodySize = entry.requestBody?.byteCount ?? 0
        }
    }

    struct PostData: Encodable {
        let mimeType: String
        let text: String
        let comment: String?

        init(_ body: CapturedBody, mimeType: String) {
            self.mimeType = mimeType
            let content = HTTPArchive.content(of: body)
            // postData has no encoding field, so binary bodies are described rather than included.
            text = content.encoding == nil ? content.text ?? "" : ""
            comment = content.encoding == nil ? content.comment : HTTPArchive.join(content.comment, "Binary body of \(body.byteCount) bytes not included.")
        }
    }

    struct Response: Encodable {
        let status: Int
        let statusText: String
        let httpVersion: String
        let cookies: [NameValue] = []
        let headers: [NameValue]
        let content: Content
        let redirectURL: String
        let headersSize = -1
        let bodySize: Int

        init(_ entry: NetworkEntry, httpVersion: String) {
            status = entry.statusCode ?? 0
            statusText = entry.statusCode.map(HTTPArchive.reasonPhrase) ?? ""
            self.httpVersion = httpVersion
            headers = entry.responseHeaders.map { NameValue(name: $0.name, value: $0.value) }
            content = Content(entry.responseBody, mimeType: entry.responseContentType ?? "")
            redirectURL = entry.redirectURL ?? ""
            bodySize = entry.responseBody?.byteCount ?? (entry.statusCode == nil ? -1 : 0)
        }
    }

    struct Content: Encodable {
        let size: Int
        let mimeType: String
        let text: String?
        let encoding: String?
        let comment: String?

        init(_ body: CapturedBody?, mimeType: String) {
            self.mimeType = mimeType
            size = body?.byteCount ?? 0
            guard let body else {
                text = nil
                encoding = nil
                comment = nil
                return
            }
            let content = HTTPArchive.content(of: body)
            text = content.text
            encoding = content.encoding
            comment = content.comment
        }
    }

    struct Cache: Encodable {}

    struct Timings: Encodable {
        let blocked = -1.0
        let dns: Double
        let connect: Double
        let ssl: Double
        let send: Double
        let wait: Double
        let receive: Double

        init(_ entry: NetworkEntry) {
            if let timings = entry.timings {
                dns = HTTPArchive.milliseconds(timings.domainLookup) ?? -1
                connect = HTTPArchive.milliseconds(timings.connect) ?? -1
                ssl = HTTPArchive.milliseconds(timings.secureConnection) ?? -1
                send = HTTPArchive.milliseconds(timings.send) ?? 0
                wait = HTTPArchive.milliseconds(timings.wait) ?? 0
                receive = HTTPArchive.milliseconds(timings.receive) ?? 0
            } else {
                // Without metrics the whole duration counts as waiting.
                dns = -1
                connect = -1
                ssl = -1
                send = 0
                wait = HTTPArchive.milliseconds(entry.duration) ?? 0
                receive = 0
            }
        }

        /// The sum of the phases that apply. In HAR the connect time includes the SSL time.
        var total: Double {
            [dns, connect, send, wait, receive].filter { $0 > 0 }.reduce(0, +)
        }
    }

    // MARK: Helpers

    /// The standard reason phrase for a status code (RFC 9110), or an empty string.
    static func reasonPhrase(_ status: Int) -> String {
        reasonPhrases[status] ?? ""
    }

    private static let reasonPhrases: [Int: String] = [
        100: "Continue", 101: "Switching Protocols", 103: "Early Hints",
        200: "OK", 201: "Created", 202: "Accepted", 203: "Non-Authoritative Information", 204: "No Content",
        205: "Reset Content", 206: "Partial Content",
        300: "Multiple Choices", 301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified",
        307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 402: "Payment Required", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 406: "Not Acceptable", 407: "Proxy Authentication Required", 408: "Request Timeout",
        409: "Conflict", 410: "Gone", 411: "Length Required", 412: "Precondition Failed", 413: "Content Too Large",
        414: "URI Too Long", 415: "Unsupported Media Type", 416: "Range Not Satisfiable", 417: "Expectation Failed",
        421: "Misdirected Request", 422: "Unprocessable Content", 425: "Too Early", 426: "Upgrade Required",
        428: "Precondition Required", 429: "Too Many Requests", 431: "Request Header Fields Too Large",
        451: "Unavailable For Legal Reasons",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway", 503: "Service Unavailable",
        504: "Gateway Timeout", 505: "HTTP Version Not Supported", 511: "Network Authentication Required",
    ]

    /// Seconds as milliseconds rounded to three decimals; `nil` for a missing or non-finite value.
    static func milliseconds(_ seconds: TimeInterval?) -> Double? {
        guard let seconds, seconds.isFinite else { return nil }
        return (max(0, seconds) * 1_000_000).rounded() / 1000
    }

    /// `h2` → `HTTP/2`, `http/1.1` → `HTTP/1.1`, `h3` → `HTTP/3`.
    static func httpVersion(_ protocolName: String) -> String {
        switch protocolName.lowercased() {
        case "h2", "h2c": "HTTP/2"
        case "h3", "http/3": "HTTP/3"
        case let other: other.uppercased()
        }
    }

    /// The query parameters of a (redacted) URL string, percent-decoded where possible.
    static func queryItems(in url: String) -> [NameValue] {
        let beforeFragment = url.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        guard let question = beforeFragment.firstIndex(of: "?") else { return [] }
        let query = beforeFragment[beforeFragment.index(after: question)...]
        return query.split(whereSeparator: { $0 == "&" || $0 == ";" }).map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let decode = { (text: Substring) in
                let plain = text.replacingOccurrences(of: "+", with: " ")
                return plain.removingPercentEncoding ?? plain
            }
            return NameValue(name: decode(parts[0]), value: parts.count > 1 ? decode(parts[1]) : "")
        }
    }

    private struct BodyContent {
        var text: String?
        var encoding: String?
        var comment: String?
    }

    private static func content(of body: CapturedBody) -> BodyContent {
        if body.redaction == .omitted {
            return BodyContent(text: body.text, comment: "Omitted by redaction: the body could not be parsed, or its content type is not one that is parsed.")
        }
        let truncation = body.isTruncated ? "Only the first \(body.data.count) of \(body.byteCount) bytes were stored." : nil
        let redaction = body.redaction == .redacted ? "Sensitive values were replaced with \(RedactionPolicy.replacement)." : nil
        let comment = join(truncation, redaction)
        if let text = body.text {
            return BodyContent(text: text, comment: comment)
        }
        return BodyContent(text: body.data.base64EncodedString(), encoding: "base64", comment: comment)
    }

    private static func join(_ parts: String?...) -> String? {
        let present = parts.compactMap { $0 }
        return present.isEmpty ? nil : present.joined(separator: " ")
    }
}
