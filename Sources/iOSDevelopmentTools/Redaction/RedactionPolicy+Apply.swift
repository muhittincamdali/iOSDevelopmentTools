import Foundation

extension RedactionPolicy {
    /// The headers with every sensitive value replaced.
    ///
    /// A header is sensitive when its name is, or when its value starts with an authentication
    /// scheme followed by credentials, as in a custom header that carries a bearer token under an
    /// unremarkable name. The schemes are the ones in the IANA HTTP Authentication Scheme Registry
    /// (`Basic`, `Bearer`, `Digest`, `DPoP`, `Negotiate`, …) and widespread vendor schemes:
    /// `NTLM`, `Token` (GitHub and others), `Bot` (Discord), `AWS4-HMAC-SHA256` and `SharedKey`.
    public func redact(headers: [HTTPHeader]) -> [HTTPHeader] {
        guard isEnabled else { return headers }
        return headers.map { header in
            let sensitive = isSensitive(name: header.name) || Self.startsWithAuthenticationScheme(header.value)
            return sensitive ? HTTPHeader(name: header.name, value: Self.replacement) : header
        }
    }

    private static let authenticationSchemes: Set<String> = [
        // IANA HTTP Authentication Scheme Registry.
        "basic", "bearer", "concealed", "digest", "dpop", "gnap", "hoba", "mutual", "negotiate",
        "privatetoken", "scram-sha-1", "scram-sha-256", "vapid",
        // Vendor schemes in common use.
        "ntlm", "token", "bot", "aws4-hmac-sha256", "sharedkey", "sharedkeylite",
    ]

    private static func startsWithAuthenticationScheme(_ value: String) -> Bool {
        let words = value.drop(while: \.isWhitespace).split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard words.count == 2 else { return false }
        return authenticationSchemes.contains(words[0].lowercased())
    }

    /// The URL as a display string, with sensitive query and fragment parameters and any user
    /// info replaced.
    ///
    /// Parameters are split on `&` and on `;`, which some servers also accept as a separator, and
    /// path segments are checked for `;name=value` parameters such as `;jsessionid=`. The
    /// result is meant for reading and for ``NetworkEntry/curlCommand()``; with a replacement in
    /// it, it is no longer a valid URL.
    public func redact(url: URL) -> String {
        redact(urlString: url.absoluteString)
    }

    func redact(urlString: String) -> String {
        guard isEnabled else { return urlString }
        // Delimiters are found as UTF-8 bytes, not Characters: a combining mark after "?" or "#"
        // would join it into one Character and hide the query or fragment.
        var remainder = Substring(urlString)
        var fragment: Substring?
        if let hash = remainder.utf8.firstIndex(of: UInt8(ascii: "#")) {
            fragment = remainder[remainder.utf8.index(after: hash)...]
            remainder = remainder[..<hash]
        }
        var query: Substring?
        if let question = remainder.utf8.firstIndex(of: UInt8(ascii: "?")) {
            query = remainder[remainder.utf8.index(after: question)...]
            remainder = remainder[..<question]
        }
        var result = redactMatrixParameters(in: redactUserInfo(in: remainder))
        if let query {
            result += "?" + redact(parameters: query)
        }
        if let fragment {
            result += "#" + (fragment.utf8.contains(UInt8(ascii: "=")) ? redact(parameters: fragment) : String(fragment))
        }
        return result
    }

    /// `name=value` pairs separated by `&` or `;`, with sensitive values replaced. Separators,
    /// names and the encoding of values that are kept stay as they were.
    ///
    /// The text is split as UTF-8 bytes, not Characters, as servers split it: a combining mark
    /// after `=`, `&` or `;` would join it into one Character, and `password=` followed by U+0301
    /// and a value would read as a pair without a value.
    func redact(parameters: Substring) -> String {
        let bytes = Array(parameters.utf8)
        var result = ""
        result.reserveCapacity(bytes.count)
        var pairStart = 0
        for index in 0...bytes.count {
            let atEnd = index == bytes.count
            guard atEnd || bytes[index] == UInt8(ascii: "&") || bytes[index] == UInt8(ascii: ";") else { continue }
            result += redact(pair: bytes[pairStart..<index])
            if atEnd { break }
            result.unicodeScalars.append(Unicode.Scalar(bytes[index]))
            pairStart = index + 1
        }
        return result
    }

    /// The pair with its value replaced when its name is sensitive. The bytes are cut only at
    /// ASCII delimiters, so they still hold whole UTF-8 sequences.
    private func redact(pair: ArraySlice<UInt8>) -> String {
        let text = String(decoding: pair, as: UTF8.self)
        guard let equals = pair.firstIndex(of: UInt8(ascii: "=")) else { return text }
        let name = String(decoding: pair[..<equals], as: UTF8.self)
        return isSensitive(name: name) ? "\(name)=\(Self.replacement)" : text
    }

    /// Replaces the user info in `scheme://user:password@host`. The user name goes as well,
    /// because services such as Git hosts accept a token in its place.
    private func redactUserInfo(in prefix: Substring) -> String {
        guard let schemeEnd = prefix.utf8.firstRange(of: "://".utf8) else { return String(prefix) }
        let authorityStart = schemeEnd.upperBound
        let authorityEnd = prefix.utf8[authorityStart...].firstIndex(of: UInt8(ascii: "/")) ?? prefix.endIndex
        guard let at = prefix.utf8[authorityStart..<authorityEnd].lastIndex(of: UInt8(ascii: "@")) else {
            return String(prefix)
        }
        return String(prefix[..<authorityStart]) + Self.replacement + String(prefix[at...])
    }

    /// Checks `;name=value` parameters in path segments, as in `/cart;jsessionid=…/items`.
    private func redactMatrixParameters(in prefix: String) -> String {
        guard prefix.utf8.contains(UInt8(ascii: ";")) else { return prefix }
        let pathStart: String.Index
        if let schemeEnd = prefix.utf8.firstRange(of: "://".utf8) {
            pathStart = prefix.utf8[schemeEnd.upperBound...].firstIndex(of: UInt8(ascii: "/")) ?? prefix.endIndex
        } else {
            pathStart = prefix.startIndex
        }
        let segments = prefix.utf8[pathStart...].split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false)
        let path = segments.map { segmentBytes -> String in
            let segment = Substring(segmentBytes)
            guard let semicolon = segment.utf8.firstIndex(of: UInt8(ascii: ";")) else { return String(segment) }
            let parametersStart = segment.utf8.index(after: semicolon)
            return String(segment[..<parametersStart]) + redact(parameters: segment[parametersStart...])
        }
        return String(prefix[..<pathStart]) + path.joined(separator: "/")
    }
}
