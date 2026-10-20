import Foundation

/// Redaction of URLs.
extension RedactionPolicy {
    /// The URL as a display string, with its credentials, query values and identifiers hidden.
    ///
    /// The URL is read with `URLComponents`:
    ///
    /// - The user name and password (`user:password@`) and the fragment (`#…`) are never written.
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
    ///   Parameters after a `;` (`;jsessionid=…`) are read like query parameters.
    /// - A path of more than ``maximumPathSegments`` segments, or a path or query of more than
    ///   ``maximumQueryParameters`` parameters, is not read: only the scheme, host and port are
    ///   written. So is every URL with ``URLDetail/hostOnly``.
    ///
    /// A URL that `URLComponents` cannot parse is recorded as its scheme and host, or as
    /// ``unparsedURL``.
    public func redact(url: URL) -> String {
        guard isEnabled else { return url.absoluteString }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            guard let scheme = url.scheme, let host = url.host(percentEncoded: true) else { return Self.unparsedURL }
            return "\(scheme)://\(host)"
        }
        return redacted(components, nesting: .document(length: url.absoluteString.unicodeScalars.count))
    }

    /// The URL's path as ``redact(url:)`` records it; empty when only the host is recorded.
    func redactedPath(of url: URL) -> String {
        guard isEnabled else { return url.path(percentEncoded: true) }
        guard urlDetail == .full, let components = URLComponents(url: url, resolvingAgainstBaseURL: false), !Self.exceedsLimits(components)
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
            result += "//" + host
            if let port = components.port { result += ":\(port)" }
        }
        guard urlDetail == .full, !Self.exceedsLimits(components) else { return result.isEmpty ? Self.unparsedURL : result }
        result += redacted(path: components.percentEncodedPath, nesting: nesting)
        if let query = components.percentEncodedQuery, !Self.isStrictForm(query) { return result + "?" + Self.replacement }
        if let items = components.percentEncodedQueryItems {
            // `?label=Password&value=…`: a parameter that names a secret hides the others.
            let naming = namingFields(items.map { (Self.formDecoded($0.name) ?? "", $0.value.flatMap(Self.formDecoded)) })
            let parameters = items.indices.map { index in
                redacted(parameter: items[index].name, value: items[index].value, hidesValue: naming.hidesValue(at: index), nesting: nesting)
            }
            result += "?" + parameters.joined(separator: "&")
        }
        return result
    }

    /// Whether the path has more than ``maximumPathSegments`` segments, or the path or the query
    /// more than ``maximumQueryParameters`` parameters. Each segment and parameter is read on its
    /// own, so the count bounds the work a URL can ask for; real URLs stay far below both.
    private static func exceedsLimits(_ components: URLComponents) -> Bool {
        let path = components.percentEncodedPath.utf8
        if path.count(where: { $0 == UInt8(ascii: "/") }) > maximumPathSegments { return true }
        if path.count(where: { $0 == UInt8(ascii: ";") }) > maximumQueryParameters { return true }
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
            let parts = segment.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            let base = parts[0]
            let reading = readings[base] ?? read(pathSegment: base, nesting: nesting)
            readings[base] = reading
            if followsLabel {
                segments.append(Self.identifierPlaceholder)
            } else {
                let shownBase = reading.hides ? Self.identifierPlaceholder : String(base)
                segments.append(parts.count == 2 ? shownBase + ";" + redacted(pathParameters: parts[1], nesting: nesting) : shownBase)
            }
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

    /// Reads a path segment, without its parameters, once: it is decoded and scanned a single
    /// time, and the free-text rule, every value detector and the word reading all run on that
    /// scan. A segment that does not decode is both.
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

    /// Parameters after a `;` in a path segment (`cart;jsessionid=…`), read like query parameters.
    private func redacted(pathParameters: Substring, nesting: Nesting) -> String {
        pathParameters.split(separator: ";", omittingEmptySubsequences: false).map { parameter in
            let pair = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return redacted(parameter: String(pair[0]), value: pair.count == 2 ? String(pair[1]) : nil, nesting: nesting)
        }.joined(separator: ";")
    }

    /// `name=value` from a query or path parameter, both percent-encoded. The value is kept only
    /// when the name is allowed and no other parameter names a secret (`hidesValue`). An empty
    /// field, as between `&&`, stays empty.
    private func redacted(parameter rawName: String, value rawValue: String?, hidesValue: Bool = false, nesting: Nesting) -> String {
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
