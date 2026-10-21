import Foundation

/// URLs written into free text.
///
/// A URL in free text is not read on its own terms: it is shown only when it is clean (see
/// ``isCleanURL(to:)``), and any other URL cuts the text where it starts. Earlier designs read
/// the query, fragment and path parameters of a URL in text and kept the text after it when they
/// looked complete; reviews got values past every version of that reading, one ending at a time.
/// The query parameters that ``RedactionPolicy/allowedQueryParameters`` allows are not read here:
/// they apply to the URL of a request, not to a URL in text.
extension FreeTextScanner {
    /// The end of a URL with a scheme and `//` that starts at `i` (`https://…`, `redis://…`): up to
    /// white space, a quote, an angle bracket, a backtick or the end of the line, without the
    /// punctuation that ends a sentence.
    func urlEnd(from i: Int, lineEnd: Int) -> Int? {
        guard ASCII.isLetter(text.bytes[i]), i == 0 || !Self.isSchemeCharacter(text.bytes[i - 1]) else { return nil }
        var k = i + 1
        while k < lineEnd, k - i <= Self.maximumSchemeLength, Self.isSchemeCharacter(text.bytes[k]) { k += 1 }
        guard k + 2 < lineEnd, text.bytes[k] == UInt8(ascii: ":"), text.bytes[k + 1] == UInt8(ascii: "/"), text.bytes[k + 2] == UInt8(ascii: "/") else {
            return nil
        }
        var end = k + 3
        while end < lineEnd, !text.isSpace(end), !Self.urlEnds.contains(text.bytes[end]) { end += 1 }
        while end > k + 3, Self.trailingPunctuation.contains(text.bytes[end - 1]) { end -= 1 }
        return end
    }

    private static let maximumSchemeLength = 32
    private static let urlEnds = ByteSet("\"'<>`")
    private static let trailingPunctuation = ByteSet(".,;:!?)]}")

