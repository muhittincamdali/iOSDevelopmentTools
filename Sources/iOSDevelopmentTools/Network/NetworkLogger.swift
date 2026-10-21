import Foundation
import os

/// Keeps the most recent HTTP requests and their responses in memory.
///
/// ``NetworkCapture`` feeds a logger from `URLSession`. Requests that do not go through a
/// session it can see, such as those of a background session, can be added with
/// ``record(request:response:body:error:startDate:endDate:)``.
///
/// Everything is redacted with ``Configuration/redaction`` before it is stored, and the logger
/// keeps at most ``Configuration/maximumEntries`` entries and
/// ``Configuration/maximumBodySize`` bytes of each body. Headers and URLs are stored whole, so
/// they are not covered by these limits. All methods can be called from any thread.
public final class NetworkLogger: Sendable {
    /// What a logger records and how much of it.
    public struct Configuration: Sendable, Hashable {
        /// The largest value ``maximumEntries`` accepts.
        public static let entryLimit = 10_000
        /// The largest value ``maximumBodySize`` accepts: 16 MiB.
        public static let bodySizeLimit = 16 * 1024 * 1024

        private var storedMaximumEntries: Int
        private var storedMaximumBodySize: Int
        private var storedIgnoredHosts: Set<String>

        /// How many entries are kept; the oldest is dropped when a new one would exceed it.
        /// Kept between 1 and ``entryLimit``.
        public var maximumEntries: Int {
            get { storedMaximumEntries }
            set { storedMaximumEntries = min(max(newValue, 1), Self.entryLimit) }
        }

        /// How many bytes of each request and response body are kept. Larger bodies are cut off
        /// and marked ``CapturedBody/isTruncated``; a cut-off body cannot be parsed, so redaction
        /// stores a note in its place (``RedactionOutcome/omitted``), as it does for a body over
        /// ``RedactionPolicy/maximumBodySize``. Kept between 0 and ``bodySizeLimit``.
        public var maximumBodySize: Int {
            get { storedMaximumBodySize }
            set { storedMaximumBodySize = min(max(newValue, 0), Self.bodySizeLimit) }
        }

        /// What is replaced before anything is stored.
        public var redaction: RedactionPolicy

        /// Hosts whose requests are not recorded. A host also covers its subdomains, so
        /// `example.com` covers `api.example.com`. Compared without case.
        public var ignoredHosts: Set<String> {
            get { storedIgnoredHosts }
            set { storedIgnoredHosts = Set(newValue.map(Self.normalizedHost).filter { !$0.isEmpty }) }
        }

        /// Creates a configuration. Out-of-range limits are clamped.
        public init(
            maximumEntries: Int = 500,
            maximumBodySize: Int = 256 * 1024,
            redaction: RedactionPolicy = .default,
            ignoredHosts: Set<String> = []
        ) {
            storedMaximumEntries = min(max(maximumEntries, 1), Self.entryLimit)
            storedMaximumBodySize = min(max(maximumBodySize, 0), Self.bodySizeLimit)
            storedIgnoredHosts = Set(ignoredHosts.map(Self.normalizedHost).filter { !$0.isEmpty })
            self.redaction = redaction
        }

        /// Whether requests to this host are recorded.
        public func records(host: String?) -> Bool {
            guard let host, !storedIgnoredHosts.isEmpty else { return true }
            let candidate = Self.normalizedHost(host)
            return !storedIgnoredHosts.contains { candidate == $0 || candidate.hasSuffix("." + $0) }
        }

        private static func normalizedHost(_ host: String) -> String {
            var result = host.lowercased().trimmingCharacters(in: .whitespaces)
            while result.hasSuffix(".") { result.removeLast() }
            return result
        }
    }

    private struct State: Sendable {
        var configuration: Configuration
        var entries: BoundedBuffer<NetworkEntry>
        var observers: [UUID: AsyncStream<Void>.Continuation] = [:]
    }

    /// The logger that ``NetworkCapture`` uses unless it is given another one.
    public static let shared = NetworkLogger()

    private let state: OSAllocatedUnfairLock<State>

    /// Creates an empty logger.
    public init(configuration: Configuration = Configuration()) {
        state = OSAllocatedUnfairLock(initialState: State(
            configuration: configuration, entries: BoundedBuffer(capacity: configuration.maximumEntries)))
    }

    /// What the logger records. Lowering ``Configuration/maximumEntries`` drops the oldest entries.
    public var configuration: Configuration {
        get { state.withLock { $0.configuration } }
        set {
            mutate { state in
                state.configuration = newValue
                state.entries.setCapacity(newValue.maximumEntries)
                return true
            }
        }
    }

    /// The recorded entries, oldest first.
    public var entries: [NetworkEntry] {
        state.withLock { $0.entries.elements }
    }

    /// The entry with this identifier, if it is still kept.
    public func entry(id: NetworkEntry.ID) -> NetworkEntry? {
        state.withLock { state in state.entries.first { $0.id == id } }
    }

    /// Removes every entry.
    public func clear() {
        mutate { state in
            state.entries.removeAll()
            return true
        }
    }

    /// A stream that yields whenever entries are added, change or are removed.
    ///
    /// Changes that happen while the consumer is busy are coalesced into one element, so a slow
    /// consumer never builds up a backlog. The stream ends when the task that iterates it is
    /// cancelled.
    public func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        state.withLock { $0.observers[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            _ = self?.state.withLock { $0.observers.removeValue(forKey: id) }
        }
        return stream
    }

