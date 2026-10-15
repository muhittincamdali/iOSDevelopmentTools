import Foundation

/// A header name and value, in the order they are shown and exported.
public struct HTTPHeader: Sendable, Hashable, Codable {
    /// The header name, as it was sent or received.
    public let name: String
    /// The header value, or ``RedactionPolicy/replacement`` when the name is sensitive.
    public let value: String

    /// Creates a header.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    /// Headers from a dictionary, sorted by name so the order is the same every time.
    static func sorted(_ fields: [String: String]) -> [HTTPHeader] {
        fields.map { HTTPHeader(name: $0.key, value: $0.value) }
            .sorted { ($0.name.lowercased(), $0.name) < ($1.name.lowercased(), $1.name) }
    }

    /// The value of the first header with this name, compared without case.
    static func value(named name: String, in headers: [HTTPHeader]) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

/// A request or response body as it was stored: possibly cut off, possibly redacted.
public struct CapturedBody: Sendable, Hashable {
    /// The stored bytes. Empty when the body was withheld.
    public let data: Data
    /// How many bytes the body had as it was sent or received, including bytes that were not
    /// stored. Redaction can make ``data`` longer or shorter than this.
    public let byteCount: Int
    /// Whether only the first bytes were stored because the body was larger than
    /// ``NetworkLogger/Configuration/maximumBodySize``.
    public let isTruncated: Bool
    /// What redaction did to the stored bytes.
    public let redaction: RedactionOutcome

    /// Creates a stored body.
    public init(data: Data, byteCount: Int, isTruncated: Bool, redaction: RedactionOutcome) {
        self.data = data
        self.byteCount = max(byteCount, 0)
        self.isTruncated = isTruncated
        self.redaction = redaction
    }

    /// Stores the first bytes of a body after checking them with the policy.
    ///
    /// - Parameters:
    ///   - prefix: The bytes that were kept, at most the capture limit.
    ///   - byteCount: The size of the whole body.
    static func capture(prefix: Data, byteCount: Int, contentType: String?, policy: RedactionPolicy) -> CapturedBody {
        let isTruncated = byteCount > prefix.count
        let (data, outcome) = policy.redact(body: prefix, contentType: contentType, isComplete: !isTruncated)
        return CapturedBody(data: data, byteCount: byteCount, isTruncated: isTruncated, redaction: outcome)
    }

    /// The stored bytes as UTF-8 text, or `nil` when they are not valid UTF-8.
    ///
    /// A truncated body may end in the middle of a character; that last character is dropped.
    public var text: String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        guard isTruncated else { return nil }
        // Drop up to three bytes of a character split by the capture limit.
        for cut in 1...3 where data.count > cut {
            if let text = String(data: data.dropLast(cut), encoding: .utf8) { return text }
        }
        return nil
    }

    /// The stored bytes formatted as indented JSON, or `nil` when they are not complete JSON.
    public var prettyPrintedJSON: String? {
        guard !isTruncated,
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              JSONSerialization.isValidJSONObject(object),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        else { return nil }
        return String(data: pretty, encoding: .utf8)
    }
}

/// One HTTP request and its response, as recorded by ``NetworkLogger``.
///
/// Values are redacted with the logger's ``RedactionPolicy`` before the entry is created, so an
/// entry never holds the sensitive values it was recorded from.
public struct NetworkEntry: Sendable, Identifiable, Hashable {
    /// Where a request is in its life.
    public enum State: Sendable, Hashable {
        /// Sent, no response or error yet.
        case pending
        /// A response arrived and the body finished loading.
        case completed
        /// The request failed or was cancelled before it completed.
        case failed
    }

    /// Time spent in each phase of the request, in seconds, from `URLSessionTaskMetrics`.
    ///
    /// A phase the system did not report (for example DNS on a reused connection) is `nil`.
    public struct Timings: Sendable, Hashable {
        /// Looking up the host name.
        public var domainLookup: TimeInterval?
        /// Opening the connection, including the TLS handshake.
        public var connect: TimeInterval?
        /// The TLS handshake.
        public var secureConnection: TimeInterval?
        /// Sending the request.
        public var send: TimeInterval?
        /// Waiting for the first byte of the response.
        public var wait: TimeInterval?
        /// Receiving the response.
        public var receive: TimeInterval?

