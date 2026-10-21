/// JSON written into free text, read with its parser.
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

    /// The longest JSON in free text that is parsed, in scalars: 64 Ki. Its tree takes memory in
    /// proportion to it, so longer JSON cuts the text at its first bracket, as JSON that does not
    /// parse does. A body is read with its own limit (see ``RedactionPolicy/maximumBodySize``).
    static let longestJSON = 65_536

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
    /// does not close as JSON does, so it is a trigger: the text is hidden from its first bracket,
    /// and so is JSON longer than ``longestJSON``. In a text inside a document, JSON one level too
    /// many, deeper than the depth left or longer than the reading budget leaves (see
    /// ``ReadingBudget``) hides the whole text.
    mutating func embeddedJSON() {
        let start = text.offsets[position]
        guard let inner = nesting.enteringDocument() else {
            hideWholeText()
            return
        }
        let budget = inner.lengthLeft
        let document: JSONDocument
        do {
            document = try JSONDocument(source, at: start, nesting: inner, lengthLimit: min(budget, Self.longestJSON))
        } catch .tooDeep where nesting.isEmbedded {
            hideWholeText()
            return
        } catch .overBudget where nesting.isEmbedded && budget <= Self.longestJSON {
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
            cut(atOffset: first)
            return
        }
        record(spans: found, region: region)
        position = end
        if readsWords, mentionsSecret(in: jsonStart..<end) { cut(afterByte: end - 1) }
    }
}
