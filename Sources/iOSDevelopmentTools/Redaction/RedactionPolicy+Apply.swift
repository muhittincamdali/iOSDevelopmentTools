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
        var remainder = Substring(urlString)
        var fragment: Substring?
        if let hash = remainder.firstIndex(of: "#") {
            fragment = remainder[remainder.index(after: hash)...]
            remainder = remainder[..<hash]
        }
        var query: Substring?
        if let question = remainder.firstIndex(of: "?") {
            query = remainder[remainder.index(after: question)...]
            remainder = remainder[..<question]
        }
        var result = redactMatrixParameters(in: redactUserInfo(in: remainder))
        if let query {
            result += "?" + redact(parameters: query)
        }
        if let fragment {
            result += "#" + (fragment.contains("=") ? redact(parameters: fragment) : String(fragment))
        }
        return result
    }

    /// `name=value` pairs separated by `&` or `;`, with sensitive values replaced. Separators,
    /// names and the encoding of values that are kept stay as they were.
    func redact(parameters: Substring) -> String {
        var result = ""
        result.reserveCapacity(parameters.utf8.count)
        var pairStart = parameters.startIndex
        var index = parameters.startIndex
        while index <= parameters.endIndex {
            let atEnd = index == parameters.endIndex
            if atEnd || parameters[index] == "&" || parameters[index] == ";" {
                result += redact(pair: parameters[pairStart..<index])
                if atEnd { break }
                result.append(parameters[index])
                pairStart = parameters.index(after: index)
            }
            index = parameters.index(after: index)
        }
        return result
    }

    private func redact(pair: Substring) -> String {
        guard let equals = pair.firstIndex(of: "=") else { return String(pair) }
        let name = pair[..<equals]
        return isSensitive(name: String(name)) ? "\(name)=\(Self.replacement)" : String(pair)
    }

    /// Replaces the user info in `scheme://user:password@host`. The user name goes as well,
    /// because services such as Git hosts accept a token in its place.
    private func redactUserInfo(in prefix: Substring) -> String {
        guard let schemeEnd = prefix.range(of: "://") else { return String(prefix) }
        let authorityStart = schemeEnd.upperBound
        let authorityEnd = prefix[authorityStart...].firstIndex(of: "/") ?? prefix.endIndex
        guard let at = prefix[authorityStart..<authorityEnd].lastIndex(of: "@") else { return String(prefix) }
        return String(prefix[..<authorityStart]) + Self.replacement + String(prefix[at...])
    }

    /// Checks `;name=value` parameters in path segments, as in `/cart;jsessionid=…/items`.
    private func redactMatrixParameters(in prefix: String) -> String {
        guard prefix.contains(";") else { return prefix }
        let pathStart: String.Index
        if let schemeEnd = prefix.range(of: "://") {
            pathStart = prefix[schemeEnd.upperBound...].firstIndex(of: "/") ?? prefix.endIndex
        } else {
            pathStart = prefix.startIndex
        }
        let segments = prefix[pathStart...].split(separator: "/", omittingEmptySubsequences: false)
        let path = segments.map { segment -> String in
            guard let semicolon = segment.firstIndex(of: ";") else { return String(segment) }
            let parameters = segment[segment.index(after: semicolon)...]
            return String(segment[...semicolon]) + redact(parameters: parameters)
        }
        return String(prefix[..<pathStart]) + path.joined(separator: "/")
    }
}
