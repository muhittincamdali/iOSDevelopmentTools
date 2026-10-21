/// Markup, quotes and brackets in free text, read by their positions alone.
///
/// The scan keeps no tag, quote or bracket open while it reads. An earlier design read a tag as
/// a key, kept the tag that was open and the closing quote it was in, and searched for a closing
/// quote to the end of the text: markup it did not know (`<!--`, `<?pi`, `</x>`, `<br/>`) kept
/// what followed it, an allowed tag kept its text, and a quote that closed on a later line kept
/// the lines in between. Markup is now never parsed (see ``startsMarkup(at:)``), and one pass of
/// its own finds the first quote that does not close on its line or that overlaps another (see
/// ``noteMarks()``).
extension FreeTextScanner {
    /// Whether the byte at `i` comes after an odd number of backslashes.
    func isEscaped(_ i: Int) -> Bool {
        var count = 0
        var k = i
        while k > 0, text.bytes[k - 1] == UInt8(ascii: "\\") {
            count += 1
            k -= 1
        }
        return count % 2 == 1
    }

    /// The first of the backslashes right before byte `i`.
    func backslashesStart(before i: Int) -> Int {
        var k = i
        while k > 0, text.bytes[k - 1] == UInt8(ascii: "\\") { k -= 1 }
        return k
    }

    // MARK: Markup

    /// Whether markup starts at byte `i`. Markup in free text is not parsed, and what is allowed
    /// after a `<` is listed, not what makes it a tag: a `<` is a comparison only before an ASCII
    /// space, a tab, a line break, an ASCII digit, `=` or the end of the text (`a < b`, `<3`,
    /// `<=`). Before anything else — a letter of any script, `/`, `!`, `?`, `_`, `:`, a digit
    /// outside ASCII, a symbol, punctuation, an invisible character — it starts markup, and the
    /// text is cut at it: `<b>`, `</x>`, `<br/>`, `<!--`, `<![CDATA[`, `<?pi`, `<!DOCTYPE`, `<#`,
    /// `<-`, `<>`, `List<String>`. No tag is a key that keeps its text, whatever its name.
    func startsMarkup(at i: Int) -> Bool {
        guard text.bytes[i] == UInt8(ascii: "<") else { return false }
        let next = i + 1
        guard next < text.count else { return false }
        // A character outside ASCII that the scanning copy reads as one of the allowed ones (`３`,
        // a space with no width) and an invisible character before it are not allowed.
        guard text.offsets[next] == text.offsets[i] + 1, source[text.offsets[next]].isASCII else { return true }
        let byte = text.bytes[next]
        return !(Self.comparisonFollowers.contains(byte) || ASCII.isDigit(byte) || text.isLineTerminator(next))
    }

    private static let comparisonFollowers = ByteSet(" \t=")

    // MARK: Quotes and brackets

    /// Quotes and brackets, which are a trigger when they do not close.
    static let marks = ByteSet("\"'`([{")
    private static let openings: [UInt8] = Array("([{".utf8)
    private static let closings: [UInt8] = Array(")]}".utf8)

    /// Reads the quotes and brackets of the text, in one pass that keeps the quotes open on the
    /// line, innermost last, and the last closing bracket of each kind:
    ///
    /// - A quote is of one of six kinds: `"`, `'` or a backtick, each written plain or escaped
    ///   (`\"`, after an odd number of backslashes). A quote of one kind opens inside a quote of
    ///   another: the `"` in `'x "y'` and in a backtick quote, the `\"` in `"x \"y"`, the `'` in
    ///   `"x 'y"`.
    /// - A `"` or a backtick opens a quote of its kind anywhere, a `'` only where no letter or
    ///   digit of any script comes before it and its backslashes, so the apostrophe of `don't`,
    ///   `Ayşe'nin` and `it\'s` opens nothing.
    /// - A quote closes at the next quote of its own kind only when it is the innermost one open.
    ///   A quote of a kind that is open but not innermost leaves the quotes overlapping
    ///   (`'x "y' "c`, `"a \" b"`): which of them it closes, and which quote is still open after
    ///   it, cannot be told, so the earliest quote still open is where the text is cut at the
    ///   latest (``unclosedQuote``).
    /// - A quote still open at a line break or at the end of the text does not close on its line.
    ///   What it holds, a key and its value over lines among them (`"note\nQx31": 1`,
    ///   `'"note'\nQx31": 1`), cannot be told, so the earliest quote still open there is where the
    ///   text is cut at the latest.
    ///
    /// A kind is open at most once, so no more than six quotes are kept.
    mutating func noteMarks() {
        // The quotes open on the line, innermost last: their kind (see `quoteKind(at:)`) and the
        // byte where they opened.
        var open: [(kind: Int, at: Int)] = []
        open.reserveCapacity(Self.quoteKinds)
        for k in 0..<text.count {
            let byte = text.bytes[k]
            if let kind = Self.closings.firstIndex(of: byte) { lastCloses[kind] = k }
            guard unclosedQuote == nil else { continue }
            if let first = open.first, text.isLineTerminator(k) {
                unclosedQuote = first.at
            } else if let kind = quoteKind(at: k) {
                if open.last?.kind == kind {
                    open.removeLast()
                } else if let first = open.first, open.contains(where: { $0.kind == kind }) {
                    unclosedQuote = first.at
                } else if opensQuote(at: k) {
                    open.append((kind, kind % 2 == 1 ? backslashesStart(before: k) : k))
                }
            }
        }
        if unclosedQuote == nil, let first = open.first { unclosedQuote = first.at }
    }

