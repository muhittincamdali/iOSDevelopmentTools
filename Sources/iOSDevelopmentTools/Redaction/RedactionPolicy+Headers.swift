/// Redaction of request, response and multipart part headers.
extension RedactionPolicy {
    /// The headers with every value hidden, except those of headers on ``allowedHeaders``.
    ///
    /// `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, any header
    /// whose folded name contains `token`, `secret`, `key`, `auth`, `session` or `signature`, a
    /// header with a secret name and a header whose name is not an ASCII token of letters, digits,
    /// `-`, `_` and `.` are hidden even when listed. So is a kept value that starts with an
    /// authentication scheme and credentials (`Bearer …`, `Basic …`, `Token …`, as 2.0.0 hid
    /// them). Other kept values go through the free-text rule (``redact(text:)``), with the
    /// parameters of the default allowed headers, such as `charset`, `boundary`, `q` and
    /// `max-age`, allowlisted too.
    public func redact(headers: [HTTPHeader]) -> [HTTPHeader] {
        guard isEnabled else { return headers }
        let valuePolicy = allowingTextKeys(headerValueKeys)
        return headers.map { header in
            HTTPHeader(name: header.name, value: valuePolicy.redactedHeaderValue(name: header.name, value: header.value))
        }
    }

    /// One header value as ``redact(headers:)`` stores it.
    func redactedHeaderValue(name: String, value: String) -> String {
        guard !hidesHeader(named: name), !Self.startsWithAuthenticationScheme(value) else { return Self.replacement }
        return redact(value, nesting: .text(length: value.unicodeScalars.count))
    }

    private static let alwaysHiddenHeaders: Set<String> = ["authorization", "proxyauthorization", "cookie", "setcookie", "xapikey"]
    private static let hiddenHeaderNameParts = ["token", "secret", "key", "auth", "session", "signature"]

    /// Whether a header's value is hidden whatever it holds.
    func hidesHeader(named name: String) -> Bool {
        let scalars = name.unicodeScalars
        guard !scalars.isEmpty, scalars.allSatisfy(HeaderValueReader.isTokenCharacter), let plain = PlainName(scalars),
              !plain.namesSecret(in: secretNameTable)
        else { return true }
        let folded = plain.folded
        if Self.alwaysHiddenHeaders.contains(folded) || Self.hiddenHeaderNameParts.contains(where: folded.contains) { return true }
        return !allowedHeaders.contains(folded)
    }

    /// The schemes of the IANA HTTP Authentication Scheme Registry and widespread vendor schemes:
    /// `NTLM`, `Token` (GitHub and others), `Bot` (Discord), `AWS4-HMAC-SHA256` and `SharedKey`.
    private static let authenticationSchemes: Set<String> = [
        "basic", "bearer", "concealed", "digest", "dpop", "gnap", "hoba", "mutual", "negotiate",
        "privatetoken", "scram-sha-1", "scram-sha-256", "vapid",
        "ntlm", "token", "bot", "aws4-hmac-sha256", "sharedkey", "sharedkeylite",
    ]

    /// Whether the value's first word is an authentication scheme and credentials follow it.
    private static func startsWithAuthenticationScheme(_ value: String) -> Bool {
        let isSeparator = { (scalar: Unicode.Scalar) in scalar.properties.isWhitespace || scalar == "," }
        let words = value.unicodeScalars.drop(while: isSeparator).split(maxSplits: 1, whereSeparator: isSeparator)
        guard words.count == 2 else { return false }
        return authenticationSchemes.contains(String(String.UnicodeScalarView(words[0])).lowercased())
    }
}
