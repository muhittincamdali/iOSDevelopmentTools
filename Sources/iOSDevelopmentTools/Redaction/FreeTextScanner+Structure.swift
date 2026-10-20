/// JSON and URLs written into free text, read with their parsers.
extension FreeTextScanner {
    // MARK: JSON

    /// Whether the byte at `i` opens JSON: `{` before `"` or `}`, or `[` before `{`, `[`, `"` or
    /// `]`, with optional white space between. `[INFO]`, `[1/3]` and `{x}` are not JSON.
    func startsJSON(_ i: Int) -> Bool {
        let byte = text.bytes[i]
        let allowed: ByteSet
        if byte == UInt8(ascii: "{") {
            allowed = Self.objectStarts
        } else if byte == UInt8(ascii: "[") {
            allowed = Self.arrayStarts
        } else {
            return false
        }
        var k = i + 1
        while k < text.count, Self.jsonWhitespace.contains(text.bytes[k]) { k += 1 }
        return k < text.count && allowed.contains(text.bytes[k])
    }

    private static let objectStarts = ByteSet("\"}")
    private static let arrayStarts = ByteSet("{[\"]")
    private static let jsonWhitespace = ByteSet(" \t\n\r")

    /// JSON in free text, parsed with the JSON parser and redacted by the key rule for structured
    /// input; its strings are free text again. In text, its members follow the rule for keys in
    /// text: the text is cut at the value of the first member whose name is not on
    /// ``allowedKeys``, and at the second element of a two-element array whose first is a string
    /// not on it (`{"status":200,"user":"bob"}` keeps `"status":200`, `["user","bob"]` keeps
    /// `["user",`). JSON that holds a word that names a secret or cannot be read
    /// (`["password"] hunter2`) cuts the text after it. JSON that does not parse is a bracket that
    /// does not close as JSON does, so it is a trigger: the text is hidden from its first bracket.
    /// In a text inside a document, JSON one level too many, deeper than the depth left or longer
    /// than the reading budget leaves (see ``ReadingBudget``) hides the whole text.
    mutating func embeddedJSON() {
        let start = text.offsets[position]
        guard let inner = nesting.enteringDocument() else {
            hideWholeText()
            return
        }
        let document: JSONDocument
        do {
            document = try JSONDocument(source, at: start, nesting: inner, lengthLimit: inner.lengthLeft)
        } catch .tooDeep where nesting.isEmbedded {
            hideWholeText()
            return
        } catch .overBudget where nesting.isEmbedded {
            hideWholeText()
            return
        } catch {
            cut(atByte: position)
            return
        }
        let region = start..<document.root.range.upperBound
        // The reader stopped within what the budget leaves, so this always fits.
        _ = inner.reads(region.count)
        let found = document.secretSpans(using: policy, compatibility: compatibility)
        let jsonStart = position
        let end = text.byteIndex(atOrAfter: region.upperBound)
        if readsWords, let first = document.firstValue(notAllowedBy: { policy.allowsTextKey($0, in: allowedKeys) }) {
            // What the key rule found before the cut stays: the values a detector changed.
            record(spans: found.filter { $0.start < first }, region: region)
            cut(atOffset: first, trigger: jsonStart)
            return
        }
        record(spans: found, region: region)
        position = end
        if readsWords, mentionsSecret(in: jsonStart..<end) { cut(afterByte: end - 1) }
    }

    // MARK: URLs

    /// The end of a URL with a scheme and `//` that starts at `i` (`https://…`, `redis://…`): up to
    /// white space, a quote or an angle bracket, without punctuation that ends a sentence.
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

    /// A URL, recorded as ``RedactionPolicy/redact(url:)`` records it. A URL one level too
    /// many, or longer than the reading budget leaves, hides the whole text it is in; in a text
    /// that is not inside a document, only the URL is hidden then.
    mutating func url(to end: Int) {
        let region = text.original(position..<end)
        guard let inner = nesting.enteringDocument(), inner.reads(region.count) else {
            if nesting.isEmbedded {
                hideWholeText()
            } else {
                record(spans: [RedactionPolicy.Span(start: region.lowerBound, end: region.upperBound, replacement: RedactionPolicy.replacement)], region: region)
                position = end
            }
            return
        }
        let written = String(String.UnicodeScalarView(source[region]))
        let redacted = policy.redactedURL(written, nesting: inner)
        let span = RedactionPolicy.Span(start: region.lowerBound, end: region.upperBound, replacement: redacted)
        record(spans: redacted == written ? [] : [span], region: region)
        position = end
    }
}