    private static func isSchemeCharacter(_ byte: UInt8) -> Bool {
        ASCII.isAlphanumeric(byte) || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ".")
    }

    /// The URL from ``position`` to byte `end`. A clean URL is recorded as
    /// ``RedactionPolicy/redact(url:)`` records it, so a path segment that looks like an
    /// identifier becomes `:id`, and the text after it is read on; its last segment is read with
    /// the next word, as a word is (`https://x.example/to ken hunter2`). Any other URL cuts the text
    /// where it starts, which is never after a trigger inside it: a clean URL holds only ASCII
    /// letters, digits, `.`, `_`, `-` and `/`. A clean URL one level too many, or longer than the
    /// reading budget leaves, hides the whole text it is in when the text is inside a document,
    /// and cuts it at the URL otherwise.
    mutating func url(to end: Int) {
        guard isCleanURL(to: end) else {
            cut(atByte: position)
            return
        }
        let region = text.original(position..<end)
        guard let inner = nesting.enteringDocument(), inner.reads(region.count) else {
            if nesting.isEmbedded { hideWholeText() } else { cut(atByte: position) }
            return
        }
        let written = String(String.UnicodeScalarView(source[region]))
        let redacted = policy.redactedURL(written, nesting: inner)
        let span = RedactionPolicy.Span(start: region.lowerBound, end: region.upperBound, replacement: redacted)
        record(spans: redacted == written ? [] : [span], region: region)
        // The last segment and the word after the URL may spell a secret name across the space,
        // as two words do.
        if readsWords, let segment = lastSegment(before: end), let secretEnd = secretEndAcrossSpace(after: segment, lineEnd: currentLineEnd()) {
            cut(afterByte: secretEnd - 1)
            return
        }
        position = end
    }

    /// The bytes of the last path segment of the URL from ``position`` to byte `end`, or of its
    /// host when it has no path; nil when the URL ends in `/`.
    private func lastSegment(before end: Int) -> Range<Int>? {
        var start = end
        while start > position, text.bytes[start - 1] != UInt8(ascii: "/") { start -= 1 }
        return start < end ? start..<end : nil
    }

    /// Whether the URL from ``position`` to byte `end` is clean, so that it is shown:
    ///
    /// - it is `scheme://host` with an optional path, at most ``longestWord`` characters long;
    /// - after the scheme it holds only the ASCII letters, digits, `.`, `_`, `-` and `/`, so no
    ///   `?`, `#`, `;`, `%`, `=`, `:`, `@`, `\`, no escape and no character outside ASCII,
    ///   invisible ones included;
    /// - the host is a name of ASCII labels or an IPv4 address in which the value detectors find
    ///   nothing (see ``RedactionPolicy/showsHost(_:)``);
    /// - neither the host nor any path segment names a secret by the key rule
    ///   (``RedactionPolicy/hidesValue(ofKey:)``), which also hides a segment without a letter or
    ///   digit;
    /// - it ends where the text ends, before white space or a line break, or before one of
    ///   ``sentencePunctuation`` that the end of the text, white space or a line break follows
    ///   (see ``endsCleanURL(at:)``).
    private func isCleanURL(to end: Int) -> Bool {
        guard endsCleanURL(at: end) else { return false }
        let range = position..<end
        guard !isOpaque(range) else { return false }
        // The invisible and control characters that the scanning copy left out, before the URL and
        // before what follows it, count as part of it.
        let written = startOffset(ofByte: position)..<(end < text.count ? text.offsets[end] : text.sourceCount)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(written.count)
        for scalar in source[written] {
            guard scalar.isASCII else { return false }
            bytes.append(UInt8(scalar.value))
        }
        guard let colon = bytes.firstIndex(of: UInt8(ascii: ":")), bytes[..<colon].allSatisfy(Self.isSchemeCharacter),
              bytes[colon...].starts(with: "://".utf8)
        else { return false }
        let rest = bytes[(colon + 3)...]
        guard rest.allSatisfy(Self.isCleanURLCharacter) else { return false }
        let host = rest.prefix { $0 != UInt8(ascii: "/") }
        guard !host.isEmpty, policy.showsHost(String(decoding: host, as: UTF8.self)), !namesSecret(host) else { return false }
        guard !rest[host.endIndex...].split(separator: UInt8(ascii: "/")).contains(where: namesSecret) else { return false }
        // The host as `URLComponents` reads it, which ``RedactionPolicy/redact(url:)`` writes: an
        // internationalized name in Punycode (`xn--…`) is read in its own letters, no host name.
        guard let parsed = URLComponents(string: String(decoding: bytes, as: UTF8.self))?.percentEncodedHost else { return false }
        return policy.showsHost(parsed)
    }

    /// Whether a clean URL may end at byte `end`: the text ends there, white space or a line
    /// break follows, or one of ``sentencePunctuation`` and then the end of the text, white space
    /// or a line break. Each is written in ASCII, with no invisible character between. Anything
    /// else after the URL — a quote, `>`, a backtick, a second mark (`x),`, `x..`), a letter right
    /// after the mark (`x.y`) — leaves where the URL ends unknown, so the URL is not clean.
    private func endsCleanURL(at end: Int) -> Bool {
        guard end < text.count else { return true }
        if isPlainBreak(end) { return true }
        guard Self.sentencePunctuation.contains(text.bytes[end]), source[text.offsets[end]].isASCII else { return false }
        let next = end + 1
        guard (next < text.count ? text.offsets[next] : text.sourceCount) == text.offsets[end] + 1 else { return false }
        return next == text.count || isPlainBreak(next)
    }

    /// Whether byte `k` is white space or a line break written in ASCII.
    private func isPlainBreak(_ k: Int) -> Bool {
        (text.isSpace(k) || text.isLineTerminator(k)) && source[text.offsets[k]].isASCII
    }

    /// The one mark that may come between a clean URL and the white space after it: the marks
    /// that end a sentence or a clause, and `)` that closes the bracket a URL is written in. A
    /// `:`, `;`, `?` or `=` after a URL is left for the text after it to complete
    /// (`/token: hunter2`), so it is not among them, and neither is a quote, `>`, `]` or `}`.
    static let sentencePunctuation = ByteSet(".,!)")

    /// The characters of a clean URL after its scheme: ASCII letters, digits, `.`, `_`, `-`, `/`.
    private static func isCleanURLCharacter(_ byte: UInt8) -> Bool {
        ASCII.isAlphanumeric(byte) || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "/")
    }

    /// Whether a host or path segment of ASCII bytes hides a value by the key rule: it names a
    /// secret, or it has no letter or digit.
    private func namesSecret(_ bytes: some Collection<UInt8>) -> Bool {
        policy.hidesValue(ofKey: bytes.lazy.map { Unicode.Scalar($0) })
    }
}