    /// Records a request that has finished, for requests that ``NetworkCapture`` cannot see.
    ///
    /// - Parameters:
    ///   - request: The request as it was sent.
    ///   - response: The response, if one arrived.
    ///   - body: The response body.
    ///   - error: The error the request failed with.
    ///   - startDate: When the request was sent.
    ///   - endDate: When it finished. Defaults to now.
    /// - Returns: The new entry's identifier, or `nil` when the host is ignored.
    @discardableResult
    public func record(
        request: URLRequest,
        response: URLResponse?,
        body: Data?,
        error: (any Error)? = nil,
        startDate: Date,
        endDate: Date = Date()
    ) -> NetworkEntry.ID? {
        let limit = configuration.maximumBodySize
        let requestBody = request.httpBody
        guard let id = begin(request: request, startDate: startDate, bodyPrefix: requestBody?.prefix(limit), bodyByteCount: requestBody?.count ?? 0) else {
            return nil
        }
        if let response { receive(response: response, for: id) }
        finish(id, bodyPrefix: body.map { Data($0.prefix(limit)) } ?? Data(), bodyByteCount: body?.count ?? 0, error: error, endDate: endDate)
        return id
    }

    // MARK: Recording

    /// Adds an entry for a request that was just sent; `nil` when its host is ignored.
    func begin(request: URLRequest, startDate: Date, bodyPrefix: Data?, bodyByteCount: Int) -> NetworkEntry.ID? {
        let configuration = configuration
        guard configuration.records(host: request.url?.host()) else { return nil }
        let contentType = request.value(forHTTPHeaderField: "Content-Type")
        let body = bodyPrefix.flatMap { prefix -> CapturedBody? in
            guard bodyByteCount > 0 else { return nil }
            return CapturedBody.capture(prefix: prefix, byteCount: bodyByteCount, contentType: contentType, policy: configuration.redaction)
        }
        let entry = NetworkEntry(startDate: startDate, request: request, body: body, policy: configuration.redaction)
        mutate { state in
            state.entries.append(entry)
            return true
        }
        return entry.id
    }

    /// Stores the response status and headers.
    func receive(response: URLResponse, for id: NetworkEntry.ID) {
        let policy = configuration.redaction
        update(id) { entry in
            Self.apply(response: response, to: &entry, policy: policy)
        }
    }

    /// Marks a request as redirected; the server's next request is recorded as a new entry.
    func redirect(_ id: NetworkEntry.ID, response: URLResponse, to newRequest: URLRequest, endDate: Date = Date()) {
        let policy = configuration.redaction
        update(id) { entry in
            Self.apply(response: response, to: &entry, policy: policy)
            entry.redirectURL = newRequest.url.map(policy.redact(url:))
            entry.endDate = endDate
        }
    }

    /// Stores the response body and the outcome.
    func finish(
        _ id: NetworkEntry.ID,
        bodyPrefix: Data,
        bodyByteCount: Int,
        error: (any Error)?,
        timings: NetworkEntry.Timings? = nil,
        networkProtocol: String? = nil,
        endDate: Date = Date()
    ) {
        let policy = configuration.redaction
        update(id) { entry in
            if bodyByteCount > 0 {
                entry.responseBody = CapturedBody.capture(
                    prefix: bodyPrefix, byteCount: bodyByteCount, contentType: entry.receivedContentType, policy: policy)
            }
            entry.receivedContentType = nil
            entry.error = error.map { NetworkError($0, policy: policy) }
            entry.timings = timings ?? entry.timings
            entry.networkProtocol = networkProtocol ?? entry.networkProtocol
            entry.endDate = endDate
        }
    }

    /// Records the final size of a request body that was streamed while it was sent. A body
    /// that turns out longer than what was checked cannot have been parsed whole, so it is
    /// omitted.
    func updateRequestBodySize(_ id: NetworkEntry.ID, byteCount: Int) {
        let policy = configuration.redaction
        update(id) { entry in
            guard let body = entry.requestBody, byteCount > body.byteCount else { return }
            guard policy.isEnabled else {
                entry.requestBody = CapturedBody(data: body.data, byteCount: byteCount, isTruncated: true, redaction: body.redaction)
                return
            }
            let note = RedactionPolicy.omissionNote(byteCount: byteCount, mediaType: MediaType(entry.requestContentType))
            entry.requestBody = CapturedBody(data: Data(note.utf8), byteCount: byteCount, isTruncated: true, redaction: .omitted)
        }
    }

    private static func apply(response: URLResponse, to entry: inout NetworkEntry, policy: RedactionPolicy) {
        entry.responseContentType = response.mimeType
        entry.receivedContentType = response.mimeType
        guard let http = response as? HTTPURLResponse else { return }
        entry.statusCode = http.statusCode
        var fields: [String: String] = [:]
        for (name, value) in http.allHeaderFields {
            fields[String(describing: name)] = String(describing: value)
        }
        entry.responseHeaders = policy.redact(headers: HTTPHeader.sorted(fields))
        entry.receivedContentType = http.value(forHTTPHeaderField: "Content-Type")
        entry.responseContentType = HTTPHeader.value(named: "Content-Type", in: entry.responseHeaders) ?? response.mimeType
    }

    private func update(_ id: NetworkEntry.ID, _ change: (inout NetworkEntry) -> Void) {
        mutate { state in
            state.entries.modifyFirst(where: { $0.id == id }, change)
        }
    }

    /// Applies a change under the lock, then notifies observers outside it.
    private func mutate(_ change: (inout State) -> Bool) {
        let observers = state.withLockUnchecked { state -> [AsyncStream<Void>.Continuation] in
            change(&state) ? Array(state.observers.values) : []
        }
        observers.forEach { $0.yield() }
    }
}
