import Foundation

/// Redaction of URLs and headers.
extension RedactionPolicy {
    /// The URL as a display string: no user info and no fragment, query values hidden unless the
    /// name is on ``allowedQueryParameters``, and path segments that look like identifiers or
    /// secrets replaced by `:id`. With ``URLDetail/hostOnly``, only the scheme, host and port.
    ///
    /// A URL that `URLComponents` cannot parse is recorded as its scheme and host, or as
    /// ``unparsedURL``.
    public func redact(url: URL) -> String {
        guard isEnabled else { return url.absoluteString }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            guard let scheme = url.scheme, let host = url.host(percentEncoded: true) else { return Self.unparsedURL }
            return "\(scheme)://\(host)"
        }
        var result = components.scheme.map { "\($0):" } ?? ""
        if let host = components.percentEncodedHost {
            result += "//" + host
            if let port = components.port { result += ":\(port)" }
        }
        guard urlDetail == .full else { return result.isEmpty ? Self.unparsedURL : result }
        result += redact(percentEncodedPath: components.percentEncodedPath)
        if let items = components.percentEncodedQueryItems {
            result += "?" + items.map { redact(parameter: $0.name, value: $0.value) }.joined(separator: "&")
        }
        return result
    }

    /// The URL's path as ``redact(url:)`` records it; empty with ``URLDetail/hostOnly``.
    func redactedPath(of url: URL) -> String {
        guard isEnabled else { return url.path(percentEncoded: true) }
        guard urlDetail == .full, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "" }
        return redact(percentEncodedPath: components.percentEncodedPath)
    }

    private func redact(percentEncodedPath path: String) -> String {
        let segments = path.unicodeScalars.split(separator: "/", omittingEmptySubsequences: false)
        return segments.map { redact(pathSegment: String(Substring($0))) }.joined(separator: "/")
    }

    /// A path segment, or `:id` when it looks like an identifier or a secret. Parameters after a
    /// `;`, as in `cart;jsessionid=…`, are treated like query parameters.
    private func redact(pathSegment segment: String) -> String {
        let parts = segment.unicodeScalars.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        let base = String(Substring(parts[0]))
        var result = Self.isIdentifierLike(base) ? Self.identifierPlaceholder : base
        guard parts.count == 2 else { return result }
        let parameters = parts[1].split(separator: ";", omittingEmptySubsequences: false).map { parameter in
            let pair = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return redact(parameter: String(Substring(pair[0])), value: pair.count == 2 ? String(Substring(pair[1])) : nil)
        }
        result += ";" + parameters.joined(separator: ";")
        return result
    }

    /// `name=value` from a query or path parameter, both percent-encoded. The value is kept only
    /// when the name is on ``allowedQueryParameters``; the name is replaced when it holds
    /// something the value detectors find.
    private func redact(parameter rawName: String, value rawValue: String?) -> String {
        let name = Self.formDecoded(rawName)
        let shownName = name.map { redact(text: $0) == $0 } == true ? rawName : Self.replacement
        guard let rawValue else { return shownName }
        guard !rawValue.isEmpty else { return shownName + "=" }
        guard let name, keepsValue(ofParameter: name), let value = Self.formDecoded(rawValue) else {
            return shownName + "=" + Self.replacement
        }
        let redacted = redact(value: value, depth: 0)
        return shownName + "=" + (redacted == value ? rawValue : Self.formEncoded(redacted))
    }

    private func keepsValue(ofParameter name: String) -> Bool {
        let key = FoldedKey(name)
        return key.isPlain && !isSecret(key) && allowedQueryParameters.contains(key.folded)
    }

    /// Whether a decoded path segment is a UUID, a number of six or more digits, a hex or Base64
    /// string of 32 or more characters, a JWT, a token of 16 or more letters and digits, or holds
    /// something the value detectors find. A segment that does not decode counts as one too.
    static func isIdentifierLike(_ segment: String) -> Bool {
        guard let decoded = segment.removingPercentEncoding else { return true }
        let scalars = Array(decoded.unicodeScalars)
        guard !scalars.isEmpty else { return false }
        if UUID(uuidString: decoded) != nil { return true }
        if scalars.count >= 6, scalars.allSatisfy(ValueDetectors.isDigit) { return true }
        let isToken = scalars.allSatisfy { ValueDetectors.isLetterOrDigit($0) || $0 == "-" || $0 == "_" }
        let hasLetter = scalars.contains(where: ValueDetectors.isLetter)
        let hasDigit = scalars.contains(where: ValueDetectors.isDigit)
        if isToken, scalars.count >= mixedTokenLength, hasLetter, hasDigit { return true }
        return !ValueDetectors.secretRanges(in: scalars).isEmpty
    }

    /// Path segments of letters and digits at least this long are treated as tokens.
    static let mixedTokenLength = 16

    // MARK: Headers

    /// The headers with every value hidden, except those of headers on ``allowedHeaders``.
    ///
    /// `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, any header
    /// whose folded name contains `token`, `secret`, `key`, `auth`, `session` or `signature`, a
    /// header with a secret name and a header whose name is not plain ASCII are hidden even when
    /// listed. Kept values still go through the value detectors.
    public func redact(headers: [HTTPHeader]) -> [HTTPHeader] {
        guard isEnabled else { return headers }
        return headers.map { header in
            let value = hidesHeader(named: header.name) ? Self.replacement : redact(text: header.value)
            return HTTPHeader(name: header.name, value: value)
        }
    }

    private static let alwaysHiddenHeaders: Set<String> = ["authorization", "proxyauthorization", "cookie", "setcookie", "xapikey"]
    private static let hiddenHeaderNameParts = ["token", "secret", "key", "auth", "session", "signature"]

    func hidesHeader(named name: String) -> Bool {
        let key = FoldedKey(name)
        guard key.isPlain, !isSecret(key), !Self.alwaysHiddenHeaders.contains(key.folded) else { return true }
        guard !Self.hiddenHeaderNameParts.contains(where: key.folded.contains) else { return true }
        return !allowedHeaders.contains(key.folded)
    }
}
