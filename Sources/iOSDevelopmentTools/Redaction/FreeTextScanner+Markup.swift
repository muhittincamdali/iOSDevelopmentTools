/// Markup, quotes and brackets in free text, read by their positions alone.
///
/// The scan keeps no tag, quote or bracket open while it reads. Earlier designs read a tag as a
/// key and tracked the quote and the start tag that were open: a quote opened before a tag kept
/// the tag from ever ending, and markup between a tag and its text ended the cut the tag had set
/// up. Markup is now never parsed (see ``startsMarkup(at:)``), and one pass of its own, over the
/// bytes of the scanning copy, finds the two positions where quotes and brackets cut the text
/// (see ``openMarks()``).
extension FreeTextScanner {
    /// Whether markup starts at byte `i`: a `<` that is not a comparison. The rule names what a
    /// comparison is, not what a tag can start with: a `<` is a comparison only before an ASCII
    /// space, tab, line feed or carriage return, an ASCII digit, `=` or the end of the text
    /// (`a < b`, `1<2`, `<3`, `<=`, `x <`). Before any other character — a letter of any script,
    /// `_`, `:`, `/`, `!`, `?`, any other punctuation, a digit or a symbol outside ASCII — it starts
    /// markup (`<user>`, `<_id>`, `</a>`, `<!--`, `<?xml`, `<०>`, `<-x>`, `x << 1`). Free text
    /// never parses markup: the first such `<` cuts the text, whatever follows it, so what an
    /// element, a comment or a CDATA section holds never shows. The character after the `<` is
    /// read in the original text, so a digit or a space outside ASCII (`<١>`, `<\u{00A0}`) is not
    /// read as its ASCII form.
    func startsMarkup(at i: Int) -> Bool {
        guard text.bytes[i] == UInt8(ascii: "<") else { return false }
        let next = text.offsets[i] + 1
        guard next < source.count else { return false }
        let scalar = source[next]
        return !(scalar.isASCII && Self.comparisonFollowers.contains(UInt8(scalar.value)))
    }

    /// What may follow a `<` that is a comparison.
    private static let comparisonFollowers = ByteSet(" \t\n\r0123456789=")

    /// Where the quotes and brackets that do not close cut the text.
    struct OpenMarks: Equatable {
        /// The earliest quote still open where a quote does not close on its line before the scan
        /// ends, or where two quotes overlap: the byte of the quote, or of the backslashes before
        /// it when it is escaped (`\"`). The text is cut there.
        var unclosedQuote: Int?
        /// The outermost bracket outside quotes that is still open where the scan ends. The text
        /// is cut after it when nothing else cut it.
        var openBracket: Int?
    }

    /// Reads the quotes and brackets of the text, in one pass that keeps the quotes open, at most
    /// one of each of the six kinds (`"`, `'` and a backtick, each plain or escaped as in escaped
    /// JSON, `\"`), and one bracket:
    ///
    /// - A `"` or a backtick opens a quote anywhere, a `'` only at the start of a word, so the
    ///   apostrophe of `don't` and of `it\'s` opens nothing. A quote of one kind opens inside a
    ///   quote of another (`'a "b" c'`, `"say 'hi'"`).
    /// - A quote closes at the next of its own character written the same way, when it is the
    ///   innermost quote open. When a quote of a kind that is open comes while a quote opened
    ///   after it is still open (`'x "y' z"`, `'a "b' c" done`), the quotes overlap: which quote
    ///   it closes cannot be told, as two earlier readings of quotes differed on it, and the pass
    ///   ends at the earliest quote still open.
    /// - A quote still open at a line break does not close on its line, and neither does one
    ///   still open where the scan ends (``scanEnd``): at the end of the text or at the first
    ///   character outside the safe alphabet, which cuts the text inside it. What it holds, a key
    ///   and its value over lines among them (`"note\nQx31": 1`), cannot be told, so the pass
    ///   ends there, at the earliest quote still open.
    /// - A bracket outside quotes (`(`, `[`, `{`) opens, and its closing one closes it.
    ///
    /// Nothing past ``scanEnd`` is read, as by the scan.
    func openMarks() -> OpenMarks {
        var marks = OpenMarks()
        var quotes: [(byte: UInt8, escaped: Bool, at: Int)] = []
        var depth = 0
        var k = 0
        while k < scanEnd {
            let byte = text.bytes[k]
            if let earliest = quotes.first, text.isLineTerminator(k) {
                marks.unclosedQuote = earliest.at
                return marks
            }
            if Self.quotes.contains(byte) {
                let escaped = isEscaped(k)
                if let index = quotes.firstIndex(where: { $0.byte == byte && $0.escaped == escaped }) {
                    guard index == quotes.count - 1 else {
                        marks.unclosedQuote = quotes[0].at
                        return marks
                    }
                    quotes.removeLast()
                } else if opensQuote(at: k) {
                    quotes.append((byte, escaped, escaped ? backslashesStart(before: k) : k))
                }
            } else if !quotes.isEmpty {
                // Nothing else inside a quote counts, brackets included.
            } else if Self.openingBrackets.contains(byte) {
                if depth == 0 { marks.openBracket = k }
                depth += 1
            } else if Self.closingBrackets.contains(byte), depth > 0 {
                depth -= 1
                if depth == 0 { marks.openBracket = nil }
            }
            k += 1
        }
        if let earliest = quotes.first { marks.unclosedQuote = earliest.at }
        return marks
    }

    /// Whether the quote character at byte `k` can open a quote: a `'` only where no letter or
    /// digit comes before it and its backslashes.
    func opensQuote(at k: Int) -> Bool {
        guard text.bytes[k] == UInt8(ascii: "'") else { return true }
        let start = backslashesStart(before: k)
        return start == 0 || !text.isAnyAlphanumeric(start - 1)
    }

    private static let openingBrackets = ByteSet("([{")
    private static let closingBrackets = ByteSet(")]}")
}
