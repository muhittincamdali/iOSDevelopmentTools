import Foundation

/// Redaction of URLs.
extension RedactionPolicy {
    /// The URL as a display string, with its credentials, query values and identifiers hidden.
    ///
    /// The URL is read with `URLComponents`:
    ///
    /// - The user name and password (`user:password@`) and the fragment (`#…`) are never written.
    /// - **Host:** the host is a key of the URL. It is written only when it is a name of ASCII
    ///   letters, digits and `-` in labels separated by `.`, an IPv4 address or an IPv6 address in
    ///   brackets, and the value detectors find nothing in it (a card number, a run of 32 hex
    ///   digits, a token). Any other host, such as `password=hunter2` in
    ///   `myapp://password=hunter2` or a host with `_`, `%` or letters outside ASCII, is written as
    ///   ``replacement`` after the scheme, with nothing after it. A host that names a secret, by
    ///   the key rule or as a word, is written with the scheme and port only, as the path after it
    ///   is its value: with a scheme of the app's own `URLComponents` reads the first part after
    ///   `//` as the host, so `myapp://pin/4831` has the host `pin` and is written as
    ///   `myapp://pin`. A host such as `auth.example.com` names `auth` and hides its whole path
    ///   too, which over-hides on purpose.
    /// - **Query:** a parameter keeps its value only when its name, decoded, is plain ASCII and on
    ///   ``allowedQueryParameters``, which is empty by default; any other value is `[REDACTED]`,
    ///   and so is a parameter without `=` that is not on the list. A name that is not plain
    ///   ASCII, or holds a card number, an address or a token, is `[REDACTED]` as well, and a
    ///   parameter that names a secret in its value (`?label=Password&value=…`) hides the others.
    ///   A query that servers could split into fields differently is written as `?[REDACTED]`, as
    ///   ``redact(body:contentType:isComplete:)`` describes for forms: one with a `;`, a `%` that
    ///   does not start an escape, or a name spelled two ways.
    /// - **Path:** a segment that looks like an identifier or a secret becomes `:id`: a UUID, a
    ///   number of six or more digits, a token of 16 or more letters and digits, a run of 32 or
    ///   more hex or Base64 characters, a JSON Web Token, anything the value detectors find, and
    ///   text the free-text rule would change. The segment after one that names a secret is a
    ///   value too and becomes `:id` whatever it looks like (`/pin/4831`, `/token/…/info`).
    /// - **Dot segments:** a path that servers resolve differently from how it is written is not
    ///   read: only the scheme, host and port are written. That is a path with a `.` or `..`
    ///   segment, `%2E` in any case, a `;` anywhere, raw or as `%3B` in any case
    ///   (`/cart;jsessionid=…`, `/a;pin/4831`), or an escape escaped again (`%252E`).
    ///   `URL.standardized` and servers resolve `/pin/./4831` and `/token/x/../4831` as
    ///   `/pin/4831` and `/token/4831` (RFC 3986 §5.2.4), and a `;` starts parameters for some
    ///   servers but is part of the segment for others, so the segment after a secret name could
    ///   not be told from what the text shows. Parameters after a `;` are never read.
    /// - A path of more than ``maximumPathSegments`` segments, or a query of more than
    ///   ``maximumQueryParameters`` parameters, is not read: only the scheme, host and port are
    ///   written. So is every URL with ``URLDetail/hostOnly``.
    ///
    /// A URL that `URLComponents` cannot parse is recorded as its scheme and host, or as
    /// ``unparsedURL``.
    public func redact(url: URL) -> String {
        guard isEnabled else { return url.absoluteString }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            guard let scheme = url.scheme, let host = url.host(percentEncoded: true) else { return Self.unparsedURL }
            return "\(scheme)://" + (showsHost(host) ? host : Self.replacement)
        }
        return redacted(components, nesting: .document(length: url.absoluteString.unicodeScalars.count))
    }

    /// The URL's host as ``redact(url:)`` records it: the host when it is written, ``replacement``
    /// when it is not (a host that is not a name of ASCII labels or an address, or one in which
    /// a value detector finds something); nil when the URL has no host.
    func redactedHost(of url: URL) -> String? {
        guard isEnabled else { return url.host() }
        // Read as ``redact(url:)`` reads it: with `URLComponents`, or from the URL when they
        // cannot read it.
        let host = URLComponents(url: url, resolvingAgainstBaseURL: false).map(\.percentEncodedHost) ?? url.host(percentEncoded: true)
        guard let host else { return nil }
        return showsHost(host) ? host : Self.replacement
    }

    /// The URL's path as ``redact(url:)`` records it; empty when only the host is recorded.
    func redactedPath(of url: URL) -> String {
        guard isEnabled else { return url.path(percentEncoded: true) }
        guard urlDetail == .full, let components = URLComponents(url: url, resolvingAgainstBaseURL: false), readsPath(of: components)
        else { return "" }
        return redacted(path: components.percentEncodedPath, nesting: .document(length: url.absoluteString.unicodeScalars.count))
    }

    /// A URL written in text, recorded as ``redact(url:)`` records it. `nesting` is the URL's own:
    /// its query values and path segments are read as text inside it.
    func redactedURL(_ text: String, nesting: Nesting) -> String {
        guard let components = URLComponents(string: text) else { return Self.unparsedURL }
        return redacted(components, nesting: nesting)
    }

    private func redacted(_ components: URLComponents, nesting: Nesting) -> String {
        var result = components.scheme.map { "\($0):" } ?? ""
        if let host = components.percentEncodedHost {
            guard showsHost(host) else { return result + "//" + Self.replacement }
            result += "//" + host
            if let port = components.port { result += ":\(port)" }
        }
        guard urlDetail == .full, readsPath(of: components) else { return result.isEmpty ? Self.unparsedURL : result }
        result += redacted(path: components.percentEncodedPath, nesting: nesting)
        if let query = components.percentEncodedQuery, !Self.isStrictForm(query) { return result + "?" + Self.replacement }
        if let items = components.percentEncodedQueryItems {
            // `?label=Password&value=…`: a parameter that names a secret hides the others.
            let field = { (item: URLQueryItem) in Self.namingField(name: Self.formDecoded(item.name) ?? "", value: item.value.flatMap(Self.formDecoded)) }
            let naming = NamingFields(items.lazy.map(field), policy: self, compatibility: CompatibilityText())
            let parameters = items.indices.map { index in
                redacted(
                    parameter: items[index].name, value: items[index].value, hidesValue: naming.hidesValue(at: index, of: field(items[index])),
                    nesting: nesting)
            }
            result += "?" + parameters.joined(separator: "&")
        }
        return result
    }

    /// Whether a host is written: empty, as in `file:///…`, or a host name or an address in which
    /// the value detectors find nothing.
    func showsHost(_ host: String) -> Bool {
        guard !host.isEmpty else { return true }
        let bytes = Array(host.utf8)
        guard Self.isHostName(bytes) || Self.isIPv4Address(bytes) || Self.isIPv6Literal(bytes) else { return false }
        return detectorSpans(in: NormalizedText(Array(host.unicodeScalars), compatibility: CompatibilityText())).isEmpty
    }

    /// The longest host name, in bytes, and the longest label in it (RFC 1035).
    private static let longestHostName = 253
    private static let longestLabel = 63

    /// Whether a host is a name of labels of ASCII letters, digits and `-` that neither starts nor
    /// ends a label, separated by `.`, with an optional `.` at the end.
    static func isHostName(_ bytes: [UInt8]) -> Bool {
        guard bytes.count <= longestHostName else { return false }
        var labels = bytes.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
        if labels.count > 1, labels.last?.isEmpty == true { labels.removeLast() }
        return labels.allSatisfy { label in
            guard let first = label.first, let last = label.last, label.count <= longestLabel else { return false }
            return first != UInt8(ascii: "-") && last != UInt8(ascii: "-") && label.allSatisfy { ASCII.isAlphanumeric($0) || $0 == UInt8(ascii: "-") }
        }
    }

    /// Whether a host is four decimal numbers from 0 to 255 separated by `.`.
    static func isIPv4Address(_ bytes: [UInt8]) -> Bool {
        let parts = bytes.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            (1...3).contains(part.count) && part.allSatisfy(ASCII.isDigit) && Int(String(decoding: part, as: UTF8.self)).map { $0 <= 255 } == true
        }
    }

    /// Whether a host is an IPv6 address in brackets: hex digits, `:` and the `.` of an IPv4 tail,
    /// without a zone (`%25en0`).
    static func isIPv6Literal(_ bytes: [UInt8]) -> Bool {
        guard bytes.count > 2, bytes.first == UInt8(ascii: "["), bytes.last == UInt8(ascii: "]") else { return false }
        let inside = bytes.dropFirst().dropLast()
        return inside.contains(UInt8(ascii: ":")) && inside.allSatisfy { byte in
            ASCII.isDigit(byte) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte | 0x20) || byte == UInt8(ascii: ":") || byte == UInt8(ascii: ".")
        }
    }

    /// Whether the path and query of a URL are read: its host, when it has one, is written and
    /// names no secret (see ``hostNamesSecret(_:)``), the URL is within the limits (see
    /// ``exceedsLimits(_:)``) and its path has no dot segment (see ``hasDotSegments(_:)``).
    func readsPath(of components: URLComponents) -> Bool {
        if let host = components.percentEncodedHost, !showsHost(host) || hostNamesSecret(host) { return false }
        return !Self.exceedsLimits(components) && !Self.hasDotSegments(components.percentEncodedPath)
    }

    /// Whether a host names a secret, by the key rule (``hidesValue(ofKey:)``) or as a word that
    /// makes the path segment after it a value (``FreeTextScanner/mentionsSecret(_:policy:compatibility:)``).
    /// In `myapp://pin/4831` `URLComponents` reads `pin` as the host, so the path after it is the
    /// value a segment `pin` would label. An IPv4 or IPv6 address names nothing.
    func hostNamesSecret(_ host: String) -> Bool {
        let bytes = Array(host.utf8)
        guard !bytes.isEmpty, !Self.isIPv4Address(bytes), !Self.isIPv6Literal(bytes) else { return false }
        let scalars = Array(host.unicodeScalars)
        return hidesValue(ofKey: scalars) || FreeTextScanner.mentionsSecret(scalars, policy: self, compatibility: CompatibilityText())
    }

    /// Whether a percent-encoded path holds what servers resolve or decode apart from its text: a
    /// segment `.` or `..`, `%2E` in any case, a `;` anywhere, raw or as `%3B` in any case, or an
    /// escape escaped again (`%25` before two hex digits or another `%`). A `;` starts parameters
    /// for a Java servlet but is part of the segment for most other servers (`/a;pin/4831` is the
    /// segment `a` with the parameter `pin`, or the segment `a;pin`), and a server that decodes
    /// before routing reads `%3B` as `;`, so no parameter after a `;` is parsed. Empty segments
    /// (`//`) are not counted: no server resolves them away.
    static func hasDotSegments(_ path: String) -> Bool {
        let bytes = Array(path.utf8)
        if bytes.contains(UInt8(ascii: ";")) { return true }
        for (i, byte) in bytes.enumerated() where byte == UInt8(ascii: "%") && i + 2 < bytes.count {
            let escape = (bytes[i + 1], bytes[i + 2] | 0x20)
            if escape == (UInt8(ascii: "2"), UInt8(ascii: "e")) || escape == (UInt8(ascii: "3"), UInt8(ascii: "b")) { return true }
            guard escape == (UInt8(ascii: "2"), UInt8(ascii: "5")), i + 3 < bytes.count else { continue }
            if bytes[i + 3] == UInt8(ascii: "%") || (i + 4 < bytes.count && isHexDigit(bytes[i + 3]) && isHexDigit(bytes[i + 4])) { return true }
        }
        return bytes.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: true).contains { segment in
            segment.count <= 2 && segment.allSatisfy { $0 == UInt8(ascii: ".") }
        }
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        ASCII.isDigit(byte) || (UInt8(ascii: "a")...UInt8(ascii: "f")).contains(byte | 0x20)
    }

    /// Whether the path has more than ``maximumPathSegments`` segments, or the query more than
    /// ``maximumQueryParameters`` parameters. Each segment and parameter is read on its own, so
    /// the count bounds the work a URL can ask for; real URLs stay far below both.
    static func exceedsLimits(_ components: URLComponents) -> Bool {
        if components.percentEncodedPath.utf8.count(where: { $0 == UInt8(ascii: "/") }) > maximumPathSegments { return true }
        guard let query = components.percentEncodedQuery else { return false }
        return query.utf8.count(where: { $0 == UInt8(ascii: "&") }) >= maximumQueryParameters
    }

    /// The path segment by segment. A segment after one that names a secret or cannot be read
    /// (`/pin/4831`, `/password-reset/…`, `/token/…/info`) is a value, so it becomes `:id`
    /// whatever it looks like. A segment that comes again is not read again.
    private func redacted(path: String, nesting: Nesting) -> String {
        var readings: [Substring: PathSegmentReading] = [:]
        var segments: [String] = []
        var followsLabel = false
        for segment in path.split(separator: "/", omittingEmptySubsequences: false) {
            guard !segment.isEmpty else {
                segments.append("")
                continue
            }
            let reading = readings[segment] ?? read(pathSegment: segment, nesting: nesting)
            readings[segment] = reading
            segments.append(followsLabel || reading.hides ? Self.identifierPlaceholder : String(segment))
            followsLabel = reading.isLabel
        }
        return segments.joined(separator: "/")
    }

    /// What a path segment is, from one reading of it.
    private struct PathSegmentReading {
        /// It looks like an identifier or holds a secret, so it becomes `:id`.
        let hides: Bool
        /// It has a word that names a secret or cannot be read, so the segment after it is a value.
        let isLabel: Bool
    }

    /// Reads a path segment once: it is decoded and scanned a single time, and the free-text rule,
    /// every value detector and the word reading all run on that scan. A segment that does not
    /// decode is both.
    private func read(pathSegment segment: Substring, nesting: Nesting) -> PathSegmentReading {
        guard let decoded = segment.removingPercentEncoding else { return PathSegmentReading(hides: true, isLabel: true) }
        let scalars = Array(decoded.unicodeScalars)
        guard !scalars.isEmpty else { return PathSegmentReading(hides: false, isLabel: false) }
        let isIdentifier = UUID(uuidString: decoded) != nil || Self.isIdentifierShaped(scalars)
        guard !isQuietWord(scalars) else { return PathSegmentReading(hides: isIdentifier, isLabel: false) }
        let compatibility = CompatibilityText()
        let text = NormalizedText(scalars, compatibility: compatibility)
        let holdsSecret = !textSpans(in: scalars, text: text, compatibility: compatibility, nesting: nesting, detectsInRegions: true).isEmpty
        let isLabel = FreeTextScanner.mentionsSecret(scalars, text: text, policy: self, compatibility: compatibility)
        return PathSegmentReading(hides: isIdentifier || holdsSecret, isLabel: isLabel)
    }

    /// `name=value` from a query parameter, both percent-encoded. The value is kept only when the
    /// name is allowed and no other parameter names a secret (`hidesValue`). An empty field, as
    /// between `&&`, stays empty.
    private func redacted(parameter rawName: String, value rawValue: String?, hidesValue: Bool, nesting: Nesting) -> String {
        if rawName.isEmpty, rawValue == nil { return "" }
        let name = Self.formDecoded(rawName)
        let shownName = name.map { PlainName($0.unicodeScalars) != nil && redactedName($0, nesting: nesting) == $0 } == true ? rawName : Self.replacement
        let allowed = name.flatMap { allowableFold($0.unicodeScalars) }.map(allowedQueryParameters.contains) ?? false
        guard let rawValue else { return allowed ? shownName : Self.replacement }
        guard !rawValue.isEmpty else { return shownName + "=" }
        guard allowed, !hidesValue, let value = Self.formDecoded(rawValue) else { return shownName + "=" + Self.replacement }
        let redactedValue = redact(value, nesting: nesting)
        return shownName + "=" + (redactedValue == value ? rawValue : Self.formEncoded(redactedValue))
    }

    /// Path segments of letters and digits at least this long are treated as tokens.
    static let mixedTokenLength = 16

    /// Whether a decoded path segment is a number of six or more digits or a token of 16 or more
    /// letters, digits, `-` and `_` with both letters and digits.
    private static func isIdentifierShaped(_ scalars: [Unicode.Scalar]) -> Bool {
        guard scalars.allSatisfy(\.isASCII) else { return false }
        let bytes = scalars.map { UInt8($0.value) }
        if bytes.count >= 6, bytes.allSatisfy(ASCII.isDigit) { return true }
        let isToken = bytes.allSatisfy { ASCII.isAlphanumeric($0) || $0 == UInt8(ascii: "-") || $0 == UInt8(ascii: "_") }
        return isToken && bytes.count >= mixedTokenLength && bytes.contains(where: ASCII.isLetter) && bytes.contains(where: ASCII.isDigit)
    }
}