        /// Creates timings; phases that are left out are `nil`.
        public init(
            domainLookup: TimeInterval? = nil, connect: TimeInterval? = nil, secureConnection: TimeInterval? = nil,
            send: TimeInterval? = nil, wait: TimeInterval? = nil, receive: TimeInterval? = nil
        ) {
            self.domainLookup = domainLookup
            self.connect = connect
            self.secureConnection = secureConnection
            self.send = send
            self.wait = wait
            self.receive = receive
        }
    }

    /// A unique identifier for the entry.
    public let id: UUID
    /// When the request was sent.
    public let startDate: Date
    /// The HTTP method, such as `GET`.
    public let method: String
    /// The request URL as a display string, redacted (see ``RedactionPolicy/redact(url:)``).
    public let url: String
    /// The host the request went to.
    public let host: String?
    /// The URL path, without query or fragment, with `;name=value` parameters redacted.
    public let path: String
    /// The request headers, sorted by name and redacted.
    public let requestHeaders: [HTTPHeader]
    /// The request body, if it had one.
    public internal(set) var requestBody: CapturedBody?

    /// When the response finished loading or the request failed.
    public internal(set) var endDate: Date?
    /// The HTTP status code, once a response arrived.
    public internal(set) var statusCode: Int?
    /// The response headers, sorted by name and redacted.
    public internal(set) var responseHeaders: [HTTPHeader] = []
    /// The response body, once it finished loading.
    public internal(set) var responseBody: CapturedBody?
    /// The `Content-Type` of the response, if any.
    public internal(set) var responseContentType: String?
    /// The error the request failed with.
    public internal(set) var error: NetworkError?
    /// Where the server redirected the request, redacted. The redirected request is a separate entry.
    public internal(set) var redirectURL: String?
    /// Phase timings, when the system reported them.
    public internal(set) var timings: Timings?
    /// The protocol the response came over, such as `h2` or `http/1.1`, when the system reported it.
    public internal(set) var networkProtocol: String?

    /// Creates an entry for a request that was just sent.
    init(id: UUID = UUID(), startDate: Date, request: URLRequest, body: CapturedBody?, policy: RedactionPolicy) {
        self.id = id
        self.startDate = startDate
        self.method = request.httpMethod ?? "GET"
        self.url = request.url.map(policy.redact(url:)) ?? ""
        self.host = request.url?.host()
        self.path = request.url.map { policy.redact(urlString: $0.path(percentEncoded: true)) } ?? ""
        self.requestHeaders = policy.redact(headers: HTTPHeader.sorted(request.allHTTPHeaderFields ?? [:]))
        self.requestBody = body
    }

    /// Where the request is in its life.
    public var state: State {
        if error != nil { return .failed }
        return endDate == nil ? .pending : .completed
    }

    /// Seconds from sending the request to the end of the response, once it ended.
    public var duration: TimeInterval? {
        endDate.map { max(0, $0.timeIntervalSince(startDate)) }
    }

    /// The `Content-Type` of the request, if any.
    public var requestContentType: String? {
        HTTPHeader.value(named: "Content-Type", in: requestHeaders)
    }
}

/// Why a request failed.
public struct NetworkError: Sendable, Hashable, Codable {
    /// The error domain, such as `NSURLErrorDomain`.
    public let domain: String
    /// The error code within the domain.
    public let code: Int
    /// A description for people.
    public let message: String

    /// Creates an error description.
    public init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    init(_ error: any Error) {
        let nsError = error as NSError
        self.init(domain: nsError.domain, code: nsError.code, message: nsError.localizedDescription)
    }

    /// Whether the request was cancelled rather than failing on the network.
    public var isCancellation: Bool {
        domain == NSURLErrorDomain && code == NSURLErrorCancelled
    }
}