    private static let quoteBytes: [UInt8] = Array("\"'`".utf8)
    /// Each quote character, plain or escaped.
    private static let quoteKinds = 2 * quoteBytes.count

    /// The kind of the quote character at byte `k`: twice its place in ``quoteBytes``, plus one
    /// when it is escaped; nil when the byte is no quote.
    private func quoteKind(at k: Int) -> Int? {
        let byte = text.bytes[k]
        guard Self.quotes.contains(byte), let index = Self.quoteBytes.firstIndex(of: byte) else { return nil }
        return 2 * index + (isEscaped(k) ? 1 : 0)
    }

    /// A quote or an opening bracket at the position. A quote may open a quoted key (see
    /// ``quote()``); whether it closes on its line was read by ``noteMarks()``. A bracket is a
    /// trigger when no closing one of its kind comes after it.
    mutating func readMark() {
        let byte = text.bytes[position]
        if Self.quotes.contains(byte) {
            quote()
            return
        }
        if let kind = Self.openings.firstIndex(of: byte), lastCloses[kind] < position {
            cut(atByte: position)
            return
        }
        position += 1
    }

    /// A quote that opens a quoted key (`"user": …`, `'user'=…`, `\"user\":` in escaped JSON):
    /// one that closes on its line with a separator after it, white space and line breaks
    /// between. A quoted key follows the key rule: unless it is on the allowlist (see
    /// ``allowsQuotedKey(_:)``), the text is cut at its opening quote, so nothing written in the
    /// quotes shows (`"x": …`, `"hunter2": "v"`, `"session Qz9W": 1`). The text in any quote is
    /// read on like any other, for the keys and names written in it.
    private mutating func quote() {
        let open = position
        position += 1
        guard opensQuote(at: open) else { return }
        let escaped = isEscaped(open)
        guard let close = closingQuote(after: open, escaped: escaped), let next = firstText(from: close + 1), isSeparator(next) else { return }
        // In escaped JSON the backslash before the closing quote is not the key's.
        let key = (open + 1)..<(escaped ? close - 1 : close)
        if !allowsQuotedKey(key) { cut(atByte: escaped ? backslashesStart(before: open) : open) }
    }

    /// The next quote of the kind at `open` on its line, escaped like it or not escaped.
    private func closingQuote(after open: Int, escaped: Bool) -> Int? {
        let quote = text.bytes[open]
        var k = open + 1
        while k < text.count, !text.isLineTerminator(k) {
            if text.bytes[k] == quote, isEscaped(k) == escaped { return k }
            k += 1
        }
        return nil
    }

    /// Whether the quoted key in the bytes `key` is on the allowlist, compared where it is in the
    /// text: the key as written, the invisible characters before it included. A key longer than
    /// ``PlainName/maximumKeyLength`` is turned down before any of it is read, so no key is copied
    /// whatever its length.
    private func allowsQuotedKey(_ key: Range<Int>) -> Bool {
        guard !key.isEmpty else { return false }
        let region = text.originalWithInvisiblesBefore(key)
        guard region.count <= PlainName.maximumKeyLength else { return false }
        return policy.allowsTextKey(source[region], in: allowedKeys)
    }

    /// Whether the quote character at byte `k` can open a quote: a `'` only where no letter or
    /// digit comes before it and its backslashes.
    private func opensQuote(at k: Int) -> Bool {
        guard text.bytes[k] == UInt8(ascii: "'") else { return true }
        let start = backslashesStart(before: k)
        return start == 0 || !text.isAnyAlphanumeric(start - 1)
    }
}
